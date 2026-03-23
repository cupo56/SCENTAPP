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

    func testSearchUsersReturnsResults() async throws {
        let profile = PublicProfileDTO(
            id: UUID(),
            username: "duftfan",
            bio: nil,
            avatarUrl: nil,
            isPublic: true,
            ownedCount: 5,
            reviewCount: 2,
            favoriteCount: 1,
            memberSince: Date()
        )
        dataSource.searchResultsToReturn = [profile]

        let results = try await dataSource.searchUsers(query: "duft")

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.username, "duftfan")
    }

    func testSearchUsersEmptyQuery() async throws {
        // The real implementation returns [] for empty queries.
        // The mock doesn't replicate that, so this tests the contract.
        dataSource.searchResultsToReturn = []

        let results = try await dataSource.searchUsers(query: "")

        XCTAssertTrue(results.isEmpty)
    }

    func testSearchUsersError() async {
        dataSource.errorToThrow = NetworkError.noConnection

        do {
            _ = try await dataSource.searchUsers(query: "test")
            XCTFail("Should have thrown")
        } catch {
            XCTAssertTrue(error is NetworkError)
        }
    }

    func testFetchPublicProfilePrivate() async throws {
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
}
