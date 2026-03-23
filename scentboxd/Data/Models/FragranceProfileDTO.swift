//
//  FragranceProfileDTO.swift
//  scentboxd
//

import Foundation

/// Antwort der Supabase RPC `get_user_fragrance_profile`.
struct FragranceProfileDTO: Codable {
    let topNotes: [NoteCount]
    let concentrations: [ConcentrationCount]
    let avgRating: Double
    let ratingDistribution: [RatingBucket]

    struct NoteCount: Codable, Identifiable {
        let name: String
        let count: Int
        var id: String { name }
    }

    struct ConcentrationCount: Codable, Identifiable {
        let type: String
        let count: Int
        var id: String { type }
    }

    struct RatingBucket: Codable, Identifiable {
        let rating: Int
        let count: Int
        var id: Int { rating }
    }

    enum CodingKeys: String, CodingKey {
        case topNotes = "top_notes"
        case concentrations
        case avgRating = "avg_rating"
        case ratingDistribution = "rating_distribution"
    }

    /// Gesamtanzahl abgegebener Bewertungen.
    var totalReviewCount: Int {
        ratingDistribution.reduce(0) { $0 + $1.count }
    }

    /// Gesamtanzahl Düfte in der Sammlung (Favoriten + Owned).
    var totalCollectionCount: Int {
        concentrations.reduce(0) { $0 + $1.count }
    }

    /// `true` wenn der User noch keine Sammlung/Bewertungen hat.
    var isEmpty: Bool {
        topNotes.isEmpty && concentrations.isEmpty && ratingDistribution.isEmpty
    }
}
