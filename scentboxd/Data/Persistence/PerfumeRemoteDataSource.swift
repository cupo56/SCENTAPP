import Foundation
import Supabase

@MainActor
class PerfumeRemoteDataSource: PerfumeRepository {
    private let client = AppConfig.client
    
    func fetchAllPerfumes() async throws -> [Perfume] {
        // 1. Abfrage mit tief verschachteltem Join
        // Wir holen: Parfums + Marke + (Verknüpfung + Note)
        let dtos: [PerfumeDTO] = try await client
            .from("perfumes")
            .select("*, brands(*), perfume_notes(note_type, notes(*))")
            .execute()
            .value
        
        // 2. Mapping
        return dtos.map { dto in
            let perfume = Perfume(
                id: dto.id,
                name: dto.name,
                concentration: dto.concentration,
                longevity: dto.longevity ?? "",
                sillage: dto.sillage ?? "",
                performance: dto.performance ?? 0.0,
                desc: dto.description,
                imageUrl: dto.imageUrl != nil ? URL(string: dto.imageUrl!) : nil
            )
            
            // Marke setzen
            if let brandDto = dto.brand {
                perfume.brand = Brand(name: brandDto.name, country: brandDto.country)
            }
            
            // Noten verarbeiten
            if let notesJunction = dto.perfumeNotes {
                
                // Hilfsfunktion, um aus DTOs echte Note-Objekte zu machen
                func extractNotes(type: String) -> [Note] {
                    return notesJunction
                        .filter { $0.noteType == type } // Filter nach "top", "mid", "base"
                        .compactMap { junction -> Note? in
                            guard let noteData = junction.note else { return nil }
                            return Note(name: noteData.name, category: noteData.category)
                        }
                }
                
                // Die Arrays befüllen
                perfume.topNotes = extractNotes(type: "top")
                perfume.midNotes = extractNotes(type: "mid")
                perfume.baseNotes = extractNotes(type: "base")
            }
            
            return perfume
        }
    }
    
    // ... restliche Funktionen (addPerfume, deletePerfume) bleiben leer ...
    func addPerfume(_ perfume: Perfume) async throws {}
    func deletePerfume(_ perfume: Perfume) async throws {}
}
