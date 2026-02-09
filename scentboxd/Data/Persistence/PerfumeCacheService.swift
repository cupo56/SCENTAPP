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
    
    func loadCachedPerfumes(modelContext: ModelContext, page: Int, pageSize: Int) throws -> [Perfume] {
        var descriptor = FetchDescriptor<Perfume>(sortBy: [SortDescriptor(\.name)])
        descriptor.fetchOffset = page * pageSize
        descriptor.fetchLimit = pageSize
        return try modelContext.fetch(descriptor)
    }
    
    func searchCachedPerfumes(modelContext: ModelContext, query: String, page: Int, pageSize: Int) throws -> [Perfume] {
        let predicate = #Predicate<Perfume> { perfume in
            perfume.name.localizedStandardContains(query)
        }
        var descriptor = FetchDescriptor<Perfume>(predicate: predicate, sortBy: [SortDescriptor(\.name)])
        descriptor.fetchOffset = page * pageSize
        descriptor.fetchLimit = pageSize
        return try modelContext.fetch(descriptor)
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
