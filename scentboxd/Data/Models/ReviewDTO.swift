//
//  ReviewDTO.swift
//  scentboxd
//
//  Created by Cupo on 22.01.26.
//

import Foundation

struct ReviewDTO: Codable {
    let id: UUID
    let perfumeId: UUID?
    let userId: UUID?
    let authorName: String?
    let title: String
    let text: String
    let rating: Int?
    let longevity: Int?
    let sillage: Int?
    let occasions: [String]?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case perfumeId = "perfume_id"
        case userId = "user_id"
        case authorName = "author_name"
        case title
        case text
        case rating
        case longevity
        case sillage
        case occasions
        case createdAt = "created_at"
    }
}

struct ReviewInsertDTO: Codable {
    let id: UUID
    let perfumeId: UUID
    let userId: UUID?
    let authorName: String?
    let title: String
    let text: String
    let rating: Int
    let longevity: Int?
    let sillage: Int?
    let occasions: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case perfumeId = "perfume_id"
        case userId = "user_id"
        case authorName = "author_name"
        case title
        case text
        case rating
        case longevity
        case sillage
        case occasions
    }
}

struct ReviewUpdateDTO: Codable {
    let title: String
    let text: String
    let rating: Int
    let longevity: Int?
    let sillage: Int?
    let occasions: [String]?
    let authorName: String?

    enum CodingKeys: String, CodingKey {
        case title
        case text
        case rating
        case longevity
        case sillage
        case occasions
        case authorName = "author_name"
    }
}

// MARK: - Review Likes

struct ReviewLikeResult: Codable {
    let liked: Bool
    let likeCount: Int

    enum CodingKeys: String, CodingKey {
        case liked
        case likeCount = "like_count"
    }
}

struct ReviewLikeInfo: Codable, Identifiable {
    let reviewId: UUID
    let likeCount: Int
    let isLiked: Bool

    var id: UUID { reviewId }

    enum CodingKeys: String, CodingKey {
        case reviewId = "review_id"
        case likeCount = "like_count"
        case isLiked = "is_liked"
    }
}
