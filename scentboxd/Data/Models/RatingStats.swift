//
//  RatingStats.swift
//  scentboxd
//
//  Created by Cupo on 22.01.26.
//

import Foundation

/// Aggregierte Rating-Statistik fuer ein Parfum.
struct RatingStats: Codable {
    let perfumeId: UUID
    let avgRating: Double
    let reviewCount: Int

    enum CodingKeys: String, CodingKey {
        case perfumeId = "perfume_id"
        case avgRating = "avg_rating"
        case reviewCount = "review_count"
    }
}
