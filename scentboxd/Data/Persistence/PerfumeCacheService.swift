//
//  PerfumeCacheService.swift
//  scentboxd
//

import Foundation
import SwiftData
import os

@MainActor
class PerfumeCacheService {
    
    private static let lastSyncedAtKey = "PerfumeCatalog_lastSyncedAt"
    private var isCaching = false
    
    var lastSyncedAt: Date? {
        get { UserDefaults.standard.object(forKey: Self.lastSyncedAtKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: Self.lastSyncedAtKey) }
    }
    
    /// Prüft ob ein Refresh nötig ist (älter als 5 Minuten)
    var needsRefresh: Bool {
        guard let lastSync = lastSyncedAt else { return true }
        return Date().timeIntervalSince(lastSync) > AppConfig.Cache.catalogTTL
    }
    
    // MARK: - Read from Cache
    
    func loadCachedPerfumes(
        modelContext: ModelContext,
        page: Int,
        pageSize: Int,
        filter: PerfumeFilter = PerfumeFilter(),
        sort: PerfumeSortOption = .nameAsc
    ) throws -> [Perfume] {
        let predicate = buildPredicate(searchQuery: nil, filter: filter)
        let sortDescriptors = buildSortDescriptors(for: sort)
        
        var descriptor = FetchDescriptor<Perfume>(predicate: predicate, sortBy: sortDescriptors)
        descriptor.fetchOffset = page * pageSize
        descriptor.fetchLimit = pageSize
        
        let results = try modelContext.fetch(descriptor)
        return applyClientFilters(results, filter: filter)
    }
    
    func searchCachedPerfumes(
        modelContext: ModelContext,
        query: String,
        page: Int,
        pageSize: Int,
        filter: PerfumeFilter = PerfumeFilter(),
        sort: PerfumeSortOption = .nameAsc
    ) throws -> [Perfume] {
        let predicate = buildPredicate(searchQuery: query, filter: filter)
        let sortDescriptors = buildSortDescriptors(for: sort)
        
        var descriptor = FetchDescriptor<Perfume>(predicate: predicate, sortBy: sortDescriptors)
        descriptor.fetchOffset = page * pageSize
        descriptor.fetchLimit = pageSize
        
        let results = try modelContext.fetch(descriptor)
        return applyClientFilters(results, filter: filter)
    }
    
    // MARK: - Predicate Builder
    
    private func buildPredicate(searchQuery: String?, filter: PerfumeFilter) -> Predicate<Perfume>? {
        let hasSearch = searchQuery != nil && !(searchQuery?.isEmpty ?? true)
        let query = searchQuery ?? ""
        
        let hasBrand = filter.brandName != nil && !(filter.brandName?.isEmpty ?? true)
        let brandName = filter.brandName ?? ""
        
        let hasConcentration = filter.concentration != nil && !(filter.concentration?.isEmpty ?? true)
        let concentration = filter.concentration ?? ""
        
        let hasLongevity = filter.longevity != nil && !(filter.longevity?.isEmpty ?? true)
        let longevity = filter.longevity ?? ""
        
        let hasSillage = filter.sillage != nil && !(filter.sillage?.isEmpty ?? true)
        let sillage = filter.sillage ?? ""
        
        // SwiftData #Predicate hat Einschränkungen bei der dynamischen Zusammensetzung.
        // Wir kombinieren die Bedingungen direkt.
        return #Predicate<Perfume> { perfume in
            (!hasSearch || perfume.name.localizedStandardContains(query) || perfume.brand?.name.localizedStandardContains(query) == true)
            && (!hasBrand || perfume.brand?.name == brandName)
            && (!hasConcentration || perfume.concentration == concentration)
            && (!hasLongevity || perfume.longevity == longevity)
            && (!hasSillage || perfume.sillage == sillage)
        }
    }
    
    // MARK: - Sort Builder
    
    private func buildSortDescriptors(for sort: PerfumeSortOption) -> [SortDescriptor<Perfume>] {
        switch sort {
        case .nameAsc:
            return [SortDescriptor(\.name, order: .forward)]
        case .nameDesc:
            return [SortDescriptor(\.name, order: .reverse)]
        case .ratingDesc:
            return [SortDescriptor(\.performance, order: .reverse)]
        case .ratingAsc:
            return [SortDescriptor(\.performance, order: .forward)]
        case .newest:
            // Fallback auf Name, da es kein createdAt auf Perfume gibt
            return [SortDescriptor(\.name, order: .forward)]
        case .popular:
            return [SortDescriptor(\.performance, order: .reverse)]
        }
    }
    
    // MARK: - Client-Side Filters (Notes, Occasions, Rating)
    // Diese Filter werden nur für den Offline-Cache genutzt.
    // Im Online-Modus werden alle Filter server-seitig in PerfumeRemoteDataSource angewendet.
    
    private func applyClientFilters(_ perfumes: [Perfume], filter: PerfumeFilter) -> [Perfume] {
        var results = perfumes
        
        if !filter.noteNames.isEmpty {
            let lowerNotes = Set(filter.noteNames.map { $0.lowercased() })
            results = results.filter { perfume in
                let allNotes = (perfume.topNotes + perfume.midNotes + perfume.baseNotes)
                    .map { $0.name.lowercased() }
                return !lowerNotes.isDisjoint(with: allNotes)
            }
        }
        
        if !filter.occasions.isEmpty {
            let lowerOccasions = Set(filter.occasions.map { $0.lowercased() })
            results = results.filter { perfume in
                let perfumeOccasions = Set(perfume.occasions.map { $0.lowercased() })
                return !lowerOccasions.isDisjoint(with: perfumeOccasions)
            }
        }
        
        if let minRating = filter.minRating {
            results = results.filter { $0.performance >= minRating }
        }
        if let maxRating = filter.maxRating {
            results = results.filter { $0.performance <= maxRating }
        }
        
        return results
    }
    
    // MARK: - Write to Cache (Upsert)
    
    func cachePerfumes(_ remotePerfumes: [Perfume], modelContext: ModelContext) throws {
        guard !isCaching else { return }
        isCaching = true
        defer { isCaching = false }

        let perfumeIds = remotePerfumes.map(\.id)
        var existingPerfumes = try buildPerfumeLookup(ids: perfumeIds, modelContext: modelContext)
        var brandLookup = try buildBrandLookup(for: remotePerfumes, modelContext: modelContext)
        var noteLookup = try buildNoteLookup(for: remotePerfumes, modelContext: modelContext)

        for remote in remotePerfumes {
            let target: Perfume

            if let existing = existingPerfumes[remote.id] {
                target = existing
            } else {
                target = Perfume(id: remote.id, name: remote.name)
                modelContext.insert(target)
                existingPerfumes[remote.id] = target
            }

            target.name = remote.name
            target.concentration = remote.concentration
            target.longevity = remote.longevity
            target.sillage = remote.sillage
            target.performance = remote.performance
            target.desc = remote.desc
            target.imageUrl = remote.imageUrl
            target.occasions = remote.occasions

            if let remoteBrand = remote.brand {
                target.brand = resolveOrCreateBrand(
                    name: remoteBrand.name,
                    country: remoteBrand.country,
                    lookup: &brandLookup,
                    modelContext: modelContext
                )
            } else {
                target.brand = nil
            }

            target.topNotes = remote.topNotes.map {
                resolveOrCreateNote(name: $0.name, category: $0.category, lookup: &noteLookup, modelContext: modelContext)
            }
            target.midNotes = remote.midNotes.map {
                resolveOrCreateNote(name: $0.name, category: $0.category, lookup: &noteLookup, modelContext: modelContext)
            }
            target.baseNotes = remote.baseNotes.map {
                resolveOrCreateNote(name: $0.name, category: $0.category, lookup: &noteLookup, modelContext: modelContext)
            }
        }

        try modelContext.save()
        lastSyncedAt = Date()

        AppLogger.cache.info("Katalog gecached: \(remotePerfumes.count) Parfums")
    }

    // MARK: - Batch Lookup Helpers

    private func buildPerfumeLookup(ids: [UUID], modelContext: ModelContext) throws -> [UUID: Perfume] {
        guard !ids.isEmpty else { return [:] }

        let predicate = #Predicate<Perfume> { perfume in
            ids.contains(perfume.id)
        }
        let descriptor = FetchDescriptor<Perfume>(predicate: predicate)
        let perfumes = try modelContext.fetch(descriptor)
        return Dictionary(perfumes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private func buildBrandLookup(for remotePerfumes: [Perfume], modelContext: ModelContext) throws -> [String: Brand] {
        let brandNames = Array(Set(remotePerfumes.compactMap { $0.brand?.name }))
        guard !brandNames.isEmpty else { return [:] }

        let predicate = #Predicate<Brand> { brand in
            brandNames.contains(brand.name)
        }
        let descriptor = FetchDescriptor<Brand>(predicate: predicate)
        let brands = try modelContext.fetch(descriptor)
        return Dictionary(brands.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private func buildNoteLookup(for remotePerfumes: [Perfume], modelContext: ModelContext) throws -> [String: Note] {
        let noteNames = Array(Set(
            remotePerfumes.flatMap { perfume in
                (perfume.topNotes + perfume.midNotes + perfume.baseNotes).map(\.name)
            }
        ))
        guard !noteNames.isEmpty else { return [:] }

        let predicate = #Predicate<Note> { note in
            noteNames.contains(note.name)
        }
        let descriptor = FetchDescriptor<Note>(predicate: predicate)
        let notes = try modelContext.fetch(descriptor)
        return Dictionary(notes.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private func resolveOrCreateBrand(name: String, country: String?, lookup: inout [String: Brand], modelContext: ModelContext) -> Brand {
        if let existing = lookup[name] {
            existing.country = country
            return existing
        }
        let brand = Brand(name: name, country: country)
        modelContext.insert(brand)
        lookup[name] = brand
        return brand
    }

    private func resolveOrCreateNote(name: String, category: String?, lookup: inout [String: Note], modelContext: ModelContext) -> Note {
        if let existing = lookup[name] {
            existing.category = category
            return existing
        }
        let note = Note(name: name, category: category)
        modelContext.insert(note)
        lookup[name] = note
        return note
    }
}
