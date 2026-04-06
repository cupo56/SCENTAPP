//
//  CuratedListDTO.swift
//  scentboxd
//

import Foundation

/// DTO für eine kuratierte Parfum-Liste (Supabase `lists`-Tabelle).
/// Gibt es bereits Einträge, enthält `itemCount` die Anzahl der Parfums.
struct CuratedListDTO: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let name: String
    let description: String?
    let isPublic: Bool
    let createdAt: Date
    let itemCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case description
        case isPublic = "is_public"
        case createdAt = "created_at"
        case itemCount = "item_count"
    }
}

/// DTO zum Erstellen einer neuen Liste (inkl. user_id).
struct CuratedListInsertDTO: Codable {
    let userId: UUID
    let name: String
    let description: String?
    let isPublic: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case name
        case description
        case isPublic = "is_public"
    }
}

/// DTO zum Aktualisieren einer bestehenden Liste (ohne user_id).
struct CuratedListUpdateDTO: Codable {
    let name: String
    let description: String?
    let isPublic: Bool

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case isPublic = "is_public"
    }
}

/// DTO für einen Eintrag in `list_items`.
struct CuratedListItemDTO: Codable, Identifiable {
    let id: UUID
    let listId: UUID
    let perfumeId: UUID
    let addedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case listId = "list_id"
        case perfumeId = "perfume_id"
        case addedAt = "added_at"
    }
}
