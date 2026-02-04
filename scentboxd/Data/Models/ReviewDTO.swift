//
//  ReviewDTO.swift
//  scentboxd
//
//  Created by Cupo on 22.01.26.
//

import Foundation

struct ReviewDTO: Codable {
    let id: UUID
    let perfumeId: UUID
    let userId: UUID?
    let authorName: String?
    let title: String
    let text: String
    let rating: Int
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case perfumeId = "perfume_id"
        case userId = "user_id"
        case authorName = "author_name"
        case title
        case text
        case rating
        case createdAt = "created_at"
    }
}
