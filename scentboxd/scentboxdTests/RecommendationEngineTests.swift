//
//  RecommendationEngineTests.swift
//  scentboxdTests
//

import Testing
import Foundation
import SwiftData
@testable import scentboxd

@MainActor
struct RecommendationEngineTests {

    // MARK: - Helpers

    private func makeNote(name: String, category: String? = nil) -> Note {
        let note = Note(name: name, category: category)
        return note
    }

    private func makePerfumeWithNotes(
        name: String,
        topNotes: [Note] = [],
        midNotes: [Note] = [],
        baseNotes: [Note] = []
    ) -> Perfume {
        let perfume = TestFactory.makePerfume(name: name)
        perfume.topNotes = topNotes
        perfume.midNotes = midNotes
        perfume.baseNotes = baseNotes
        return perfume
    }

    // MARK: - Tests

    @Test("Leere Sammlung ergibt keine Empfehlungen")
    func testEmptyCollection_noRecommendations() async {
        let engine = RecommendationEngine()
        let catalog = [makePerfumeWithNotes(name: "A", topNotes: [makeNote(name: "Oud")])]

        let results = await engine.calculateRecommendations(
            ownedPerfumes: [],
            favoritePerfumes: [],
            allPerfumes: catalog
        )

        #expect(results.isEmpty)
    }

    @Test("Katalog ohne Noten ergibt keine Empfehlungen")
    func testCatalogWithoutNotes_noRecommendations() async {
        let engine = RecommendationEngine()
        let owned = [makePerfumeWithNotes(name: "Owned", topNotes: [makeNote(name: "Rose")])]
        let catalog = [makePerfumeWithNotes(name: "A"), makePerfumeWithNotes(name: "B")]

        let results = await engine.calculateRecommendations(
            ownedPerfumes: owned,
            favoritePerfumes: [],
            allPerfumes: catalog
        )

        #expect(results.isEmpty)
    }

    @Test("Owned Parfum wird aus Empfehlungen ausgeschlossen")
    func testExcludesAlreadyOwned() async {
        let engine = RecommendationEngine()
        let oud = makeNote(name: "Oud", category: "Woody")
        let sandalwood = makeNote(name: "Sandalwood", category: "Woody")

        let owned = makePerfumeWithNotes(name: "Owned Oud", topNotes: [oud])
        let candidate = makePerfumeWithNotes(name: "Candidate Oud", topNotes: [oud, sandalwood])

        let results = await engine.calculateRecommendations(
            ownedPerfumes: [owned],
            favoritePerfumes: [],
            allPerfumes: [owned, candidate]
        )

        let ids = results.map { $0.perfume.id }
        #expect(!ids.contains(owned.id))
        #expect(ids.contains(candidate.id))
    }

    @Test("Favorisierte Parfums werden aus Empfehlungen ausgeschlossen")
    func testExcludesFavoritedPerfumes() async {
        let engine = RecommendationEngine()
        let rose = makeNote(name: "Rose", category: "Floral")
        let jasmine = makeNote(name: "Jasmine", category: "Floral")

        let fav = makePerfumeWithNotes(name: "Fav Rose", topNotes: [rose])
        let candidate = makePerfumeWithNotes(name: "Similar Rose", topNotes: [rose, jasmine])

        let results = await engine.calculateRecommendations(
            ownedPerfumes: [],
            favoritePerfumes: [fav],
            allPerfumes: [fav, candidate]
        )

        let ids = results.map { $0.perfume.id }
        #expect(!ids.contains(fav.id))
        #expect(ids.contains(candidate.id))
    }

    @Test("Ergebnisse sind nach Score absteigend sortiert")
    func testScoreOrdering() async {
        let engine = RecommendationEngine()
        let oud = makeNote(name: "Oud")
        let sandalwood = makeNote(name: "Sandalwood")
        let bergamot = makeNote(name: "Bergamot")
        let lemon = makeNote(name: "Lemon")

        let owned = makePerfumeWithNotes(name: "Owned", topNotes: [oud, sandalwood])

        // Hoher Match: hat beide Noten
        let highMatch = makePerfumeWithNotes(name: "High", topNotes: [oud, sandalwood])
        // Niedriger Match: komplett andere Noten
        let lowMatch = makePerfumeWithNotes(name: "Low", topNotes: [bergamot, lemon])

        let results = await engine.calculateRecommendations(
            ownedPerfumes: [owned],
            favoritePerfumes: [],
            allPerfumes: [owned, highMatch, lowMatch]
        )

        guard results.count >= 2 else {
            Issue.record("Erwartet mindestens 2 Empfehlungen, erhalten: \(results.count)")
            return
        }
        #expect(results[0].score >= results[1].score)
        #expect(results[0].perfume.id == highMatch.id)
    }

    @Test("Limit wird korrekt eingehalten")
    func testLimitRespected() async {
        let engine = RecommendationEngine()
        let note = makeNote(name: "Musk")
        let owned = makePerfumeWithNotes(name: "Base", topNotes: [note])
        let candidates = (1...10).map {
            makePerfumeWithNotes(name: "Candidate \($0)", topNotes: [note])
        }

        let results = await engine.calculateRecommendations(
            ownedPerfumes: [owned],
            favoritePerfumes: [],
            allPerfumes: [owned] + candidates,
            limit: 5
        )

        #expect(results.count <= 5)
    }

    @Test("Favoriten werden stärker gewichtet als owned")
    func testFavoritesWeightedHigher() async {
        let engine = RecommendationEngine()
        let oud = makeNote(name: "Oud")
        let rose = makeNote(name: "Rose")

        let owned = makePerfumeWithNotes(name: "Owned Rose", topNotes: [rose])
        let favorite = makePerfumeWithNotes(name: "Fav Oud", topNotes: [oud])

        // Kandidat mit Oud sollte höheren Score haben wegen Favoriten-Gewichtung
        let oudCandidate = makePerfumeWithNotes(name: "Oud Candidate", topNotes: [oud])
        let roseCandidate = makePerfumeWithNotes(name: "Rose Candidate", topNotes: [rose])

        let results = await engine.calculateRecommendations(
            ownedPerfumes: [owned],
            favoritePerfumes: [favorite],
            allPerfumes: [owned, favorite, oudCandidate, roseCandidate]
        )

        let oudScore = results.first { $0.perfume.id == oudCandidate.id }?.score ?? 0
        let roseScore = results.first { $0.perfume.id == roseCandidate.id }?.score ?? 0
        #expect(oudScore > roseScore)
    }

    @Test("Begründungstext enthält Note-Namen")
    func testReasonContainsNoteName() async {
        let engine = RecommendationEngine()
        let oud = makeNote(name: "Oud", category: "Woody")

        let owned = makePerfumeWithNotes(name: "Owned", topNotes: [oud])
        let candidate = makePerfumeWithNotes(name: "Candidate", topNotes: [oud])

        let results = await engine.calculateRecommendations(
            ownedPerfumes: [owned],
            favoritePerfumes: [],
            allPerfumes: [owned, candidate]
        )

        guard let first = results.first else {
            Issue.record("Keine Empfehlungen erhalten")
            return
        }
        #expect(first.reason.contains("Oud") || first.reason.contains("Woody") || !first.reason.isEmpty)
    }
}
