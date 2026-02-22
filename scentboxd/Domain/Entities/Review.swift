//
//  Review.swift
//  scentboxd
//
//  Created by Cupo on 09.01.26.
//

import Foundation
import SwiftData

@Model
class Review {
    @Attribute(.unique) var id: UUID
    var title: String
    var text: String
    var rating: Int // 1 bis 5
    var createdAt: Date
    var authorName: String?
    var userId: UUID?
    
    // Beziehung: Ein Review gehört zu einem Parfum
    var perfume: Perfume?
    
    init(id: UUID = UUID(), title: String, text: String, rating: Int, createdAt: Date = Date(), authorName: String? = nil, userId: UUID? = nil) {
        self.id = id
        self.title = title
        self.text = text
        self.rating = rating
        self.createdAt = createdAt
        self.authorName = authorName
        self.userId = userId
    }
}
