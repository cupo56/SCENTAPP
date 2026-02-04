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
    // TRICK: Wir speichern den "echten" Wert als String (statusRaw)
    // Das erlaubt uns, im Predicate einfach nach Strings zu filtern.
    var statusRaw: String
    var dateAdded: Date
    var personalNotes: String?
    
    // Computed Property: Für den Rest des Codes fühlt es sich weiter wie ein Enum an.
    // SwiftData ignoriert computed properties, daher stört das die Datenbank nicht.
    var status: UserPerfumeStatus {
        get { UserPerfumeStatus(rawValue: statusRaw) ?? .none }
        set { statusRaw = newValue.rawValue }
    }
    
    init(status: UserPerfumeStatus = .none, dateAdded: Date = Date(), personalNotes: String? = nil) {
        self.statusRaw = status.rawValue // Hier wandeln wir direkt beim Erstellen um
        self.dateAdded = dateAdded
        self.personalNotes = personalNotes
    }
}
