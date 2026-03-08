//
//  UserPerfumeDTO.swift
//  scentboxd
//
//  Created by Cupo on 25.01.26.
//

import Foundation

struct UserPerfumeDTO: Codable {
    let userId: UUID
    let perfumeId: UUID
    let isFavorite: Bool
    let isOwned: Bool
    let isEmpty: Bool
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case perfumeId = "perfume_id"
        case isFavorite = "is_favorite"
        case isOwned = "is_owned"
        case isEmpty = "is_empty"
        case createdAt = "created_at"
    }
}
