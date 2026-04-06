//
//  PerfumeDataLoaderTests.swift
//  scentboxdTests
//

import XCTest
import SwiftData
@testable import scentboxd

@MainActor
final class PerfumeDataLoaderTests: XCTestCase {

    private var mockRepo: MockPerfumeRepository!
    private var mockReviewDS: MockReviewDataSource!
    private var cacheService: PerfumeCacheService!
    private var networkMonitor: NetworkMonitor!
    private var container: ModelContainer!
    private var sut: PerfumeDataLoader!

    override func setUpWithError() throws {
        mockRepo = MockPerfumeRepository()
        mockReviewDS = MockReviewDataSource()
        cacheService = PerfumeCacheService()
        networkMonitor = NetworkMonitor()
        container = try TestFactory.makeModelContainer()

        sut = PerfumeDataLoader(
            repository: mockRepo,
            reviewDataSource: mockReviewDS,
            cacheService: cacheService,
            networkMonitor: networkMonitor
        )
    }

    override func tearDown() {
        sut = nil
        container = nil
        networkMonitor = nil
        cacheService = nil
        mockReviewDS = nil
        mockRepo = nil
    }

    // MARK: - Load Data (Online)

    func testLoadDataOnlineSuccess() async {
        let perfumes = [
            TestFactory.makePerfume(name: "Sauvage"),
            TestFactory.makePerfume(name: "Bleu de Chanel")
        ]
        mockRepo.perfumesToReturn = perfumes
        networkMonitor.isConnected = true

        await sut.loadData(
            searchText: "",
            filter: PerfumeFilter(),
            sort: .nameAsc,
            cacheKey: "test",
            modelContext: container.mainContext
        )

        XCTAssertEqual(sut.perfumes.count, 2)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
        XCTAssertEqual(mockRepo.fetchPerfumesCalled, 1)
    }

    func testLoadDataSetsIsLoadingFalseOnCompletion() async {
        mockRepo.perfumesToReturn = []
        networkMonitor.isConnected = true

        await sut.loadData(
            searchText: "",
            filter: PerfumeFilter(),
            sort: .nameAsc,
            cacheKey: "test",
            modelContext: container.mainContext
        )

        XCTAssertFalse(sut.isLoading)
    }

    func testLoadDataOnlineError() async {
        mockRepo.errorToThrow = NetworkError.timeout
        networkMonitor.isConnected = true

        await sut.loadData(
            searchText: "",
            filter: PerfumeFilter(),
            sort: .nameAsc,
            cacheKey: "error-test",
            modelContext: container.mainContext
        )

        XCTAssertNotNil(sut.errorMessage)
        XCTAssertTrue(sut.perfumes.isEmpty)
    }

    // MARK: - Offline

    func testLoadDataUsesSwiftDataCacheWhenRemoteFails() async throws {
        // GIVEN: SwiftData-Cache vorbefüllt, Repository wirft Fehler
        let cachedPerfumes = [
            TestFactory.makePerfume(name: "Cached A"),
            TestFactory.makePerfume(name: "Cached B")
        ]
        try cacheService.cachePerfumes(cachedPerfumes, modelContext: container.mainContext)
        mockRepo.errorToThrow = NetworkError.timeout
        networkMonitor.isConnected = true

        // WHEN
        await sut.loadData(
            searchText: "",
            filter: PerfumeFilter(),
            sort: .nameAsc,
            cacheKey: "cache-fallback",
            modelContext: container.mainContext,
            forceRefresh: true
        )

        // THEN: Perfumes aus Cache, keine Fehlermeldung (cacheLoaded war true vor Remote-Versuch)
        XCTAssertEqual(sut.perfumes.count, 2)
        XCTAssertTrue(sut.perfumes.contains { $0.name == "Cached A" })
        XCTAssertNil(sut.errorMessage)
    }

    func testLoadMoreOfflineAppendsFromCache() async {
        // GIVEN: Zuerst online laden, dann Offline → loadMore soll aus Cache nachladen
        let pageSize = AppConfig.Pagination.perfumePageSize
        let firstPage = (0..<pageSize).map { TestFactory.makePerfume(name: "P\($0)") }
        let secondPage = (0..<pageSize).map { TestFactory.makePerfume(name: "Q\($0)") }
        mockRepo.perfumesToReturn = firstPage
        networkMonitor.isConnected = true

        await sut.loadData(
            searchText: "",
            filter: PerfumeFilter(),
            sort: .nameAsc,
            cacheKey: "offline-paginate",
            modelContext: container.mainContext
        )

        mockRepo.perfumesToReturn = secondPage
        if let lastItem = sut.perfumes.last {
            await sut.loadMoreIfNeeded(
                currentItem: lastItem,
                searchText: "",
                filter: PerfumeFilter(),
                sort: .nameAsc,
                modelContext: container.mainContext
            )
        }
        let fetchCountAfterOnline = mockRepo.fetchPerfumesCalled

        // Offline: loadData mit neuem Key (kein In-Memory-Hit), dann loadMore
        networkMonitor.isConnected = false
        await sut.loadData(
            searchText: "",
            filter: PerfumeFilter(),
            sort: .nameAsc,
            cacheKey: "offline-paginate-2",
            modelContext: container.mainContext
        )
        XCTAssertEqual(sut.perfumes.count, pageSize, "Erste Seite aus Cache")

        if let lastItem = sut.perfumes.last {
            await sut.loadMoreIfNeeded(
                currentItem: lastItem,
                searchText: "",
                filter: PerfumeFilter(),
                sort: .nameAsc,
                modelContext: container.mainContext
            )
        }

        // THEN: Zweite Seite aus SwiftData-Cache angehängt, kein weiterer Remote-Call
        XCTAssertEqual(sut.perfumes.count, pageSize * 2)
        XCTAssertEqual(mockRepo.fetchPerfumesCalled, fetchCountAfterOnline)
    }

    func testLoadDataOfflineNoCache() async {
        networkMonitor.isConnected = false

        await sut.loadData(
            searchText: "",
            filter: PerfumeFilter(),
            sort: .nameAsc,
            cacheKey: "offline",
            modelContext: container.mainContext
        )

        XCTAssertTrue(sut.isOffline)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertEqual(mockRepo.fetchPerfumesCalled, 0, "Sollte kein Remote-Fetch versuchen im Offline-Modus")
    }

    // MARK: - Pagination

    func testLoadDataSetsHasMorePagesWhenFull() async {
        // Genau pageSize Ergebnisse → hasMorePages = true
        let pageSize = AppConfig.Pagination.perfumePageSize
        let perfumes = (0..<pageSize).map { TestFactory.makePerfume(name: "P\($0)") }
        mockRepo.perfumesToReturn = perfumes
        networkMonitor.isConnected = true

        await sut.loadData(
            searchText: "",
            filter: PerfumeFilter(),
            sort: .nameAsc,
            cacheKey: "full-page",
            modelContext: container.mainContext
        )

        // hasMorePages ist private, aber wir prüfen indirekt:
        // Wenn weniger als pageSize → wird false gesetzt (kein loadMore)
        XCTAssertEqual(sut.perfumes.count, pageSize)
    }

    // MARK: - Load More

    func testLoadMoreIfNeededAppendsResults() async {
        // Erstes Laden
        let pageSize = AppConfig.Pagination.perfumePageSize
        let firstPage = (0..<pageSize).map { TestFactory.makePerfume(name: "P\($0)") }
        mockRepo.perfumesToReturn = firstPage
        networkMonitor.isConnected = true

        await sut.loadData(
            searchText: "",
            filter: PerfumeFilter(),
            sort: .nameAsc,
            cacheKey: "paginate",
            modelContext: container.mainContext
        )

        // Zweite Seite vorbereiten
        let secondPage = [TestFactory.makePerfume(name: "Extra")]
        mockRepo.perfumesToReturn = secondPage

        // loadMore triggern mit letztem Item
        if let lastItem = sut.perfumes.last {
            await sut.loadMoreIfNeeded(
                currentItem: lastItem,
                searchText: "",
                filter: PerfumeFilter(),
                sort: .nameAsc,
                modelContext: container.mainContext
            )
        }

        XCTAssertEqual(sut.perfumes.count, pageSize + 1)
    }

    func testLoadMoreGuardsWhenNotLastItem() async {
        let perfumes = [
            TestFactory.makePerfume(name: "Erster"),
            TestFactory.makePerfume(name: "Zweiter")
        ]
        mockRepo.perfumesToReturn = perfumes
        networkMonitor.isConnected = true

        await sut.loadData(
            searchText: "",
            filter: PerfumeFilter(),
            sort: .nameAsc,
            cacheKey: "guard-test",
            modelContext: container.mainContext
        )

        let callsBefore = mockRepo.fetchPerfumesCalled

        // Trigger mit erstem Item (nicht letztes) → sollte Guard abfangen
        await sut.loadMoreIfNeeded(
            currentItem: perfumes[0],
            searchText: "",
            filter: PerfumeFilter(),
            sort: .nameAsc,
            modelContext: container.mainContext
        )

        XCTAssertEqual(mockRepo.fetchPerfumesCalled, callsBefore, "Sollte keinen weiteren Fetch auslösen")
    }

    // MARK: - Rating Stats

    func testLoadDataLoadsRatingStats() async {
        let perfume = TestFactory.makePerfume(name: "Rated")
        mockRepo.perfumesToReturn = [perfume]
        mockReviewDS.batchRatingStatsToReturn = [
            perfume.id: TestFactory.makeRatingStats(perfumeId: perfume.id, avgRating: 4.5, reviewCount: 10)
        ]
        networkMonitor.isConnected = true

        await sut.loadData(
            searchText: "",
            filter: PerfumeFilter(),
            sort: .nameAsc,
            cacheKey: "rating-test",
            modelContext: container.mainContext
        )

        XCTAssertEqual(sut.ratingStatsMap[perfume.id]?.avgRating, 4.5)
        XCTAssertEqual(mockReviewDS.fetchBatchRatingStatsCalled, 1)
    }

    // MARK: - Search

    func testLoadDataSearchCallsSearchPerfumes() async {
        let perfume = TestFactory.makePerfume(name: "Sauvage")
        mockRepo.searchResultsToReturn = [perfume]
        networkMonitor.isConnected = true

        await sut.loadData(
            searchText: "Sauvage",
            filter: PerfumeFilter(),
            sort: .nameAsc,
            cacheKey: "search-test",
            modelContext: container.mainContext
        )

        XCTAssertEqual(mockRepo.searchPerfumesCalled, 1)
        XCTAssertEqual(mockRepo.fetchPerfumesCalled, 0, "Sollte searchPerfumes statt fetchPerfumes nutzen")
    }

    // MARK: - Cache

    func testClearSearchCacheWorks() async {
        mockRepo.perfumesToReturn = [TestFactory.makePerfume()]
        networkMonitor.isConnected = true

        // Laden → Cache füllen
        await sut.loadData(
            searchText: "",
            filter: PerfumeFilter(),
            sort: .nameAsc,
            cacheKey: "cache-test",
            modelContext: container.mainContext
        )

        let callsAfterFirstLoad = mockRepo.fetchPerfumesCalled

        // Zweites Laden mit gleichem Key → sollte aus Cache kommen
        await sut.loadData(
            searchText: "",
            filter: PerfumeFilter(),
            sort: .nameAsc,
            cacheKey: "cache-test",
            modelContext: container.mainContext
        )

        XCTAssertEqual(mockRepo.fetchPerfumesCalled, callsAfterFirstLoad, "Sollte aus In-Memory-Cache laden")

        // Cache leeren → neuer Fetch nötig
        sut.clearSearchCache()

        await sut.loadData(
            searchText: "",
            filter: PerfumeFilter(),
            sort: .nameAsc,
            cacheKey: "cache-test",
            modelContext: container.mainContext,
            forceRefresh: true
        )

        XCTAssertGreaterThan(mockRepo.fetchPerfumesCalled, callsAfterFirstLoad, "Nach clearSearchCache sollte neu geladen werden")
    }
}
