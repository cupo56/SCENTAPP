//
//  PerfumeFilterViewModelTests.swift
//  scentboxdTests
//

import XCTest
import Combine
@testable import scentboxd

@MainActor
final class PerfumeFilterViewModelTests: XCTestCase {

    private var mockRepo: MockPerfumeRepository!
    private var sut: PerfumeFilterViewModel!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        mockRepo = MockPerfumeRepository()
        sut = PerfumeFilterViewModel(repository: mockRepo)
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        sut = nil
        mockRepo = nil
    }

    // MARK: - Initial State

    func testInitialState() {
        XCTAssertTrue(sut.activeFilter.isEmpty)
        XCTAssertEqual(sut.sortOption, .nameAsc)
        XCTAssertTrue(sut.availableBrands.isEmpty)
        XCTAssertTrue(sut.availableConcentrations.isEmpty)
        XCTAssertFalse(sut.isFilterSheetPresented)
    }

    // MARK: - Load Filter Options

    func testLoadFilterOptionsSuccess() async {
        mockRepo.brandsToReturn = ["Dior", "Chanel", "Tom Ford"]
        mockRepo.concentrationsToReturn = ["EDP", "EDT", "Parfum"]

        await sut.loadAvailableFilterOptions()

        XCTAssertEqual(sut.availableBrands, ["Dior", "Chanel", "Tom Ford"])
        XCTAssertEqual(sut.availableConcentrations, ["EDP", "EDT", "Parfum"])
        XCTAssertEqual(mockRepo.fetchBrandsCalled, 1)
        XCTAssertEqual(mockRepo.fetchConcentrationsCalled, 1)
    }

    func testLoadFilterOptionsError() async {
        mockRepo.errorToThrow = NetworkError.timeout

        await sut.loadAvailableFilterOptions()

        // Sollte nicht crashen, Brands bleiben leer
        XCTAssertTrue(sut.availableBrands.isEmpty)
        XCTAssertTrue(sut.availableConcentrations.isEmpty)
    }

    func testLoadFilterOptionsCaching() async {
        mockRepo.brandsToReturn = ["Dior"]
        mockRepo.concentrationsToReturn = ["EDP"]

        // Erster Aufruf → Repository wird abgefragt
        await sut.loadAvailableFilterOptions()
        XCTAssertEqual(mockRepo.fetchBrandsCalled, 1)

        // Zweiter Aufruf innerhalb TTL → kein erneuter Fetch
        await sut.loadAvailableFilterOptions()
        XCTAssertEqual(mockRepo.fetchBrandsCalled, 1, "Sollte gecachte Daten verwenden")
    }

    func testLoadFilterOptionsPopulatesBrands() async {
        mockRepo.brandsToReturn = ["Creed", "Amouage"]
        mockRepo.concentrationsToReturn = ["EDP"]

        await sut.loadAvailableFilterOptions()

        XCTAssertTrue(sut.availableBrands.contains("Creed"))
        XCTAssertTrue(sut.availableBrands.contains("Amouage"))
        XCTAssertEqual(sut.availableBrands.count, 2)
    }

    // MARK: - Reset Filters

    func testResetFilters() {
        sut.activeFilter = PerfumeFilter(brandName: "Dior", concentration: "EDP")
        sut.sortOption = .ratingDesc

        sut.resetFilters()

        XCTAssertTrue(sut.activeFilter.isEmpty)
        XCTAssertEqual(sut.sortOption, .nameAsc)
    }

    func testResetFiltersResetsSort() {
        sut.sortOption = .newest
        sut.resetFilters()
        XCTAssertEqual(sut.sortOption, .nameAsc)
    }

    // MARK: - Combine Subjects

    func testActiveFilterChangeSendsSubject() {
        let expectation = XCTestExpectation(description: "filterSubject wird gefeuert")
        var receivedFilter: PerfumeFilter?

        sut.filterSubject
            .sink { filter in
                receivedFilter = filter
                expectation.fulfill()
            }
            .store(in: &cancellables)

        sut.activeFilter = PerfumeFilter(brandName: "Chanel")

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedFilter?.brandName, "Chanel")
    }

    func testSortOptionChangeSendsSubject() {
        let expectation = XCTestExpectation(description: "sortSubject wird gefeuert")
        var receivedSort: PerfumeSortOption?

        sut.sortSubject
            .sink { sort in
                receivedSort = sort
                expectation.fulfill()
            }
            .store(in: &cancellables)

        sut.sortOption = .ratingDesc

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedSort, .ratingDesc)
    }

    // MARK: - Filter Sheet

    func testFilterSheetPresentedTriggersLoad() async {
        mockRepo.brandsToReturn = ["Dior"]
        mockRepo.concentrationsToReturn = ["EDP"]

        sut.isFilterSheetPresented = true

        // Warten bis der Task im didSet ausgeführt wurde
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(mockRepo.fetchBrandsCalled, 1, "Öffnen des Sheets sollte Filter-Optionen laden")
    }
}
