//
//  CompareSelectionManagerTests.swift
//  scentboxdTests
//

import XCTest
@testable import scentboxd

@MainActor
final class CompareSelectionManagerTests: XCTestCase {

    private var sut: CompareSelectionManager!

    override func setUp() {
        sut = CompareSelectionManager()
    }

    override func tearDown() {
        sut = nil
    }

    // MARK: - Toggle

    func testToggleAddsPerfume() {
        let perfume = TestFactory.makePerfume(name: "Sauvage")

        sut.toggle(perfume)

        XCTAssertEqual(sut.selectedPerfumes.count, 1)
        XCTAssertTrue(sut.isSelected(perfume))
    }

    func testToggleRemovesPerfume() {
        let perfume = TestFactory.makePerfume(name: "Sauvage")

        sut.toggle(perfume)
        sut.toggle(perfume)

        XCTAssertTrue(sut.selectedPerfumes.isEmpty)
        XCTAssertFalse(sut.isSelected(perfume))
    }

    // MARK: - Max 3 Limit

    func testCannotAddMoreThanThree() {
        let p1 = TestFactory.makePerfume(name: "Eins")
        let p2 = TestFactory.makePerfume(name: "Zwei")
        let p3 = TestFactory.makePerfume(name: "Drei")
        let p4 = TestFactory.makePerfume(name: "Vier")

        sut.toggle(p1)
        sut.toggle(p2)
        sut.toggle(p3)
        sut.toggle(p4)

        XCTAssertEqual(sut.selectedPerfumes.count, 3)
        XCTAssertFalse(sut.isSelected(p4))
    }

    func testCanAddIsFalseAtMax() {
        sut.toggle(TestFactory.makePerfume(name: "1"))
        sut.toggle(TestFactory.makePerfume(name: "2"))
        sut.toggle(TestFactory.makePerfume(name: "3"))

        XCTAssertFalse(sut.canAdd)
    }

    func testCanAddIsTrueWhenBelowMax() {
        sut.toggle(TestFactory.makePerfume(name: "1"))

        XCTAssertTrue(sut.canAdd)
    }

    // MARK: - canCompare

    func testCanCompareNeedsTwoPerfumes() {
        XCTAssertFalse(sut.canCompare)

        sut.toggle(TestFactory.makePerfume(name: "A"))
        XCTAssertFalse(sut.canCompare)

        sut.toggle(TestFactory.makePerfume(name: "B"))
        XCTAssertTrue(sut.canCompare)
    }

    func testCanCompareWithThreePerfumes() {
        sut.toggle(TestFactory.makePerfume(name: "A"))
        sut.toggle(TestFactory.makePerfume(name: "B"))
        sut.toggle(TestFactory.makePerfume(name: "C"))

        XCTAssertTrue(sut.canCompare)
    }

    // MARK: - Clear

    func testClearRemovesAll() {
        sut.toggle(TestFactory.makePerfume(name: "A"))
        sut.toggle(TestFactory.makePerfume(name: "B"))

        sut.clear()

        XCTAssertTrue(sut.selectedPerfumes.isEmpty)
        XCTAssertTrue(sut.canAdd)
        XCTAssertFalse(sut.canCompare)
    }

    // MARK: - isSelected

    func testIsSelectedReturnsFalseForUnselected() {
        let perfume = TestFactory.makePerfume(name: "Nicht ausgewählt")

        XCTAssertFalse(sut.isSelected(perfume))
    }

    // MARK: - Initialzustand

    func testInitialState() {
        XCTAssertTrue(sut.selectedPerfumes.isEmpty)
        XCTAssertTrue(sut.canAdd)
        XCTAssertFalse(sut.canCompare)
    }
}
