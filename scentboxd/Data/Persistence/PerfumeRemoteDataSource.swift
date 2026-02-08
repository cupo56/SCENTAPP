import Foundation
import Supabase

@MainActor
class PerfumeRemoteDataSource: PerfumeRepository {
    private let client = AppConfig.client
    
    private let selectQuery = "*, brands(*), perfume_notes(note_type, notes(*))"
    
    // MARK: - Paginated Fetch
    
    func fetchPerfumes(page: Int, pageSize: Int) async throws -> [Perfume] {
        let from = page * pageSize
        let to = from + pageSize - 1
        
        let dtos: [PerfumeDTO] = try await client
            .from("perfumes")
            .select(selectQuery)
            .order("name")
            .range(from: from, to: to)
            .execute()
            .value
        
        return dtos.map { mapDTO($0) }
    }
    
    // MARK: - Server-Side Search
    
    func searchPerfumes(query: String, page: Int, pageSize: Int) async throws -> [Perfume] {
        let from = page * pageSize
        let to = from + pageSize - 1
        let pattern = "%\(query)%"
        
        let dtos: [PerfumeDTO] = try await client
            .from("perfumes")
            .select(selectQuery)
            .ilike("name", pattern: pattern)
            .order("name")
            .range(from: from, to: to)
            .execute()
            .value
        
        return dtos.map { mapDTO($0) }
    }
    
    // MARK: - Legacy (loads entire catalogue)
    
    func fetchAllPerfumes() async throws -> [Perfume] {
        let dtos: [PerfumeDTO] = try await client
            .from("perfumes")
            .select(selectQuery)
            .execute()
            .value
        
        return dtos.map { mapDTO($0) }
    }
    
    // MARK: - Mapping
    
    private func mapDTO(_ dto: PerfumeDTO) -> Perfume {
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
            func extractNotes(type: String) -> [Note] {
                return notesJunction
                    .filter { $0.noteType == type }
                    .compactMap { junction -> Note? in
                        guard let noteData = junction.note else { return nil }
                        return Note(name: noteData.name, category: noteData.category)
                    }
            }
            
            perfume.topNotes = extractNotes(type: "top")
            perfume.midNotes = extractNotes(type: "mid")
            perfume.baseNotes = extractNotes(type: "base")
        }
        
        return perfume
    }
    
    // ... restliche Funktionen (addPerfume, deletePerfume) bleiben leer ...
    func addPerfume(_ perfume: Perfume) async throws {}
    func deletePerfume(_ perfume: Perfume) async throws {}
}
