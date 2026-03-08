//
//  PerfumeSearchCache.swift
//  scentboxd
//

import Foundation

/// In-Memory-Cache für Suchergebnisse mit TTL.
@MainActor
final class PerfumeSearchCache {
    // NSCache handles memory pressure automatically by evicting items
    private let cache = NSCache<NSString, CacheEntry>()
    private let ttl: TimeInterval = AppConfig.Cache.searchTTL

    // Wrapper class for NSCache value, since it requires AnyObject
    private final class CacheEntry {
        let results: [Perfume]
        let timestamp: Date
        
        init(results: [Perfume], timestamp: Date) {
            self.results = results
            self.timestamp = timestamp
        }
    }

    func results(for key: String) -> [Perfume]? {
        guard let entry = cache.object(forKey: key as NSString) else { return nil }
        guard Date().timeIntervalSince(entry.timestamp) < ttl else {
            cache.removeObject(forKey: key as NSString)
            return nil
        }
        return entry.results
    }

    func store(_ results: [Perfume], for key: String) {
        let entry = CacheEntry(results: results, timestamp: Date())
        cache.setObject(entry, forKey: key as NSString)
    }

    func removeAll() {
        cache.removeAllObjects()
    }
}
