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
    var longevity: Int?
    var sillage: Int?
    var createdAt: Date
    var authorName: String?
    var userId: UUID?

    /// Markiert, ob diese Review-Aenderung noch nicht zu Supabase hochgeladen wurde.
    var hasPendingSync: Bool
    /// Art der ausstehenden Aenderung (save/update/delete).
    var pendingSyncAction: ReviewSyncAction?

    // Beziehung: Ein Review gehoert zu einem Parfum
    var perfume: Perfume?

    init(
        id: UUID = UUID(),
        title: String,
        text: String,
        rating: Int,
        longevity: Int? = nil,
        sillage: Int? = nil,
        createdAt: Date = Date(),
        authorName: String? = nil,
        userId: UUID? = nil,
        hasPendingSync: Bool = false,
        pendingSyncAction: ReviewSyncAction? = nil
    ) {
        self.id = id
        self.title = title
        self.text = text
        self.rating = rating
        self.longevity = longevity
        self.sillage = sillage
        self.createdAt = createdAt
        self.authorName = authorName
        self.userId = userId
        self.hasPendingSync = hasPendingSync
        self.pendingSyncAction = pendingSyncAction
    }
}
