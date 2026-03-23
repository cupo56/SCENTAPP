//
//  PublicProfileDTO.swift
//  scentboxd
//

import Foundation

struct PublicProfileDTO: Codable, Identifiable {
    let id: UUID
    let username: String
    let bio: String?
    let avatarUrl: String?
    let isPublic: Bool
    let ownedCount: Int
    let reviewCount: Int
    let favoriteCount: Int
    let memberSince: Date

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case bio
        case avatarUrl = "avatar_url"
        case isPublic = "is_public"
        case ownedCount = "owned_count"
        case reviewCount = "review_count"
        case favoriteCount = "favorite_count"
        case memberSince = "member_since"
    }
}
