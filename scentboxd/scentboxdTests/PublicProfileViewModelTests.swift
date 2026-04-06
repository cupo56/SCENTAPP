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

    // MARK: - loadProfile: Success Cases

    func testLoadProfileSuccess_setsProfileAndClearsError() async {
        let userId = UUID()
        dataSource.profileToReturn = makeProfile(id: userId, username: "testuser", ownedCount: 10)

        await viewModel.loadProfile(userId: userId)

        XCTAssertNotNil(viewModel.profile)
        XCTAssertEqual(viewModel.profile?.username, "testuser")
        XCTAssertEqual(viewModel.profile?.ownedCount, 10)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testLoadProfileSuccess_allFieldsMapped() async {
        let userId = UUID()
        let memberDate = Date(timeIntervalSince1970: 1_700_000_000)
        dataSource.profileToReturn = PublicProfileDTO(
            id: userId,
            username: "duftfan",
            bio: "Ich liebe Düfte",
            avatarUrl: "https://example.com/avatar.jpg",
            isPublic: true,
            ownedCount: 42,
            reviewCount: 15,
            favoriteCount: 8,
            memberSince: memberDate
        )

        await viewModel.loadProfile(userId: userId)

        let p = viewModel.profile
        XCTAssertEqual(p?.id, userId)
        XCTAssertEqual(p?.bio, "Ich liebe Düfte")
        XCTAssertEqual(p?.avatarUrl, "https://example.com/avatar.jpg")
        XCTAssertTrue(p?.isPublic ?? false)
        XCTAssertEqual(p?.reviewCount, 15)
        XCTAssertEqual(p?.favoriteCount, 8)
        XCTAssertEqual(p?.memberSince, memberDate)
    }

    func testLoadProfilePublic_isPublicTrue() async {
        dataSource.profileToReturn = makeProfile(isPublic: true)
        await viewModel.loadProfile(userId: UUID())
        XCTAssertTrue(viewModel.profile?.isPublic ?? false)
    }

    // MARK: - loadProfile: Private Profile (RLS)

    func testLoadProfilePrivate_isPublicFalse() async {
        dataSource.profileToReturn = makeProfile(username: "privatuser", isPublic: false)

        await viewModel.loadProfile(userId: UUID())

        XCTAssertNotNil(viewModel.profile)
        XCTAssertFalse(viewModel.profile?.isPublic ?? true)
        XCTAssertEqual(viewModel.profile?.username, "privatuser")
    }

    func testPrivateProfileStatsAreZero() async {
        dataSource.profileToReturn = makeProfile(
            isPublic: false,
            ownedCount: 0,
            reviewCount: 0,
            favoriteCount: 0
        )

        await viewModel.loadProfile(userId: UUID())

        XCTAssertEqual(viewModel.profile?.ownedCount, 0)
        XCTAssertEqual(viewModel.profile?.reviewCount, 0)
        XCTAssertEqual(viewModel.profile?.favoriteCount, 0)
    }

    // MARK: - loadProfile: Error Cases

    func testLoadProfileNetworkError_setsErrorMessage() async {
        dataSource.errorToThrow = NetworkError.noConnection

        await viewModel.loadProfile(userId: UUID())

        XCTAssertNil(viewModel.profile)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testLoadProfileServerError_setsErrorMessage() async {
        dataSource.errorToThrow = NetworkError.serverError(statusCode: 500)

        await viewModel.loadProfile(userId: UUID())

        XCTAssertNil(viewModel.profile)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testLoadProfileClearsOldError_onRetry() async {
        dataSource.errorToThrow = NetworkError.noConnection
        await viewModel.loadProfile(userId: UUID())
        XCTAssertNotNil(viewModel.errorMessage)

        dataSource.errorToThrow = nil
        dataSource.profileToReturn = makeProfile(username: "recovered")
        await viewModel.loadProfile(userId: UUID())

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.profile?.username, "recovered")
    }

    // MARK: - loadProfile: Loading State

    func testLoadProfile_isLoadingFalseAfterCompletion() async {
        dataSource.profileToReturn = makeProfile()
        await viewModel.loadProfile(userId: UUID())
        XCTAssertFalse(viewModel.isLoading)
    }

    func testLoadProfile_isLoadingFalseAfterError() async {
        dataSource.errorToThrow = NetworkError.timeout
        await viewModel.loadProfile(userId: UUID())
        XCTAssertFalse(viewModel.isLoading)
    }

    // MARK: - loadCollection: Pagination

    func testLoadCollectionFirstPage() async {
        let userId = UUID()
        dataSource.collectionToReturn = [makeCollectionItem(name: "Parfum A")]

        await viewModel.loadCollection(userId: userId)

        XCTAssertEqual(viewModel.collection.count, 1)
        XCTAssertEqual(viewModel.collection.first?.name, "Parfum A")
        XCTAssertFalse(viewModel.isLoadingCollection)
    }

    func testLoadCollectionMultiplePages_appendsItems() async {
        let userId = UUID()
        let fullPage = (0..<AppConfig.Pagination.perfumePageSize).map { makeCollectionItem(name: "P\($0)") }
        dataSource.collectionToReturn = fullPage

        await viewModel.loadCollection(userId: userId)
        XCTAssertEqual(viewModel.collection.count, fullPage.count)
        XCTAssertTrue(viewModel.hasMorePages)

        let secondPage = [makeCollectionItem(name: "Extra")]
        dataSource.collectionToReturn = secondPage
        await viewModel.loadCollection(userId: userId)

        XCTAssertEqual(viewModel.collection.count, fullPage.count + 1)
    }

    func testLoadCollectionEmptyPage_stopsLoading() async {
        dataSource.collectionToReturn = []

        await viewModel.loadCollection(userId: UUID())

        XCTAssertTrue(viewModel.collection.isEmpty)
        XCTAssertFalse(viewModel.hasMorePages)
    }

    func testLoadCollectionDoesNotDoubleLoad() async {
        dataSource.collectionToReturn = []
        await viewModel.loadCollection(userId: UUID())

        XCTAssertFalse(viewModel.hasMorePages)

        dataSource.fetchCollectionCallCount = 0
        await viewModel.loadCollection(userId: UUID())
        XCTAssertEqual(dataSource.fetchCollectionCallCount, 0, "Should not fetch when no more pages")
    }

    func testLoadCollectionError_doesNotCrash() async {
        dataSource.errorToThrow = NetworkError.noConnection

        await viewModel.loadCollection(userId: UUID())

        XCTAssertTrue(viewModel.collection.isEmpty)
        XCTAssertFalse(viewModel.isLoadingCollection)
    }

    // MARK: - resetCollection

    func testResetCollection_clearsState() async {
        let userId = UUID()
        dataSource.collectionToReturn = [makeCollectionItem()]
        await viewModel.loadCollection(userId: userId)
        XCTAssertFalse(viewModel.collection.isEmpty)

        viewModel.resetCollection()

        XCTAssertTrue(viewModel.collection.isEmpty)
        XCTAssertTrue(viewModel.hasMorePages)
    }

    func testResetCollection_allowsReloading() async {
        let userId = UUID()
        dataSource.collectionToReturn = []
        await viewModel.loadCollection(userId: userId)
        XCTAssertFalse(viewModel.hasMorePages)

        viewModel.resetCollection()
        XCTAssertTrue(viewModel.hasMorePages)

        dataSource.collectionToReturn = [makeCollectionItem(name: "After Reset")]
        await viewModel.loadCollection(userId: userId)
        XCTAssertEqual(viewModel.collection.first?.name, "After Reset")
    }

    // MARK: - Helpers

    private func makeProfile(
        id: UUID = UUID(),
        username: String = "testuser",
        isPublic: Bool = true,
        ownedCount: Int = 5,
        reviewCount: Int = 2,
        favoriteCount: Int = 1
    ) -> PublicProfileDTO {
        PublicProfileDTO(
            id: id,
            username: username,
            bio: nil,
            avatarUrl: nil,
            isPublic: isPublic,
            ownedCount: ownedCount,
            reviewCount: reviewCount,
            favoriteCount: favoriteCount,
            memberSince: Date()
        )
    }

    private func makeCollectionItem(
        name: String = "Test Parfum"
    ) -> PublicCollectionItemDTO {
        PublicCollectionItemDTO(
            id: UUID(),
            name: name,
            description: nil,
            imageUrl: nil,
            concentration: nil,
            longevity: nil,
            sillage: nil,
            performance: nil
        )
    }
}

// MARK: - Mock

@MainActor
final class MockPublicProfileDataSource: PublicProfileDataSourceProtocol {
    var profileToReturn: PublicProfileDTO?
    var collectionToReturn: [PublicCollectionItemDTO] = []
    var searchResultsToReturn: [PublicProfileDTO] = []
    var errorToThrow: Error?

    private(set) var fetchProfileCallCount = 0
    var fetchCollectionCallCount = 0
    private(set) var searchCallCount = 0
    private(set) var lastSearchQuery: String?
    private(set) var updateVisibilityCallCount = 0
    private(set) var updateBioCallCount = 0

    func fetchPublicProfile(userId: UUID) async throws -> PublicProfileDTO {
        fetchProfileCallCount += 1
        if let error = errorToThrow { throw error }
        guard let profile = profileToReturn else {
            throw NetworkError.unknown(underlying: NSError(domain: "test", code: 0))
        }
        return profile
    }

    func fetchPublicCollection(userId: UUID, page: Int, pageSize: Int) async throws -> [PublicCollectionItemDTO] {
        fetchCollectionCallCount += 1
        if let error = errorToThrow { throw error }
        return collectionToReturn
    }

    func searchUsers(query: String) async throws -> [PublicProfileDTO] {
        searchCallCount += 1
        lastSearchQuery = query
        if let error = errorToThrow { throw error }
        return searchResultsToReturn
    }

    func updateProfileVisibility(userId: UUID, isPublic: Bool) async throws {
        updateVisibilityCallCount += 1
        if let error = errorToThrow { throw error }
    }

    func updateBio(userId: UUID, bio: String) async throws {
        updateBioCallCount += 1
        if let error = errorToThrow { throw error }
    }
}
