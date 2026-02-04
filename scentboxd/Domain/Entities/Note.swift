//
//  Note.swift
//  scentboxd
//
//  Created by Cupo on 09.01.26.
//

import SwiftData

@Model
class Note {
    @Attribute(.unique) var name: String
    var category: String? // z.B. "Citrus", "Woody"
    
    @Relationship(inverse: \Perfume.topNotes)
    var topNoteIn: [Perfume]?
        
    @Relationship(inverse: \Perfume.midNotes)
    var midNoteIn: [Perfume]?
        
    @Relationship(inverse: \Perfume.baseNotes)
    var baseNoteIn: [Perfume]?
    
    init(name: String, category: String? = nil) {
        self.name = name
        self.category = category
    }
}
