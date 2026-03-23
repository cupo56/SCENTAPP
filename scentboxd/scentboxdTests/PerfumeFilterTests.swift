//
//  PerfumeFilterTests.swift
//  scentboxdTests
//

import XCTest
@testable import scentboxd

final class PerfumeFilterTests: XCTestCase {

    // MARK: - isEmpty

    func testEmptyFilterIsEmpty() {
        let filter = PerfumeFilter()
        XCTAssertTrue(filter.isEmpty)
    }

    func testFilterWithBrandIsNotEmpty() {
        var filter = PerfumeFilter()
        filter.brandName = "Dior"
        XCTAssertFalse(filter.isEmpty)
    }

    func testFilterWithConcentrationIsNotEmpty() {
        var filter = PerfumeFilter()
        filter.concentration = "EDP"
        XCTAssertFalse(filter.isEmpty)
    }

    func testFilterWithLongevityIsNotEmpty() {
        var filter = PerfumeFilter()
        filter.longevity = "Lang"
        XCTAssertFalse(filter.isEmpty)
    }

    func testFilterWithSillageIsNotEmpty() {
        var filter = PerfumeFilter()
        filter.sillage = "Stark"
        XCTAssertFalse(filter.isEmpty)
    }

    func testFilterWithNotesIsNotEmpty() {
        var filter = PerfumeFilter()
        filter.noteNames = ["Vanille"]
        XCTAssertFalse(filter.isEmpty)
    }

    func testFilterWithOccasionsIsNotEmpty() {
        var filter = PerfumeFilter()
        filter.occasions = ["Abend"]
        XCTAssertFalse(filter.isEmpty)
    }

    func testFilterWithMinRatingIsNotEmpty() {
        var filter = PerfumeFilter()
        filter.minRating = 3.0
        XCTAssertFalse(filter.isEmpty)
    }

    func testFilterWithMaxRatingIsNotEmpty() {
        var filter = PerfumeFilter()
        filter.maxRating = 5.0
        XCTAssertFalse(filter.isEmpty)
    }

    // MARK: - activeFilterCount

    func testActiveFilterCountZeroForEmpty() {
        let filter = PerfumeFilter()
        XCTAssertEqual(filter.activeFilterCount, 0)
    }

    func testActiveFilterCountSingleCategory() {
        var filter = PerfumeFilter()
        filter.brandName = "Chanel"
        XCTAssertEqual(filter.activeFilterCount, 1)
    }

    func testActiveFilterCountMultipleCategories() {
        var filter = PerfumeFilter()
        filter.brandName = "Chanel"
        filter.concentration = "EDT"
        filter.noteNames = ["Rose", "Jasmin"]
        filter.minRating = 3.0
        XCTAssertEqual(filter.activeFilterCount, 4)
    }

    func testActiveFilterCountRatingCountsAsOne() {
        var filter = PerfumeFilter()
        filter.minRating = 2.0
        filter.maxRating = 4.5
        XCTAssertEqual(filter.activeFilterCount, 1)
    }

    func testActiveFilterCountAllCategories() {
        var filter = PerfumeFilter()
        filter.brandName = "Dior"
        filter.concentration = "EDP"
        filter.longevity = "Lang"
        filter.sillage = "Stark"
        filter.noteNames = ["Vanille"]
        filter.occasions = ["Abend"]
        filter.minRating = 3.0
        XCTAssertEqual(filter.activeFilterCount, 7)
    }

    // MARK: - cacheKeyComponent

    func testCacheKeyComponentEmptyFilter() {
        let filter = PerfumeFilter()
        XCTAssertEqual(filter.cacheKeyComponent, "|||||||")
    }

    func testCacheKeyComponentWithValues() {
        var filter = PerfumeFilter()
        filter.brandName = "Dior"
        filter.concentration = "EDP"
        let key = filter.cacheKeyComponent
        XCTAssertTrue(key.hasPrefix("Dior|EDP|"))
    }

    func testCacheKeyComponentNotesSorted() {
        var filter = PerfumeFilter()
        filter.noteNames = ["Zeder", "Amber", "Moschus"]
        let key = filter.cacheKeyComponent
        XCTAssertTrue(key.contains("Amber,Moschus,Zeder"))
    }

    func testCacheKeyComponentOccasionsSorted() {
        var filter = PerfumeFilter()
        filter.occasions = ["Nacht", "Abend", "Tag"]
        let key = filter.cacheKeyComponent
        XCTAssertTrue(key.contains("Abend,Nacht,Tag"))
    }

    // MARK: - PerfumeSortOption

    func testSortOptionIdMatchesRawValue() {
        for option in PerfumeSortOption.allCases {
            XCTAssertEqual(option.id, option.rawValue)
        }
    }

    func testSortOptionAllCasesCount() {
        XCTAssertEqual(PerfumeSortOption.allCases.count, 6)
    }

    func testSortOptionSystemImageNotEmpty() {
        for option in PerfumeSortOption.allCases {
            XCTAssertFalse(option.systemImage.isEmpty)
        }
    }
}
