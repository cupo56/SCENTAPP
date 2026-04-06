import Foundation
import SwiftData

@MainActor
final class PerfumeResolver {
    private let repository: PerfumeRepository

    init(repository: PerfumeRepository) {
        self.repository = repository
    }

    func resolvePerfume(id: UUID, modelContext: ModelContext) async throws -> Perfume? {
        try await resolvePerfumes(ids: [id], modelContext: modelContext).first
    }

    func resolvePerfumes(ids: [UUID], modelContext: ModelContext) async throws -> [Perfume] {
        var seenIds = Set<UUID>()
        let orderedIds = ids.filter { seenIds.insert($0).inserted }
        guard !orderedIds.isEmpty else { return [] }

        let allPerfumes = try modelContext.fetch(FetchDescriptor<Perfume>())
        var perfumeLookup = Dictionary(
            uniqueKeysWithValues: allPerfumes.map { ($0.id, $0) }
        )

        let missingIds = orderedIds.filter { perfumeLookup[$0] == nil }

        if !missingIds.isEmpty {
            let remotePerfumes = try await repository.fetchPerfumesByIds(missingIds)
            var brandLookup = try buildBrandLookup(modelContext: modelContext)
            var noteLookup = try buildNoteLookup(modelContext: modelContext)

            for remotePerfume in remotePerfumes {
                let target = perfumeLookup[remotePerfume.id] ?? {
                    let perfume = Perfume(
                        id: remotePerfume.id,
                        name: remotePerfume.name,
                        concentration: remotePerfume.concentration,
                        longevity: remotePerfume.longevity,
                        sillage: remotePerfume.sillage,
                        performance: remotePerfume.performance,
                        desc: remotePerfume.desc,
                        occasions: remotePerfume.occasions,
                        imageUrl: remotePerfume.imageUrl
                    )
                    modelContext.insert(perfume)
                    perfumeLookup[perfume.id] = perfume
                    return perfume
                }()

                update(target: target, with: remotePerfume, brandLookup: &brandLookup, noteLookup: &noteLookup, modelContext: modelContext)
            }

            try modelContext.save()
        }

        return orderedIds.compactMap { perfumeLookup[$0] }
    }

    private func update(
        target: Perfume,
        with remote: Perfume,
        brandLookup: inout [String: Brand],
        noteLookup: inout [String: Note],
        modelContext: ModelContext
    ) {
        target.name = remote.name
        target.concentration = remote.concentration
        target.longevity = remote.longevity
        target.sillage = remote.sillage
        target.performance = remote.performance
        target.desc = remote.desc
        target.occasions = remote.occasions
        target.imageUrl = remote.imageUrl

        if let remoteBrand = remote.brand {
            target.brand = resolveOrCreateBrand(
                name: remoteBrand.name,
                country: remoteBrand.country,
                lookup: &brandLookup,
                modelContext: modelContext
            )
        } else {
            target.brand = nil
        }

        target.topNotes = remote.topNotes.map {
            resolveOrCreateNote(name: $0.name, category: $0.category, lookup: &noteLookup, modelContext: modelContext)
        }
        target.midNotes = remote.midNotes.map {
            resolveOrCreateNote(name: $0.name, category: $0.category, lookup: &noteLookup, modelContext: modelContext)
        }
        target.baseNotes = remote.baseNotes.map {
            resolveOrCreateNote(name: $0.name, category: $0.category, lookup: &noteLookup, modelContext: modelContext)
        }
    }

    private func buildBrandLookup(modelContext: ModelContext) throws -> [String: Brand] {
        let allBrands = try modelContext.fetch(FetchDescriptor<Brand>())
        return Dictionary(allBrands.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private func buildNoteLookup(modelContext: ModelContext) throws -> [String: Note] {
        let allNotes = try modelContext.fetch(FetchDescriptor<Note>())
        return Dictionary(allNotes.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private func resolveOrCreateBrand(
        name: String,
        country: String?,
        lookup: inout [String: Brand],
        modelContext: ModelContext
    ) -> Brand {
        if let existing = lookup[name] {
            existing.country = country
            return existing
        }

        let brand = Brand(name: name, country: country)
        modelContext.insert(brand)
        lookup[name] = brand
        return brand
    }

    private func resolveOrCreateNote(
        name: String,
        category: String?,
        lookup: inout [String: Note],
        modelContext: ModelContext
    ) -> Note {
        if let existing = lookup[name] {
            existing.category = category
            return existing
        }

        let note = Note(name: name, category: category)
        modelContext.insert(note)
        lookup[name] = note
        return note
    }
}
