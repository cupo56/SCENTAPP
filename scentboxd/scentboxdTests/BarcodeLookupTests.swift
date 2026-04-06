//
//  BarcodeLookupTests.swift
//  scentboxdTests
//

import XCTest
@testable import scentboxd

@MainActor
final class BarcodeLookupTests: XCTestCase {

    private var mockRepo: MockPerfumeRepository!
    private var mockMonitor: NetworkMonitor!
    private var sut: BarcodeScannerViewModel!

    override func setUp() {
        super.setUp()
        mockRepo = MockPerfumeRepository()
        mockMonitor = NetworkMonitor.shared
        sut = BarcodeScannerViewModel(repository: mockRepo, networkMonitor: mockMonitor)
    }

    override func tearDown() {
        sut = nil
        mockRepo = nil
        super.tearDown()
    }

    // MARK: - testValidEAN_findsPerfume

    func testValidEAN_findsPerfume() async throws {
        let perfume = TestFactory.makePerfume(name: "Bleu de Chanel")
        mockRepo.barcodeResultToReturn = perfume

        sut.handleScan("3145891073507")

        // Warten bis die async Task abgeschlossen ist
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(sut.foundPerfume?.name, "Bleu de Chanel")
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isSearching)
        XCTAssertEqual(mockRepo.lastBarcode, "3145891073507")
        XCTAssertEqual(mockRepo.fetchByBarcodeCalled, 1)
    }

    // MARK: - testInvalidEAN_returnsNil

    func testInvalidEAN_returnsNil() async throws {
        mockRepo.barcodeResultToReturn = nil

        sut.handleScan("0000000000000")

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertNil(sut.foundPerfume)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertFalse(sut.isSearching)
    }

    // MARK: - testOffline_showsError

    func testOffline_showsError() async throws {
        // Simuliere Offline-Zustand
        mockMonitor.isConnected = false

        sut.handleScan("3145891073507")

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertNil(sut.foundPerfume)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertEqual(mockRepo.fetchByBarcodeCalled, 0, "Bei Offline sollte kein API-Call erfolgen")

        // Aufräumen
        mockMonitor.isConnected = true
    }

    // MARK: - testDuplicateScan_ignoredAfterFirst

    func testDuplicateScan_ignoredAfterFirst() async throws {
        let perfume = TestFactory.makePerfume(name: "Sauvage")
        mockRepo.barcodeResultToReturn = perfume

        sut.handleScan("3348901250268")
        sut.handleScan("3348901250268") // zweiter Scan wird ignoriert

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(mockRepo.fetchByBarcodeCalled, 1, "Nur ein API-Call erwartet")
    }

    // MARK: - testReset_erlaubtNeuenScan

    func testReset_erlaubtNeuenScan() async throws {
        let perfume = TestFactory.makePerfume(name: "Aventus")
        mockRepo.barcodeResultToReturn = perfume

        sut.handleScan("5060412342009")
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(mockRepo.fetchByBarcodeCalled, 1)

        sut.reset()

        XCTAssertNil(sut.foundPerfume)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.hasScanned)

        sut.handleScan("5060412342009")
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(mockRepo.fetchByBarcodeCalled, 2, "Nach reset() sollte ein neuer Scan möglich sein")
    }
}
