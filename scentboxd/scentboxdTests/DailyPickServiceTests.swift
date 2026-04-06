//
//  DailyPickServiceTests.swift
//  scentboxdTests
//
//  Unit Tests für den DailyPick Scoring-Algorithmus.
//

import XCTest
import SwiftData
@testable import scentboxd

@MainActor
final class DailyPickServiceTests: XCTestCase {

    private var service: DailyPickService!
    private var container: ModelContainer!

    override func setUp() async throws {
        service = DailyPickService()
        container = try TestFactory.makeModelContainer()
    }

    // MARK: - Empty Collection

    func testEmptyCollection_noRecommendations() {
        let criteria = makeCriteria(occasion: .casual, season: .summer)
        let results = service.calculateRecommendations(
            ownedPerfumes: [],
            criteria: criteria
        )
        XCTAssertTrue(results.isEmpty, "Leere Sammlung sollte keine Empfehlungen liefern")
    }

    // MARK: - Seasonal Note Matching

    func testSummerHot_prefersCitrusFresh() throws {
        let context = container.mainContext

        // Parfum mit Citrus-Noten (Sommer-passend)
        let citrusPerfume = TestFactory.makePerfume(name: "Summer Vibes", sillage: "Leicht", performance: 4.0)
        let citrusNote = Note(name: "Bergamot", category: "Citrus")
        let freshNote = Note(name: "Marine", category: "Aquatic")
        context.insert(citrusPerfume)
        context.insert(citrusNote)
        context.insert(freshNote)
        citrusPerfume.topNotes = [citrusNote, freshNote]

        // Parfum mit Woody-Noten (nicht Sommer-passend)
        let woodyPerfume = TestFactory.makePerfume(name: "Winter Warmth", sillage: "Stark", performance: 4.0)
        let woodyNote = Note(name: "Sandalwood", category: "Woody")
        let spicyNote = Note(name: "Cinnamon", category: "Spicy")
        context.insert(woodyPerfume)
        context.insert(woodyNote)
        context.insert(spicyNote)
        woodyPerfume.topNotes = [woodyNote, spicyNote]

        let criteria = makeCriteria(occasion: .casual, season: .summer, temperature: 32)

        // Citrus Noten-Score soll höher sein als Woody im Sommer
        let citrusScore = service.notePassungScore(perfume: citrusPerfume, season: .summer)
        let woodyScore = service.notePassungScore(perfume: woodyPerfume, season: .summer)

        XCTAssertGreaterThan(citrusScore, woodyScore,
            "Citrus-Noten sollten im Sommer besser abschneiden als Woody-Noten")
    }

    func testWinterCold_prefersWoodyOriental() throws {
        let context = container.mainContext

        let woodyPerfume = TestFactory.makePerfume(name: "Oud Nights", sillage: "Stark", performance: 4.5)
        let oudNote = Note(name: "Oud", category: "Woody")
        let amberNote = Note(name: "Amber", category: "Oriental")
        context.insert(woodyPerfume)
        context.insert(oudNote)
        context.insert(amberNote)
        woodyPerfume.topNotes = [oudNote]
        woodyPerfume.baseNotes = [amberNote]

        let freshPerfume = TestFactory.makePerfume(name: "Ocean Breeze", sillage: "Leicht", performance: 3.5)
        let marineNote = Note(name: "Sea Salt", category: "Aquatic")
        context.insert(freshPerfume)
        context.insert(marineNote)
        freshPerfume.topNotes = [marineNote]

        let woodyScore = service.notePassungScore(perfume: woodyPerfume, season: .winter)
        let freshScore = service.notePassungScore(perfume: freshPerfume, season: .winter)

        XCTAssertGreaterThan(woodyScore, freshScore,
            "Woody/Oriental-Noten sollten im Winter besser abschneiden als aquatische Noten")
    }

    // MARK: - Sillage Matching

    func testWorkOccasion_prefersLightSillage() {
        let lightPerfume = TestFactory.makePerfume(name: "Office Light", sillage: "Leicht", performance: 3.5)
        let heavyPerfume = TestFactory.makePerfume(name: "Club Bomb", sillage: "Stark", performance: 4.5)

        let lightScore = service.sillagePassungScore(perfume: lightPerfume, occasion: .work)
        let heavyScore = service.sillagePassungScore(perfume: heavyPerfume, occasion: .work)

        XCTAssertGreaterThan(lightScore, heavyScore,
            "Leichte Sillage sollte für Arbeit besser passen als starke Sillage")
    }

    func testDateOccasion_prefersStrongSillage() {
        let lightPerfume = TestFactory.makePerfume(name: "Subtle Touch", sillage: "Leicht", performance: 3.5)
        let strongPerfume = TestFactory.makePerfume(name: "Seductive Night", sillage: "Stark", performance: 4.5)

        let lightScore = service.sillagePassungScore(perfume: lightPerfume, occasion: .date)
        let strongScore = service.sillagePassungScore(perfume: strongPerfume, occasion: .date)

        XCTAssertGreaterThan(strongScore, lightScore,
            "Starke Sillage sollte für Date besser passen als leichte Sillage")
    }

    // MARK: - Score Ordering

    func testScoreOrdering() throws {
        let context = container.mainContext

        // 3 Parfums mit unterschiedlicher Performance
        let parfums = (1...3).map { i in
            TestFactory.makePerfume(name: "Parfum \(i)", performance: Double(i) * 1.5)
        }
        parfums.forEach { context.insert($0) }

        let criteria = makeCriteria(occasion: .casual, season: .summer)
        let results = service.calculateRecommendations(
            ownedPerfumes: parfums,
            criteria: criteria,
            maxResults: 3
        )

        XCTAssertEqual(results.count, 3, "Alle 3 Parfums sollten empfohlen werden")

        // Scores sollten absteigend sortiert sein
        for i in 0..<(results.count - 1) {
            XCTAssertGreaterThanOrEqual(
                results[i].score,
                results[i + 1].score,
                "Ergebnisse sollten nach Score absteigend sortiert sein"
            )
        }
    }

    // MARK: - Random Bonus

    func testRandomBonus_variesRecommendations() throws {
        let context = container.mainContext

        // 5 identische Parfums — durch Random-Bonus sollte die Reihenfolge variieren
        let parfums = (1...5).map { i in
            TestFactory.makePerfume(name: "Clone \(i)", performance: 3.0)
        }
        parfums.forEach { context.insert($0) }

        let criteria = makeCriteria(occasion: .casual, season: .summer)

        // Mehrere Durchläufe → mindestens einmal soll die Reihenfolge anders sein
        var orderings = Set<String>()
        for _ in 0..<20 {
            let results = service.calculateRecommendations(
                ownedPerfumes: parfums,
                criteria: criteria,
                maxResults: 5
            )
            let ordering = results.map(\.perfume.name).joined(separator: ",")
            orderings.insert(ordering)
        }

        XCTAssertGreaterThan(orderings.count, 1,
            "Random-Bonus sollte für Variation in den Empfehlungen sorgen")
    }

    // MARK: - Season Detection

    func testSeasonDetection() {
        // Januar → Winter
        let jan = dateFromMonth(1)
        XCTAssertEqual(Season.from(date: jan), .winter)

        // April → Frühling
        let apr = dateFromMonth(4)
        XCTAssertEqual(Season.from(date: apr), .spring)

        // Juli → Sommer
        let jul = dateFromMonth(7)
        XCTAssertEqual(Season.from(date: jul), .summer)

        // Oktober → Herbst
        let oct = dateFromMonth(10)
        XCTAssertEqual(Season.from(date: oct), .autumn)

        // Dezember → Winter
        let dec = dateFromMonth(12)
        XCTAssertEqual(Season.from(date: dec), .winter)
    }

    // MARK: - Helpers

    private func makeCriteria(
        occasion: Occasion,
        season: Season,
        temperature: Double? = nil,
        humidity: Double? = nil
    ) -> DailyPickCriteria {
        DailyPickCriteria(
            temperature: temperature,
            humidity: humidity,
            occasion: occasion,
            timeOfDay: .afternoon,
            season: season
        )
    }

    private func dateFromMonth(_ month: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = month
        components.day = 15
        return Calendar.current.date(from: components) ?? Date()
    }
}
