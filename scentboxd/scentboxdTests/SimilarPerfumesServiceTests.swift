//
//  SimilarPerfumesServiceTests.swift
//  scentboxdTests
//

import XCTest
@testable import scentboxd

@MainActor
final class SimilarPerfumesServiceTests: XCTestCase {

    private var mockRepo: MockPerfumeRepository!
    private var sut: SimilarPerfumesService!
    private let perfumeId = UUID()

    override func setUp() {
        mockRepo = MockPerfumeRepository()
        sut = SimilarPerfumesService(repository: mockRepo)
    }

    override func tearDown() {
        sut = nil
        mockRepo = nil
    }

    // MARK: - Erfolgreicher Ladevorgang

    func testLoadSimilarPerfumesSuccess() async {
        // GIVEN
        mockRepo.perfumesToReturn = [
            TestFactory.makePerfume(name: "Ähnlich 1"),
            TestFactory.makePerfume(name: "Ähnlich 2"),
            TestFactory.makePerfume(name: "Ähnlich 3")
        ]

        // WHEN
        await sut.loadSimilarPerfumes(for: perfumeId)

        // THEN
        XCTAssertEqual(sut.similarPerfumes.count, 3)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }

    // MARK: - Leere Ergebnisse

    func testLoadSimilarPerfumesEmpty() async {
        // GIVEN
        mockRepo.perfumesToReturn = []

        // WHEN
        await sut.loadSimilarPerfumes(for: perfumeId)

        // THEN
        XCTAssertTrue(sut.similarPerfumes.isEmpty)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }

    // MARK: - Fehlerfall

    func testLoadSimilarPerfumesError() async {
        // GIVEN
        mockRepo.errorToThrow = NetworkError.timeout

        // WHEN
        await sut.loadSimilarPerfumes(for: perfumeId)

        // THEN
        XCTAssertTrue(sut.similarPerfumes.isEmpty)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNotNil(sut.errorMessage)
    }

    // MARK: - Nur einmal laden

    func testLoadSimilarPerfumesOnlyOnce() async {
        // GIVEN
        mockRepo.perfumesToReturn = [TestFactory.makePerfume(name: "Einmal")]

        // WHEN
        await sut.loadSimilarPerfumes(for: perfumeId)
        await sut.loadSimilarPerfumes(for: perfumeId)

        // THEN – der Guard verhindert ein zweites Laden
        XCTAssertEqual(sut.similarPerfumes.count, 1)
    }

    // MARK: - Limit

    func testLoadSimilarPerfumesRespectsLimit() async {
        // GIVEN: Mehr als 6 Parfums im Repo
        mockRepo.perfumesToReturn = (0..<10).map {
            TestFactory.makePerfume(name: "Parfum \($0)")
        }

        // WHEN
        await sut.loadSimilarPerfumes(for: perfumeId)

        // THEN – MockPerfumeRepository gibt prefix(limit) zurück
        XCTAssertEqual(sut.similarPerfumes.count, 6)
    }
}
