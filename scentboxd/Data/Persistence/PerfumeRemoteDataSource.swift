import Foundation
import Supabase

@MainActor
class PerfumeRemoteDataSource: PerfumeRepository {
    private let client = AppConfig.client
    
    private let selectQuery = "*, brands(*), perfume_notes(note_type, notes(*))"
    
    // MARK: - Paginated Fetch
    
    // MARK: - Paginated Fetch
    
    func fetchTotalCount(searchQuery: String?, filter: PerfumeFilter) async throws -> Int {
        var query = client
            .from("perfumes")
            .select("id", head: true, count: .exact)

        // Brand-ID vorab auflösen
        let brandId = try await resolveBrandId(from: filter)

        // Textsuche (Name + Marke)
        if let search = searchQuery, !search.isEmpty {
            let sanitized = sanitize(search)
            let matchingBrandIds = try await fetchBrandIds(matching: sanitized)
            if matchingBrandIds.isEmpty {
                query = query.ilike("name", pattern: "%\(sanitized)%")
            } else {
                query = query.or("name.ilike.%\(sanitized)%,brand_id.in.(\(matchingBrandIds.map(\.uuidString).joined(separator: ",")))")
            }
        }

        // Server-seitige Filter
        query = applyServerFilters(to: query, filter: filter, brandId: brandId)
        
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
    
    func fetchPerfumes(page: Int, pageSize: Int, filter: PerfumeFilter, sort: PerfumeSortOption) async throws -> [Perfume] {
        let from = page * pageSize
        let end = from + pageSize - 1

        let brandId = try await resolveBrandId(from: filter)

        var query = client
            .from("perfumes")
            .select(selectQuery)

        query = applyServerFilters(to: query, filter: filter, brandId: brandId)

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
            .range(from: from, to: end)
            .execute()
            .value

        return dtos.map { mapDTO($0) }
    }

    // MARK: - Server-Side Search
    
    func searchPerfumes(query: String, page: Int, pageSize: Int, filter: PerfumeFilter, sort: PerfumeSortOption) async throws -> [Perfume] {
        let from = page * pageSize
        let end = from + pageSize - 1
        let sanitized = sanitize(query)

        // Brand-IDs suchen, die zum Suchbegriff passen
        let matchingBrandIds = try await fetchBrandIds(matching: sanitized)

        // Kombinierte Suche: Name ODER Brand-ID
        var dbQuery: PostgrestFilterBuilder
        if matchingBrandIds.isEmpty {
            dbQuery = client
                .from("perfumes")
                .select(selectQuery)
                .ilike("name", pattern: "%\(sanitized)%")
        } else {
            dbQuery = client
                .from("perfumes")
                .select(selectQuery)
                .or("name.ilike.%\(sanitized)%,brand_id.in.(\(matchingBrandIds.map(\.uuidString).joined(separator: ",")))")
        }

        let brandId = try await resolveBrandId(from: filter)
        dbQuery = applyServerFilters(to: dbQuery, filter: filter, brandId: brandId)
        
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
            .range(from: from, to: end)
            .execute()
            .value

        return dtos.map { mapDTO($0) }
    }

    func fetchSearchSuggestions(query: String) async throws -> [SearchSuggestionDTO] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else { return [] }

        let params: [String: AnyJSON] = [
            "search_query": .string(trimmedQuery),
            "max_results": .integer(5)
        ]

        let suggestions: [SearchSuggestionDTO] = try await client
            .rpc("search_suggestions", params: params)
            .execute()
            .value

        return suggestions
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
    
    private func applyServerFilters(to query: PostgrestFilterBuilder, filter: PerfumeFilter, brandId: UUID? = nil) -> PostgrestFilterBuilder {
        var filtered = query

        if let id = brandId {
            filtered = filtered.eq("brand_id", value: id.uuidString)
        }
        if let concentration = filter.concentration, !concentration.isEmpty {
            filtered = filtered.ilike("concentration", pattern: concentration)
        }
        if let longevity = filter.longevity, !longevity.isEmpty {
            filtered = filtered.ilike("longevity", pattern: longevity)
        }
        if let sillage = filter.sillage, !sillage.isEmpty {
            filtered = filtered.ilike("sillage", pattern: sillage)
        }

        // Rating-Range-Filter (server-seitig auf performance)
        if let minRating = filter.minRating {
            filtered = filtered.gte("performance", value: minRating)
        }
        if let maxRating = filter.maxRating {
            filtered = filtered.lte("performance", value: maxRating)
        }

        // Occasions-Filter (server-seitig via Array-Contains)
        if !filter.occasions.isEmpty {
            filtered = filtered.contains("occasions", value: filter.occasions)
        }

        return filtered
    }
    
    // MARK: - Notes-Filter (Two-Step: IDs ermitteln, dann filtern)
    
    /// Ermittelt Parfum-IDs, die mindestens eine der angegebenen Noten enthalten.
    /// Wird als Vorstufe genutzt, um die Hauptabfrage mit `.in("id")` einzuschränken.
    private func fetchPerfumeIdsByNotes(_ noteNames: [String]) async throws -> [UUID] {
        struct PerfumeNoteIdDTO: Codable { // swiftlint:disable:this nesting
            let perfumeId: UUID

            enum CodingKeys: String, CodingKey { // swiftlint:disable:this nesting
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
    
    /// Löst den Brand-Namen aus dem Filter zu einer exakten Brand-ID auf.
    private func resolveBrandId(from filter: PerfumeFilter) async throws -> UUID? {
        guard let brand = filter.brandName, !brand.isEmpty else { return nil }
        struct BrandIdDTO: Codable { let id: UUID }
        let results: [BrandIdDTO] = try await client
            .from("brands")
            .select("id")
            .eq("name", value: brand)
            .limit(1)
            .execute()
            .value
        return results.first?.id
    }

    /// Brand-IDs suchen, die zum Suchbegriff passen
    private func fetchBrandIds(matching query: String) async throws -> [UUID] {
        struct BrandIdDTO: Codable {
            let id: UUID
        }
        let results: [BrandIdDTO] = try await client
            .from("brands")
            .select("id")
            .ilike("name", pattern: "%\(query)%")
            .execute()
            .value
        return results.map(\.id)
    }

    /// Sanitizes user input for use in PostgREST filter strings.
    /// Escapes LIKE wildcards and strips PostgREST metacharacters that could
    /// alter filter logic when interpolated into `.or()` expressions.
    private func sanitize(_ input: String) -> String {
        input
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
            .filter { $0 != "," && $0 != "(" && $0 != ")" }
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
            imageUrl: dto.imageUrl.flatMap { URL(string: $0) }.flatMap { $0.scheme == "https" ? $0 : nil }
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

    // MARK: - Fetch by IDs

    func fetchPerfumesByIds(_ ids: [UUID]) async throws -> [Perfume] {
        guard !ids.isEmpty else { return [] }

        let dtos: [PerfumeDTO] = try await client
            .from("perfumes")
            .select(selectQuery)
            .in("id", values: ids)
            .execute()
            .value

        return dtos.map { mapDTO($0) }
    }

    // MARK: - Barcode Lookup

    func fetchPerfumeByBarcode(ean: String) async throws -> Perfume? {
        let dtos: [PerfumeDTO] = try await client
            .from("perfumes")
            .select(selectQuery)
            .eq("ean", value: ean)
            .limit(1)
            .execute()
            .value
        return dtos.first.map { mapDTO($0) }
    }

    // MARK: - Similar Perfumes

    func fetchSimilarPerfumes(for perfumeId: UUID, limit: Int = 6) async throws -> [Perfume] {

        // 1. Hole ähnliche IDs und deren Score (Score wird vorerst nur für Sortierung in DB verwendet)
        let params: [String: AnyJSON] = [
            "p_perfume_id": .string(perfumeId.uuidString),
            "p_limit": .integer(limit)
        ]
        
        let similarDTOs: [SimilarPerfumeDTO] = try await client
            .rpc("get_similar_perfumes", params: params)
            .execute()
            .value
        
        let ids = similarDTOs.map { $0.perfumeId }
        guard !ids.isEmpty else { return [] }
        
        // 2. Lade volle Parfum-Details (um Reviews, Brands etc. zu bekommen)
        let perfumes = try await fetchPerfumesByIds(ids)
        
        // 3. Sortiere die Ergebnisse anhand der ursprünglichen Reihenfolge aus dem RPC-Call
        let idToScore = Dictionary(uniqueKeysWithValues: similarDTOs.map { ($0.perfumeId, $0.similarityScore) })
        
        return perfumes.sorted { first, second in
            let score1 = idToScore[first.id] ?? 0
            let score2 = idToScore[second.id] ?? 0
            return score1 > score2
        }
    }
}
