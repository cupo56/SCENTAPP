//
//  PerfumeCacheServiceTests.swift
//  scentboxdTests
//

import XCTest
import SwiftData
@testable import scentboxd

@MainActor
final class PerfumeCacheServiceTests: XCTestCase {

    private var sut: PerfumeCacheService!
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        container = try TestFactory.makeModelContainer()
        context = container.mainContext
        sut = PerfumeCacheService()
        // Reset UserDefaults key used by cache
        UserDefaults.standard.removeObject(forKey: "PerfumeCatalog_lastSyncedAt")
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "PerfumeCatalog_lastSyncedAt")
        try await super.tearDown()
    }

    // MARK: - needsRefresh / TTL

    func testNeedsRefreshWhenNeverSynced() {
        XCTAssertTrue(sut.needsRefresh)
    }

    func testNeedsRefreshFalseAfterRecentSync() {
        sut.lastSyncedAt = Date()
        XCTAssertFalse(sut.needsRefresh)
    }

    func testNeedsRefreshTrueAfterTTLExpired() {
        sut.lastSyncedAt = Date(timeIntervalSinceNow: -301)
        XCTAssertTrue(sut.needsRefresh)
    }

    // MARK: - cachePerfumes + loadCachedPerfumes (round-trip)

    func testCacheAndLoadPerfumes() throws {
        let perfume = TestFactory.makePerfume(name: "Aventus")
        try sut.cachePerfumes([perfume], modelContext: context)

        let loaded = try sut.loadCachedPerfumes(modelContext: context, page: 0, pageSize: 10)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, "Aventus")
    }

    func testCacheUpsertUpdatesExisting() throws {
        let id = UUID()
        let v1 = TestFactory.makePerfume(id: id, name: "V1")
        try sut.cachePerfumes([v1], modelContext: context)

        let v2 = TestFactory.makePerfume(id: id, name: "V2")
        try sut.cachePerfumes([v2], modelContext: context)

        let loaded = try sut.loadCachedPerfumes(modelContext: context, page: 0, pageSize: 10)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, "V2")
    }

    func testCacheSetsLastSyncedAt() throws {
        XCTAssertNil(sut.lastSyncedAt)
        try sut.cachePerfumes([], modelContext: context)
        XCTAssertNotNil(sut.lastSyncedAt)
    }

    // MARK: - Pagination

    func testPagination() throws {
        let perfumes = (0..<5).map { TestFactory.makePerfume(name: "P\($0)") }
        try sut.cachePerfumes(perfumes, modelContext: context)

        let page0 = try sut.loadCachedPerfumes(modelContext: context, page: 0, pageSize: 2)
        let page1 = try sut.loadCachedPerfumes(modelContext: context, page: 1, pageSize: 2)
        XCTAssertEqual(page0.count, 2)
        XCTAssertEqual(page1.count, 2)
    }

    // MARK: - Sort

    func testSortByNameAsc() throws {
        try sut.cachePerfumes([
            TestFactory.makePerfume(name: "Zara"),
            TestFactory.makePerfume(name: "Aventus")
        ], modelContext: context)

        let loaded = try sut.loadCachedPerfumes(modelContext: context, page: 0, pageSize: 10, sort: .nameAsc)
        XCTAssertEqual(loaded.first?.name, "Aventus")
        XCTAssertEqual(loaded.last?.name, "Zara")
    }

    func testSortByNameDesc() throws {
        try sut.cachePerfumes([
            TestFactory.makePerfume(name: "Aventus"),
            TestFactory.makePerfume(name: "Zara")
        ], modelContext: context)

        let loaded = try sut.loadCachedPerfumes(modelContext: context, page: 0, pageSize: 10, sort: .nameDesc)
        XCTAssertEqual(loaded.first?.name, "Zara")
        XCTAssertEqual(loaded.last?.name, "Aventus")
    }

    func testSortByRatingDesc() throws {
        try sut.cachePerfumes([
            TestFactory.makePerfume(name: "Low", performance: 2.0),
            TestFactory.makePerfume(name: "High", performance: 5.0)
        ], modelContext: context)

        let loaded = try sut.loadCachedPerfumes(modelContext: context, page: 0, pageSize: 10, sort: .ratingDesc)
        XCTAssertEqual(loaded.first?.name, "High")
    }

    // MARK: - Client-side Filters (rating)

    func testFilterByMinRating() throws {
        try sut.cachePerfumes([
            TestFactory.makePerfume(name: "Low", performance: 2.0),
            TestFactory.makePerfume(name: "High", performance: 4.5)
        ], modelContext: context)

        var filter = PerfumeFilter()
        filter.minRating = 4.0
        let loaded = try sut.loadCachedPerfumes(modelContext: context, page: 0, pageSize: 10, filter: filter)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, "High")
    }

    func testFilterByMaxRating() throws {
        try sut.cachePerfumes([
            TestFactory.makePerfume(name: "Low", performance: 2.0),
            TestFactory.makePerfume(name: "High", performance: 4.5)
        ], modelContext: context)

        var filter = PerfumeFilter()
        filter.maxRating = 3.0
        let loaded = try sut.loadCachedPerfumes(modelContext: context, page: 0, pageSize: 10, filter: filter)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, "Low")
    }

    // MARK: - Search

    func testSearchCachedPerfumes() throws {
        try sut.cachePerfumes([
            TestFactory.makePerfume(name: "Sauvage"),
            TestFactory.makePerfume(name: "Aventus")
        ], modelContext: context)

        let results = try sut.searchCachedPerfumes(
            modelContext: context, query: "Sauv", page: 0, pageSize: 10
        )
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "Sauvage")
    }

    // MARK: - Filter by concentration (predicate)

    func testFilterByConcentration() throws {
        try sut.cachePerfumes([
            TestFactory.makePerfume(name: "EDP One", concentration: "EDP"),
            TestFactory.makePerfume(name: "EDT One", concentration: "EDT")
        ], modelContext: context)

        var filter = PerfumeFilter()
        filter.concentration = "EDP"
        let loaded = try sut.loadCachedPerfumes(modelContext: context, page: 0, pageSize: 10, filter: filter)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, "EDP One")
    }

    // MARK: - Batch Lookup Reuse

    func testCachePerfumesReusesNewBrandWithinSameBatch() throws {
        let brand = Brand(name: "Dior", country: "France")
        let first = TestFactory.makePerfume(name: "Sauvage Elixir")
        first.brand = brand

        let second = TestFactory.makePerfume(name: "Sauvage")
        second.brand = Brand(name: "Dior", country: "France")

        try sut.cachePerfumes([first, second], modelContext: context)

        let brands = try context.fetch(FetchDescriptor<Brand>())
        XCTAssertEqual(brands.count, 1)
        XCTAssertEqual(brands.first?.name, "Dior")
    }

    func testCachePerfumesReusesNewNoteWithinSameBatch() throws {
        let first = TestFactory.makePerfume(name: "First")
        first.topNotes = [Note(name: "Bergamot", category: "Citrus")]

        let second = TestFactory.makePerfume(name: "Second")
        second.midNotes = [Note(name: "Bergamot", category: "Citrus")]

        try sut.cachePerfumes([first, second], modelContext: context)

        let notes = try context.fetch(FetchDescriptor<Note>())
        XCTAssertEqual(notes.count, 1)
        XCTAssertEqual(notes.first?.name, "Bergamot")
    }
}
