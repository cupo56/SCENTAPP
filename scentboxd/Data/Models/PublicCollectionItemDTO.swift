//
//  PublicCollectionItemDTO.swift
//  scentboxd
//

import Foundation

/// Flaches DTO für Parfums aus der `get_public_user_collection` RPC.
/// Enthält keine verschachtelten Beziehungen (brands, notes, occasions).
struct PublicCollectionItemDTO: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String?
    let imageUrl: String?
    let concentration: String?
    let longevity: String?
    let sillage: String?
    let performance: Double?

    enum CodingKeys: String, CodingKey {
        case id, name, concentration, longevity, sillage, performance
        case description = "desc"
        case imageUrl = "image_url"
    }
}
