//
//  UserSearchTests.swift
//  scentboxdTests
//

import XCTest
@testable import scentboxd

@MainActor
final class UserSearchTests: XCTestCase {

    private var dataSource: MockPublicProfileDataSource!

    override func setUp() {
        super.setUp()
        dataSource = MockPublicProfileDataSource()
    }

    // MARK: - searchUsers: Basic

    func testSearchReturnsMatchingResults() async throws {
        let profile = makeSearchProfile(username: "duftfan")
        dataSource.searchResultsToReturn = [profile]

        let results = try await dataSource.searchUsers(query: "duft")

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.username, "duftfan")
        XCTAssertEqual(dataSource.lastSearchQuery, "duft")
    }

    func testSearchReturnsMultipleResults() async throws {
        let profiles = [
            makeSearchProfile(username: "alice"),
            makeSearchProfile(username: "alina"),
            makeSearchProfile(username: "alexander")
        ]
        dataSource.searchResultsToReturn = profiles

        let results = try await dataSource.searchUsers(query: "al")

        XCTAssertEqual(results.count, 3)
    }

    func testSearchNoResults_returnsEmptyArray() async throws {
        dataSource.searchResultsToReturn = []

        let results = try await dataSource.searchUsers(query: "zzzznonexistent")

        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - searchUsers: Edge Cases

    func testSearchEmptyQuery_returnsEmpty() async throws {
        dataSource.searchResultsToReturn = []

        let results = try await dataSource.searchUsers(query: "")

        XCTAssertTrue(results.isEmpty)
    }

    func testSearchCallTrackingIncremented() async throws {
        dataSource.searchResultsToReturn = []
        _ = try await dataSource.searchUsers(query: "test1")
        _ = try await dataSource.searchUsers(query: "test2")

        XCTAssertEqual(dataSource.searchCallCount, 2)
    }

    // MARK: - searchUsers: Error Handling

    func testSearchNetworkError_throwsError() async {
        dataSource.errorToThrow = NetworkError.noConnection

        do {
            _ = try await dataSource.searchUsers(query: "test")
            XCTFail("Should have thrown NetworkError.noConnection")
        } catch {
            XCTAssertTrue(error is NetworkError)
        }
    }

    func testSearchTimeoutError_throwsError() async {
        dataSource.errorToThrow = NetworkError.timeout

        do {
            _ = try await dataSource.searchUsers(query: "test")
            XCTFail("Should have thrown")
        } catch let error as NetworkError {
            if case .timeout = error {
                // Expected
            } else {
                XCTFail("Expected timeout, got \(error)")
            }
        } catch {
            XCTFail("Expected NetworkError, got \(error)")
        }
    }

    // MARK: - fetchPublicProfile: Private vs Public (RLS Contract)

    func testFetchPrivateProfile_returnsIsPublicFalse() async throws {
        let profile = PublicProfileDTO(
            id: UUID(),
            username: "privatuser",
            bio: nil,
            avatarUrl: nil,
            isPublic: false,
            ownedCount: 0,
            reviewCount: 0,
            favoriteCount: 0,
            memberSince: Date()
        )
        dataSource.profileToReturn = profile

        let result = try await dataSource.fetchPublicProfile(userId: profile.id)

        XCTAssertFalse(result.isPublic)
        XCTAssertEqual(result.username, "privatuser")
    }

    func testFetchPublicProfile_returnsIsPublicTrue() async throws {
        let profile = PublicProfileDTO(
            id: UUID(),
            username: "oeffentlich",
            bio: "Sichtbar",
            avatarUrl: nil,
            isPublic: true,
            ownedCount: 10,
            reviewCount: 3,
            favoriteCount: 2,
            memberSince: Date()
        )
        dataSource.profileToReturn = profile

        let result = try await dataSource.fetchPublicProfile(userId: profile.id)

        XCTAssertTrue(result.isPublic)
        XCTAssertEqual(result.ownedCount, 10)
    }

    func testFetchProfile_noProfileConfigured_throwsError() async {
        dataSource.profileToReturn = nil

        do {
            _ = try await dataSource.fetchPublicProfile(userId: UUID())
            XCTFail("Should have thrown when no profile configured")
        } catch {
            // Expected: mock throws when profileToReturn is nil
        }
    }

    // MARK: - fetchPublicCollection

    func testFetchPublicCollection_returnsItems() async throws {
        let item = PublicCollectionItemDTO(
            id: UUID(),
            name: "Bleu de Chanel",
            description: "Frisch und holzig",
            imageUrl: "https://example.com/img.jpg",
            concentration: "EDP",
            longevity: "Lang",
            sillage: "Mittel",
            performance: 4.5
        )
        dataSource.collectionToReturn = [item]

        let results = try await dataSource.fetchPublicCollection(userId: UUID(), page: 0, pageSize: 20)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "Bleu de Chanel")
        XCTAssertEqual(results.first?.concentration, "EDP")
    }

    func testFetchPublicCollection_emptyCollection() async throws {
        dataSource.collectionToReturn = []

        let results = try await dataSource.fetchPublicCollection(userId: UUID(), page: 0, pageSize: 20)

        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - updateProfileVisibility

    func testUpdateProfileVisibility_callsDataSource() async throws {
        try await dataSource.updateProfileVisibility(userId: UUID(), isPublic: false)

        XCTAssertEqual(dataSource.updateVisibilityCallCount, 1)
    }

    func testUpdateProfileVisibility_error_throws() async {
        dataSource.errorToThrow = NetworkError.clientError(statusCode: 403)

        do {
            try await dataSource.updateProfileVisibility(userId: UUID(), isPublic: true)
            XCTFail("Should have thrown")
        } catch let error as NetworkError {
            if case .clientError(let code) = error {
                XCTAssertEqual(code, 403)
            } else {
                XCTFail("Expected clientError, got \(error)")
            }
        } catch {
            XCTFail("Expected NetworkError")
        }
    }

    // MARK: - updateBio

    func testUpdateBio_callsDataSource() async throws {
        try await dataSource.updateBio(userId: UUID(), bio: "Neue Bio")

        XCTAssertEqual(dataSource.updateBioCallCount, 1)
    }

    // MARK: - Helpers

    private func makeSearchProfile(username: String) -> PublicProfileDTO {
        PublicProfileDTO(
            id: UUID(),
            username: username,
            bio: nil,
            avatarUrl: nil,
            isPublic: true,
            ownedCount: 0,
            reviewCount: 0,
            favoriteCount: 0,
            memberSince: Date()
        )
    }
}
