//
//  PerfumeDTO.swift
//  scentboxd
//
//  Created by Cupo on 14.01.26.
//

import Foundation

// 1. Die reine Note (aus Tabelle 'notes')
struct NoteContentDTO: Codable {
    let name: String
    let category: String?
}

// 2. Die Verknüpfung (aus Tabelle 'perfume_notes')
// Enthält den Typ (top/mid/base) UND die eigentliche Note
struct PerfumeNoteJunctionDTO: Codable {
    let noteType: String // "top", "mid", "base"
    let note: NoteContentDTO? // Das verschachtelte Objekt
    
    enum CodingKeys: String, CodingKey {
        case noteType = "note_type"
        case note = "notes" // Supabase nennt das Feld so wie die Tabelle
    }
}

// 3. Brand (wie vorher)
struct BrandDTO: Codable {
    let id: UUID
    let name: String
    let country: String?
}

// 4. Das Haupt-DTO
struct PerfumeDTO: Codable, Identifiable {
    let id: UUID
    let name: String
    let concentration: String?
    let longevity: String?
    let sillage: String?
    let performance: Double?
    let description: String?
    let imageUrl: String?
    let occasions: [String]?
    
    let brand: BrandDTO?
    
    // NEU: Liste der Verknüpfungen
    let perfumeNotes: [PerfumeNoteJunctionDTO]?
    
    enum CodingKeys: String, CodingKey {
        case id, name, concentration, longevity, sillage, performance, occasions
        case description = "desc"
        case brand = "brands"
        case perfumeNotes = "perfume_notes"
        case imageUrl = "image_url"
    }
}
