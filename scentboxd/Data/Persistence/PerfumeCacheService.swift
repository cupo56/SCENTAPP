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
    
    var lastSyncedAt: Date? {
        get { UserDefaults.standard.object(forKey: Self.lastSyncedAtKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: Self.lastSyncedAtKey) }
    }
    
    /// Prüft ob ein Refresh nötig ist (älter als 5 Minuten)
    var needsRefresh: Bool {
        guard let lastSync = lastSyncedAt else { return true }
        return Date().timeIntervalSince(lastSync) > 300
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
        for remote in remotePerfumes {
            let id = remote.id
            let predicate = #Predicate<Perfume> { $0.id == id }
            var descriptor = FetchDescriptor<Perfume>(predicate: predicate)
            descriptor.fetchLimit = 1
            
            let existing = try modelContext.fetch(descriptor).first
            let target: Perfume
            
            if let existing {
                target = existing
            } else {
                target = Perfume(id: remote.id, name: remote.name)
                modelContext.insert(target)
            }
            
            // Skalare Properties aktualisieren
            target.name = remote.name
            target.concentration = remote.concentration
            target.longevity = remote.longevity
            target.sillage = remote.sillage
            target.performance = remote.performance
            target.desc = remote.desc
            target.imageUrl = remote.imageUrl
            target.occasions = remote.occasions
            
            // Brand aktualisieren
            if let remoteBrand = remote.brand {
                target.brand = findOrCreateBrand(
                    name: remoteBrand.name,
                    country: remoteBrand.country,
                    modelContext: modelContext
                )
            } else {
                target.brand = nil
            }
            
            // Noten aktualisieren
            target.topNotes = remote.topNotes.map {
                findOrCreateNote(name: $0.name, category: $0.category, modelContext: modelContext)
            }
            target.midNotes = remote.midNotes.map {
                findOrCreateNote(name: $0.name, category: $0.category, modelContext: modelContext)
            }
            target.baseNotes = remote.baseNotes.map {
                findOrCreateNote(name: $0.name, category: $0.category, modelContext: modelContext)
            }
        }
        
        try modelContext.save()
        lastSyncedAt = Date()
        
        AppLogger.cache.info("Katalog gecached: \(remotePerfumes.count) Parfums")
    }
    
    // MARK: - Helpers
    
    private func findOrCreateBrand(name: String, country: String?, modelContext: ModelContext) -> Brand {
        let predicate = #Predicate<Brand> { $0.name == name }
        var descriptor = FetchDescriptor<Brand>(predicate: predicate)
        descriptor.fetchLimit = 1
        
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.country = country
            return existing
        }
        
        let brand = Brand(name: name, country: country)
        modelContext.insert(brand)
        return brand
    }
    
    private func findOrCreateNote(name: String, category: String?, modelContext: ModelContext) -> Note {
        let predicate = #Predicate<Note> { $0.name == name }
        var descriptor = FetchDescriptor<Note>(predicate: predicate)
        descriptor.fetchLimit = 1
        
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.category = category
            return existing
        }
        
        let note = Note(name: name, category: category)
        modelContext.insert(note)
        return note
    }
}
