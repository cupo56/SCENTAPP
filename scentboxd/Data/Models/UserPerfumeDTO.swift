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
    let status: String
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case perfumeId = "perfume_id"
        case status
        case createdAt = "created_at"
    }
}
