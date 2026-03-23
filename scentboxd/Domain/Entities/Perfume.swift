//
//  Perfume.swift
//  scentboxd
//
//  Created by Cupo on 09.01.26.
//

import Foundation
import SwiftData

@Model
class Perfume {
    @Attribute(.unique) var id: UUID
    var name: String
    var concentration: String? // z.B. "EDT", "EDP", "PARFUM"
    var longevity: String // z.B. "Langhaltend"
    var sillage: String   // z.B. "Stark"
    var performance: Double
    var desc: String?     // Description
    var imageUrl: URL?
    // MARK: - Relationships
    
    var brand: Brand?
    
    @Relationship var topNotes: [Note] = []
    @Relationship var midNotes: [Note] = []
    @Relationship var baseNotes: [Note] = []
    
    @Relationship(deleteRule: .cascade, inverse: \Review.perfume)
    var reviews: [Review] = []
    
    @Relationship(deleteRule: .cascade)
    var userMetadata: UserPersonalData?
    
    var occasions: [String] = []
    
    init(
        id: UUID = UUID(),
        name: String,
        concentration: String? = nil,
        longevity: String = "",
        sillage: String = "",
        performance: Double = 0.0,
        desc: String? = nil,
        occasions: [String] = [],
        imageUrl: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.concentration = concentration
        self.longevity = longevity
        self.sillage = sillage
        self.performance = performance
        self.desc = desc
        self.occasions = occasions
        self.imageUrl = imageUrl
    }
}

// Hilfsklasse für User-spezifische Daten
@Model
class UserPersonalData {
    var isFavorite: Bool
    var isOwned: Bool
    var isWantToTry: Bool
    var dateAdded: Date
    var personalNotes: String?

    /// Markiert, ob diese Änderung noch nicht zu Supabase hochgeladen wurde.
    /// Wird von syncFromSupabase() respektiert, um lokale Änderungen nicht zu überschreiben.
    var hasPendingSync: Bool

    /// true wenn kein Status gesetzt ist
    var hasNoStatus: Bool {
        !isFavorite && !isOwned && !isWantToTry
    }

    init(isFavorite: Bool = false, isOwned: Bool = false, isWantToTry: Bool = false, dateAdded: Date = Date(), personalNotes: String? = nil, hasPendingSync: Bool = false) {
        self.isFavorite = isFavorite
        self.isOwned = isOwned
        self.isWantToTry = isWantToTry
        self.dateAdded = dateAdded
        self.personalNotes = personalNotes
        self.hasPendingSync = hasPendingSync
    }
}
