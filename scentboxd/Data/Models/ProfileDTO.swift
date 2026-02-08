//
//  ProfileDTO.swift
//  scentboxd
//
//  Created by Cupo on 09.02.26.
//

import Foundation

struct ProfileDTO: Codable {
    let id: UUID
    let username: String?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case updatedAt = "updated_at"
    }
}
