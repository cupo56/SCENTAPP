import Foundation
import Supabase

@MainActor
class PerfumeRemoteDataSource: PerfumeRepository {
    private let client = AppConfig.client
    
    private let selectQuery = "*, brands(*), perfume_notes(note_type, notes(*))"
    
    // MARK: - Paginated Fetch
    
    func fetchTotalCount(searchQuery: String? = nil, filter: PerfumeFilter = PerfumeFilter()) async throws -> Int {
        var query = client
            .from("perfumes")
            .select("id", head: true, count: .exact)
        
        // Textsuche
        if let search = searchQuery, !search.isEmpty {
            let sanitized = sanitize(search)
            query = query.ilike("name", pattern: "%\(sanitized)%")
        }
        
        // Server-seitige Filter
        query = applyServerFilters(to: query, filter: filter)
        
        let response = try await query.execute()
        return response.count ?? 0
    }
    
    func fetchPerfumes(page: Int, pageSize: Int, filter: PerfumeFilter = PerfumeFilter(), sort: PerfumeSortOption = .nameAsc) async throws -> [Perfume] {
        let from = page * pageSize
        let to = from + pageSize - 1
        
        var query = client
            .from("perfumes")
            .select(selectQuery)
        
        query = applyServerFilters(to: query, filter: filter)
        
        let (orderColumn, ascending) = sortParameters(for: sort)
        
        let dtos: [PerfumeDTO] = try await query
            .order(orderColumn, ascending: ascending)
            .range(from: from, to: to)
            .execute()
            .value
        
        let perfumes = dtos.map { mapDTO($0) }
        return applyClientFilters(perfumes, filter: filter)
    }
    
    // MARK: - Server-Side Search
    
    func searchPerfumes(query: String, page: Int, pageSize: Int, filter: PerfumeFilter = PerfumeFilter(), sort: PerfumeSortOption = .nameAsc) async throws -> [Perfume] {
        let from = page * pageSize
        let to = from + pageSize - 1
        let sanitized = sanitize(query)
        
        var dbQuery = client
            .from("perfumes")
            .select(selectQuery)
            .ilike("name", pattern: "%\(sanitized)%")
        
        dbQuery = applyServerFilters(to: dbQuery, filter: filter)
        
        let (orderColumn, ascending) = sortParameters(for: sort)
        
        let dtos: [PerfumeDTO] = try await dbQuery
            .order(orderColumn, ascending: ascending)
            .range(from: from, to: to)
            .execute()
            .value
        
        let perfumes = dtos.map { mapDTO($0) }
        return applyClientFilters(perfumes, filter: filter)
    }
    
    // MARK: - Metadata für Filter-Picker
    
    func fetchAvailableBrands() async throws -> [String] {
        struct BrandNameDTO: Codable {
            let name: String
        }
        let results: [BrandNameDTO] = try await client
            .from("brands")
            .select("name")
            .order("name")
            .execute()
            .value
        return results.map(\.name)
    }
    
    func fetchAvailableConcentrations() async throws -> [String] {
        struct ConcentrationDTO: Codable {
            let concentration: String
        }
        let results: [ConcentrationDTO] = try await client
            .from("perfumes")
            .select("concentration")
            .not("concentration", operator: .is, value: "null")
            .order("concentration")
            .execute()
            .value
        
        return Array(Set(results.map(\.concentration))).sorted()
    }
    
    // MARK: - Server-Side Filter Builder
    
    private func applyServerFilters(to query: PostgrestFilterBuilder, filter: PerfumeFilter) -> PostgrestFilterBuilder {
        var q = query
        
        if let brand = filter.brandName, !brand.isEmpty {
            q = q.eq("brands.name", value: brand)
        }
        if let concentration = filter.concentration, !concentration.isEmpty {
            q = q.ilike("concentration", pattern: concentration)
        }
        if let longevity = filter.longevity, !longevity.isEmpty {
            q = q.ilike("longevity", pattern: longevity)
        }
        if let sillage = filter.sillage, !sillage.isEmpty {
            q = q.ilike("sillage", pattern: sillage)
        }
        
        return q
    }
    
    /// Gibt Spalte und Richtung für `.order()` zurück
    private func sortParameters(for sort: PerfumeSortOption) -> (column: String, ascending: Bool) {
        switch sort {
        case .nameAsc:     return ("name", true)
        case .nameDesc:    return ("name", false)
        case .ratingDesc:  return ("performance", false)
        case .ratingAsc:   return ("performance", true)
        case .newest:      return ("created_at", false)
        case .popular:     return ("performance", false)
        }
    }
    
    // MARK: - Client-Side Filters (Notes, Occasions, Rating Range)
    
    private func applyClientFilters(_ perfumes: [Perfume], filter: PerfumeFilter) -> [Perfume] {
        var results = perfumes
        
        // Noten-Filter
        if !filter.noteNames.isEmpty {
            let lowerNotes = Set(filter.noteNames.map { $0.lowercased() })
            results = results.filter { perfume in
                let allNotes = (perfume.topNotes + perfume.midNotes + perfume.baseNotes)
                    .map { $0.name.lowercased() }
                return !lowerNotes.isDisjoint(with: allNotes)
            }
        }
        
        // Occasions-Filter
        if !filter.occasions.isEmpty {
            let lowerOccasions = Set(filter.occasions.map { $0.lowercased() })
            results = results.filter { perfume in
                let perfumeOccasions = Set(perfume.occasions.map { $0.lowercased() })
                return !lowerOccasions.isDisjoint(with: perfumeOccasions)
            }
        }
        
        // Rating-Range-Filter (basierend auf performance-Feld)
        if let minRating = filter.minRating {
            results = results.filter { $0.performance >= minRating }
        }
        if let maxRating = filter.maxRating {
            results = results.filter { $0.performance <= maxRating }
        }
        
        return results
    }
    
    // MARK: - Helpers
    
    private func sanitize(_ input: String) -> String {
        input
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
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
            occasions: dto.occasions ?? [],
            imageUrl: dto.imageUrl.flatMap { URL(string: $0) }
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
    
}
