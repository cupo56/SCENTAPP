//
//  PerfumeStatusServiceTests.swift
//  scentboxdTests
//

import XCTest
import SwiftData
@testable import scentboxd

@MainActor
final class PerfumeStatusServiceTests: XCTestCase {

    private var sut: PerfumeStatusService!
    private var mockDataSource: MockUserPerfumeDataSource!
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        mockDataSource = MockUserPerfumeDataSource()
        sut = PerfumeStatusService(userPerfumeDataSource: mockDataSource)
        container = try TestFactory.makeModelContainer()
        context = container.mainContext
    }

    // MARK: - Status Checks

    func testIsFavoriteReturnsFalseWithoutMetadata() {
        let perfume = TestFactory.makePerfume()
        XCTAssertFalse(sut.isFavorite(perfume))
    }

    func testIsFavoriteReturnsTrueWhenSet() {
        let perfume = TestFactory.makePerfume()
        perfume.userMetadata = UserPersonalData(isFavorite: true)
        XCTAssertTrue(sut.isFavorite(perfume))
    }

    func testIsOwnedReturnsFalseWithoutMetadata() {
        let perfume = TestFactory.makePerfume()
        XCTAssertFalse(sut.isOwned(perfume))
    }

    func testIsOwnedReturnsTrueWhenSet() {
        let perfume = TestFactory.makePerfume()
        perfume.userMetadata = UserPersonalData(isOwned: true)
        XCTAssertTrue(sut.isOwned(perfume))
    }

    // MARK: - Toggle Favorite

    func testToggleFavoriteCreatesMetadata() {
        let perfume = TestFactory.makePerfume()
        context.insert(perfume)

        sut.toggleFavorite(perfume: perfume, modelContext: context, isAuthenticated: false)

        XCTAssertTrue(perfume.userMetadata?.isFavorite ?? false)
        XCTAssertTrue(perfume.userMetadata?.hasPendingSync ?? false)
    }

    func testToggleFavoriteTogglesExisting() {
        let perfume = TestFactory.makePerfume()
        perfume.userMetadata = UserPersonalData(isFavorite: true)
        context.insert(perfume)

        sut.toggleFavorite(perfume: perfume, modelContext: context, isAuthenticated: false)

        XCTAssertFalse(perfume.userMetadata?.isFavorite ?? true)
    }

    // MARK: - Toggle Owned

    func testToggleOwnedCreatesMetadata() {
        let perfume = TestFactory.makePerfume()
        context.insert(perfume)

        sut.toggleOwned(perfume: perfume, modelContext: context, isAuthenticated: false)

        XCTAssertTrue(perfume.userMetadata?.isOwned ?? false)
    }

    func testToggleOwnedTogglesExisting() {
        let perfume = TestFactory.makePerfume()
        perfume.userMetadata = UserPersonalData(isOwned: true)
        context.insert(perfume)

        sut.toggleOwned(perfume: perfume, modelContext: context, isAuthenticated: false)

        XCTAssertFalse(perfume.userMetadata?.isOwned ?? true)
    }

    // MARK: - Throttling

    func testThrottlingBlocksRapidToggles() {
        let perfume = TestFactory.makePerfume()
        context.insert(perfume)

        sut.toggleFavorite(perfume: perfume, modelContext: context, isAuthenticated: false)
        let firstState = perfume.userMetadata?.isFavorite

        // Second toggle should be throttled (within 0.5s)
        sut.toggleFavorite(perfume: perfume, modelContext: context, isAuthenticated: false)
        XCTAssertEqual(perfume.userMetadata?.isFavorite, firstState)
    }

    // MARK: - Sync

    func testToggleDoesNotSyncWhenNotAuthenticated() async throws {
        let perfume = TestFactory.makePerfume()
        context.insert(perfume)

        sut.toggleFavorite(perfume: perfume, modelContext: context, isAuthenticated: false)

        // Give async tasks a moment
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(mockDataSource.saveCalled, 0)
        XCTAssertEqual(mockDataSource.deleteCalled, 0)
    }

    func testToggleSyncsWhenAuthenticated() async throws {
        let perfume = TestFactory.makePerfume()
        context.insert(perfume)

        sut.toggleFavorite(perfume: perfume, modelContext: context, isAuthenticated: true)

        // Give async sync task time to complete
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(mockDataSource.saveCalled, 1)
        XCTAssertTrue(mockDataSource.lastSavedIsFavorite ?? false)
    }

    func testToggleSyncErrorSetsAlertWhenAuthenticated() async throws {
        mockDataSource.errorToThrow = NetworkError.timeout
        let perfume = TestFactory.makePerfume()
        context.insert(perfume)

        sut.toggleFavorite(perfume: perfume, modelContext: context, isAuthenticated: true)

        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertNotNil(sut.syncErrorMessage)
        XCTAssertTrue(sut.showSyncErrorAlert)
    }

    // MARK: - UserPersonalData

    func testHasNoStatusWhenAllFalse() {
        let data = UserPersonalData()
        XCTAssertTrue(data.hasNoStatus)
    }

    func testHasNoStatusFalseWhenFavorite() {
        let data = UserPersonalData(isFavorite: true)
        XCTAssertFalse(data.hasNoStatus)
    }

    func testHasNoStatusFalseWhenOwned() {
        let data = UserPersonalData(isOwned: true)
        XCTAssertFalse(data.hasNoStatus)
    }
}
