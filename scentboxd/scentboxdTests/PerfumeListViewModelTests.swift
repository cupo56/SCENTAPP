//
//  PerfumeListViewModelTests.swift
//  scentboxdTests
//

import XCTest
@testable import scentboxd

@MainActor
final class PerfumeListViewModelTests: XCTestCase {

    private var mockRepo: MockPerfumeRepository!
    private var mockReviewDS: MockReviewDataSource!
    private var filterVM: PerfumeFilterViewModel!
    private var sut: PerfumeListViewModel!
    private var searchSuggestionService: SearchSuggestionService!

    override func setUp() {
        super.setUp()
        mockRepo = MockPerfumeRepository()
        mockReviewDS = MockReviewDataSource()
        filterVM = PerfumeFilterViewModel(repository: mockRepo)
        searchSuggestionService = SearchSuggestionService(repository: mockRepo)

        let dataLoader = PerfumeDataLoader(
            repository: mockRepo,
            reviewDataSource: mockReviewDS,
            cacheService: PerfumeCacheService(),
            networkMonitor: NetworkMonitor.shared
        )

        sut = PerfumeListViewModel(
            dataLoader: dataLoader,
            networkMonitor: NetworkMonitor.shared,
            filterVM: filterVM,
            searchSuggestionService: searchSuggestionService
        )
    }

    override func tearDown() {
        sut = nil
        filterVM = nil
        searchSuggestionService = nil
        mockRepo = nil
        mockReviewDS = nil
        super.tearDown()
    }

    // MARK: - loadData

    func testLoadDataSuccess() async {
        // GIVEN
        let perfumes = [
            TestFactory.makePerfume(name: "Bleu de Chanel"),
            TestFactory.makePerfume(name: "Sauvage")
        ]
        mockRepo.perfumesToReturn = perfumes

        // WHEN
        await sut.loadData()

        // THEN
        XCTAssertEqual(sut.dataLoader.perfumes.count, 2, "Sollte 2 Parfums geladen haben.")
        XCTAssertNil(sut.dataLoader.errorMessage, "Kein Fehler erwartet.")
        XCTAssertFalse(sut.dataLoader.isLoading, "Ladevorgang sollte beendet sein.")
        XCTAssertEqual(mockRepo.fetchPerfumesCalled, 1, "fetchPerfumes sollte genau einmal aufgerufen werden.")
    }

    func testLoadDataEmpty() async {
        // GIVEN
        mockRepo.perfumesToReturn = []

        // WHEN
        await sut.loadData()

        // THEN
        XCTAssertTrue(sut.dataLoader.perfumes.isEmpty, "Keine Parfums erwartet.")
        XCTAssertNil(sut.dataLoader.errorMessage, "Leere Liste ist kein Fehler.")
    }

    func testLoadDataNetworkError() async {
        // GIVEN
        mockRepo.errorToThrow = NetworkError.noConnection

        // WHEN
        await sut.loadData()

        // THEN
        XCTAssertNotNil(sut.dataLoader.errorMessage, "Fehlermeldung sollte gesetzt sein.")
        XCTAssertTrue(sut.dataLoader.perfumes.isEmpty, "Bei Fehler keine Parfums erwartet.")
    }

    // MARK: - Pagination

    func testLoadMorePagination() async {
        // GIVEN: Erste Seite mit genau pageSize Ergebnissen (→ hasMorePages = true)
        let firstPage = (0..<20).map { TestFactory.makePerfume(name: "Parfum \($0)") }
        mockRepo.perfumesToReturn = firstPage
        await sut.loadData()

        let secondPage = [TestFactory.makePerfume(name: "Parfum 20")]
        mockRepo.perfumesToReturn = secondPage

        // WHEN: loadMoreIfNeeded mit dem letzten Element
        if let lastItem = sut.dataLoader.perfumes.last {
            await sut.loadMoreIfNeeded(currentItem: lastItem)
        }

        // THEN
        XCTAssertEqual(sut.dataLoader.perfumes.count, 21, "Erste + zweite Seite = 21 Parfums.")
        XCTAssertEqual(mockRepo.fetchPerfumesCalled, 2, "Sollte zweimal aufgerufen worden sein.")
    }

    func testLoadMoreNotTriggeredForNonLastItem() async {
        // GIVEN
        let perfumes = (0..<20).map { TestFactory.makePerfume(name: "Parfum \($0)") }
        mockRepo.perfumesToReturn = perfumes
        await sut.loadData()

        // WHEN: loadMoreIfNeeded mit einem nicht-letzten Element
        let firstItem = sut.dataLoader.perfumes[0]
        await sut.loadMoreIfNeeded(currentItem: firstItem)

        // THEN
        XCTAssertEqual(mockRepo.fetchPerfumesCalled, 1, "Kein zusätzlicher Fetch erwartet.")
    }

    // MARK: - Refresh

    func testRefreshReloadsData() async {
        // GIVEN: Initial load
        mockRepo.perfumesToReturn = [TestFactory.makePerfume(name: "Alt")]
        await sut.loadData()

        // WHEN: Refresh mit neuen Daten
        mockRepo.perfumesToReturn = [TestFactory.makePerfume(name: "Neu")]
        await sut.refresh()

        // THEN
        XCTAssertEqual(sut.dataLoader.perfumes.first?.name, "Neu", "Nach Refresh sollten neue Daten geladen sein.")
        XCTAssertEqual(mockRepo.fetchPerfumesCalled, 2, "Sollte zweimal aufgerufen worden sein.")
    }

    // MARK: - Filter

    func testResetFilters() {
        // GIVEN
        filterVM.activeFilter = PerfumeFilter(brandName: "Chanel", concentration: "EDP")
        filterVM.sortOption = .ratingDesc

        // WHEN
        filterVM.resetFilters()

        // THEN
        XCTAssertTrue(filterVM.activeFilter.isEmpty, "Filter sollte zurückgesetzt sein.")
        XCTAssertEqual(filterVM.sortOption, .nameAsc, "Sortierung sollte Standard sein.")
    }

    // MARK: - Filter Options

    func testLoadAvailableFilterOptions() async {
        // GIVEN
        mockRepo.brandsToReturn = ["Chanel", "Dior"]
        mockRepo.concentrationsToReturn = ["EDP", "EDT"]

        // WHEN
        await filterVM.loadAvailableFilterOptions()

        // THEN
        XCTAssertEqual(filterVM.availableBrands, ["Chanel", "Dior"])
        XCTAssertEqual(filterVM.availableConcentrations, ["EDP", "EDT"])
    }
}
