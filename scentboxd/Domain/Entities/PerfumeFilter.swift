//
//  PerfumeFilter.swift
//  scentboxd
//

import Foundation

// MARK: - Filter

struct PerfumeFilter: Equatable, Hashable {
    var brandName: String?
    var concentration: String?
    var longevity: String?
    var sillage: String?
    var noteNames: [String] = []
    var occasions: [String] = []
    var minRating: Double?
    var maxRating: Double?
    
    var isEmpty: Bool {
        brandName == nil
        && concentration == nil
        && longevity == nil
        && sillage == nil
        && noteNames.isEmpty
        && occasions.isEmpty
        && minRating == nil
        && maxRating == nil
    }
    
    /// Anzahl aktiver Filter (für Badge)
    var activeFilterCount: Int {
        var count = 0
        if brandName != nil { count += 1 }
        if concentration != nil { count += 1 }
        if longevity != nil { count += 1 }
        if sillage != nil { count += 1 }
        if !noteNames.isEmpty { count += 1 }
        if !occasions.isEmpty { count += 1 }
        if minRating != nil || maxRating != nil { count += 1 }
        return count
    }
    
    /// Cache-Key für In-Memory-Suchcache
    var cacheKeyComponent: String {
        let parts: [String] = [
            brandName ?? "",
            concentration ?? "",
            longevity ?? "",
            sillage ?? "",
            noteNames.sorted().joined(separator: ","),
            occasions.sorted().joined(separator: ","),
            minRating.map { String($0) } ?? "",
            maxRating.map { String($0) } ?? ""
        ]
        return parts.joined(separator: "|")
    }
}

// MARK: - Sort

enum PerfumeSortOption: String, CaseIterable, Identifiable {
    case nameAsc = "Name (A–Z)"
    case nameDesc = "Name (Z–A)"
    case ratingDesc = "Beste Bewertung"
    case ratingAsc = "Niedrigste Bewertung"
    case newest = "Neueste"
    case popular = "Beliebteste"
    
    var id: String { rawValue }
    
    var systemImage: String {
        switch self {
        case .nameAsc: return "textformat.abc"
        case .nameDesc: return "textformat.abc"
        case .ratingDesc: return "star.fill"
        case .ratingAsc: return "star"
        case .newest: return "clock"
        case .popular: return "flame"
        }
    }
}
