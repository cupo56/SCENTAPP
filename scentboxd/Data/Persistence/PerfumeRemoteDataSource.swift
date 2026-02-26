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
        
        // Notes-Filter: IDs einschränken falls aktiv
        if !filter.noteNames.isEmpty {
            let matchingIds = try await fetchPerfumeIdsByNotes(filter.noteNames)
            if matchingIds.isEmpty {
                return 0
            }
            query = query.in("id", values: matchingIds)
        }
        
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
        
        // Notes-Filter: IDs einschränken falls aktiv
        if !filter.noteNames.isEmpty {
            let matchingIds = try await fetchPerfumeIdsByNotes(filter.noteNames)
            if matchingIds.isEmpty {
                return []
            }
            query = query.in("id", values: matchingIds)
        }
        
        let (orderColumn, ascending) = sortParameters(for: sort)
        
        let dtos: [PerfumeDTO] = try await query
            .order(orderColumn, ascending: ascending)
            .range(from: from, to: to)
            .execute()
            .value
        
        return dtos.map { mapDTO($0) }
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
        
        // Notes-Filter: IDs einschränken falls aktiv
        if !filter.noteNames.isEmpty {
            let matchingIds = try await fetchPerfumeIdsByNotes(filter.noteNames)
            if matchingIds.isEmpty {
                return []
            }
            dbQuery = dbQuery.in("id", values: matchingIds)
        }
        
        let (orderColumn, ascending) = sortParameters(for: sort)
        
        let dtos: [PerfumeDTO] = try await dbQuery
            .order(orderColumn, ascending: ascending)
            .range(from: from, to: to)
            .execute()
            .value
        
        return dtos.map { mapDTO($0) }
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
        
        // Rating-Range-Filter (server-seitig auf performance)
        if let minRating = filter.minRating {
            q = q.gte("performance", value: minRating)
        }
        if let maxRating = filter.maxRating {
            q = q.lte("performance", value: maxRating)
        }
        
        // Occasions-Filter (server-seitig via Array-Contains)
        if !filter.occasions.isEmpty {
            q = q.contains("occasions", value: filter.occasions)
        }
        
        return q
    }
    
    // MARK: - Notes-Filter (Two-Step: IDs ermitteln, dann filtern)
    
    /// Ermittelt Parfum-IDs, die mindestens eine der angegebenen Noten enthalten.
    /// Wird als Vorstufe genutzt, um die Hauptabfrage mit `.in("id")` einzuschränken.
    private func fetchPerfumeIdsByNotes(_ noteNames: [String]) async throws -> [UUID] {
        struct PerfumeNoteIdDTO: Codable {
            let perfumeId: UUID
            
            enum CodingKeys: String, CodingKey {
                case perfumeId = "perfume_id"
            }
        }
        
        // Case-insensitiv: or-Filter mit ilike pro Note
        let orConditions = noteNames
            .map { "name.ilike.\(sanitize($0))" }
            .joined(separator: ",")
        
        let results: [PerfumeNoteIdDTO] = try await client
            .from("perfume_notes")
            .select("perfume_id, notes!inner(name)")
            .or(orConditions, referencedTable: "notes")
            .execute()
            .value
        
        // Deduplizieren
        return Array(Set(results.map(\.perfumeId)))
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
