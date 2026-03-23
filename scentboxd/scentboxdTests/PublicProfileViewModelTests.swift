//
//  PublicProfileViewModelTests.swift
//  scentboxdTests
//

import XCTest
@testable import scentboxd

@MainActor
final class PublicProfileViewModelTests: XCTestCase {

    private var dataSource: MockPublicProfileDataSource!
    private var viewModel: PublicProfileViewModel!

    override func setUp() {
        super.setUp()
        dataSource = MockPublicProfileDataSource()
        viewModel = PublicProfileViewModel(dataSource: dataSource)
    }

    // MARK: - loadProfile

    func testLoadProfileSuccess() async {
        let userId = UUID()
        let profile = PublicProfileDTO(
            id: userId,
            username: "testuser",
            bio: "Duftliebhaber",
            avatarUrl: nil,
            isPublic: true,
            ownedCount: 10,
            reviewCount: 5,
            favoriteCount: 3,
            memberSince: Date()
        )
        dataSource.profileToReturn = profile

        await viewModel.loadProfile(userId: userId)

        XCTAssertNotNil(viewModel.profile)
        XCTAssertEqual(viewModel.profile?.username, "testuser")
        XCTAssertEqual(viewModel.profile?.ownedCount, 10)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testLoadProfileError() async {
        dataSource.errorToThrow = NetworkError.noConnection

        await viewModel.loadProfile(userId: UUID())

        XCTAssertNil(viewModel.profile)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }

    // MARK: - loadCollection

    func testLoadCollectionPagination() async {
        let userId = UUID()
        let item = PublicCollectionItemDTO(
            id: UUID(),
            name: "Test Parfum",
            description: nil,
            imageUrl: nil,
            concentration: nil,
            longevity: nil,
            sillage: nil,
            performance: nil
        )
        dataSource.collectionToReturn = [item]

        await viewModel.loadCollection(userId: userId)

        XCTAssertEqual(viewModel.collection.count, 1)
        XCTAssertFalse(viewModel.isLoadingCollection)
    }

    func testLoadCollectionStopsWhenNoMorePages() async {
        let userId = UUID()
        dataSource.collectionToReturn = []

        await viewModel.loadCollection(userId: userId)

        XCTAssertFalse(viewModel.hasMorePages)
    }

    func testResetCollection() async {
        let userId = UUID()
        let item = PublicCollectionItemDTO(
            id: UUID(),
            name: "Test",
            description: nil,
            imageUrl: nil,
            concentration: nil,
            longevity: nil,
            sillage: nil,
            performance: nil
        )
        dataSource.collectionToReturn = [item]
        await viewModel.loadCollection(userId: userId)

        viewModel.resetCollection()

        XCTAssertTrue(viewModel.collection.isEmpty)
        XCTAssertTrue(viewModel.hasMorePages)
    }
}

// MARK: - Mock

@MainActor
final class MockPublicProfileDataSource: PublicProfileDataSource {
    var profileToReturn: PublicProfileDTO?
    var collectionToReturn: [PublicCollectionItemDTO] = []
    var searchResultsToReturn: [PublicProfileDTO] = []
    var errorToThrow: Error?

    override func fetchPublicProfile(userId: UUID) async throws -> PublicProfileDTO {
        if let error = errorToThrow { throw error }
        guard let profile = profileToReturn else {
            throw NetworkError.unknown(underlying: NSError(domain: "test", code: 0))
        }
        return profile
    }

    override func fetchPublicCollection(userId: UUID, page: Int, pageSize: Int) async throws -> [PublicCollectionItemDTO] {
        if let error = errorToThrow { throw error }
        return collectionToReturn
    }

    override func searchUsers(query: String) async throws -> [PublicProfileDTO] {
        if let error = errorToThrow { throw error }
        return searchResultsToReturn
    }
}
