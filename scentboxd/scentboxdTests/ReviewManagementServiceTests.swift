//
//  ReviewManagementServiceTests.swift
//  scentboxdTests
//

import XCTest
import SwiftData
@testable import scentboxd

@MainActor
final class ReviewManagementServiceTests: XCTestCase {

    private var mockDS: MockReviewDataSource!
    private var container: ModelContainer!
    private var perfume: Perfume!
    private var sut: ReviewManagementService!

    override func setUpWithError() throws {
        mockDS = MockReviewDataSource()
        container = try TestFactory.makeModelContainer()
        perfume = TestFactory.makePerfume(name: "Test Parfum")
        container.mainContext.insert(perfume)

        sut = ReviewManagementService(
            perfumeId: perfume.id,
            reviewDataSource: mockDS
        )
    }

    override func tearDown() {
        sut = nil
        perfume = nil
        container = nil
        mockDS = nil
    }

    // MARK: - Load Reviews

    func testLoadReviewsSuccess() async {
        mockDS.reviewsToReturn = [
            TestFactory.makeReview(title: "Gut"),
            TestFactory.makeReview(title: "Super")
        ]
        mockDS.ratingStatsToReturn = TestFactory.makeRatingStats(
            perfumeId: perfume.id, avgRating: 4.0, reviewCount: 2
        )

        await sut.loadReviews()

        XCTAssertEqual(sut.reviews.count, 2)
        XCTAssertFalse(sut.isLoadingReviews)
        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(mockDS.fetchReviewsCalled, 1)
    }

    func testLoadReviewsEmpty() async {
        mockDS.reviewsToReturn = []

        await sut.loadReviews()

        XCTAssertTrue(sut.reviews.isEmpty)
        XCTAssertFalse(sut.isLoadingReviews)
    }

    func testLoadReviewsError() async {
        mockDS.errorToThrow = NetworkError.timeout

        await sut.loadReviews()

        XCTAssertTrue(sut.reviews.isEmpty)
        XCTAssertTrue(sut.showErrorAlert)
        XCTAssertNotNil(sut.errorMessage)
    }

    // MARK: - Load More

    func testLoadMoreIfNeededFetchesWhenNearEnd() async {
        let pageSize = AppConfig.Pagination.reviewPageSize
        let firstPage = (0..<pageSize).map { _ in TestFactory.makeReview() }
        mockDS.reviewsToReturn = firstPage
        mockDS.ratingStatsToReturn = TestFactory.makeRatingStats(
            perfumeId: perfume.id, avgRating: 4.0, reviewCount: pageSize
        )
        await sut.loadReviews()

        let moreReviews = [TestFactory.makeReview(title: "Extra")]
        mockDS.reviewsToReturn = moreReviews

        let thresholdIndex = max(sut.reviews.count - 3, 0)
        let nearEndReview = sut.reviews[thresholdIndex]
        await sut.loadMoreIfNeeded(currentReview: nearEndReview)

        XCTAssertGreaterThanOrEqual(mockDS.fetchReviewsCalled, 2)
        XCTAssertTrue(sut.reviews.contains { $0.title == "Extra" })
    }

    func testLoadMoreIfNeededDoesNotFetchWhenNotNearEnd() async {
        mockDS.reviewsToReturn = (0..<5).map { _ in TestFactory.makeReview() }
        mockDS.ratingStatsToReturn = TestFactory.makeRatingStats(
            perfumeId: perfume.id, avgRating: 4.0, reviewCount: 5
        )
        await sut.loadReviews()

        await sut.loadMoreIfNeeded(currentReview: sut.reviews[0])

        XCTAssertEqual(mockDS.fetchReviewsCalled, 1, "Sollte keinen weiteren Fetch auslösen (Review nicht in den letzten 3)")
    }

    // MARK: - Rating Stats

    func testLoadRatingStatsUpdatesAverage() async {
        mockDS.reviewsToReturn = [TestFactory.makeReview()]
        mockDS.ratingStatsToReturn = TestFactory.makeRatingStats(
            perfumeId: perfume.id, avgRating: 4.5, reviewCount: 10
        )

        await sut.loadReviews()

        XCTAssertEqual(sut.averageRating, 4.5)
        XCTAssertEqual(sut.serverReviewCount, 10)
    }

    func testLoadRatingStatsZeroReviewsNilAverage() async {
        mockDS.reviewsToReturn = []
        mockDS.ratingStatsToReturn = TestFactory.makeRatingStats(
            perfumeId: perfume.id, avgRating: 0, reviewCount: 0
        )

        await sut.loadReviews()

        XCTAssertNil(sut.averageRating)
    }

    // MARK: - Save Review

    func testSaveReviewSuccess() async {
        let review = TestFactory.makeReview(title: "Neuer Review")

        await sut.saveReview(review, perfume: perfume, modelContext: container.mainContext)

        XCTAssertEqual(mockDS.saveReviewCalled, 1)
        XCTAssertEqual(mockDS.lastSavedReview?.title, "Neuer Review")
        XCTAssertFalse(sut.isSavingReview)
        XCTAssertTrue(sut.reviews.contains(where: { $0.id == review.id }))
    }

    func testSaveReviewOfflineFallback() async {
        mockDS.errorToThrow = NetworkError.timeout
        let review = TestFactory.makeReview(title: "Offline Review")

        await sut.saveReview(review, perfume: perfume, modelContext: container.mainContext)

        XCTAssertTrue(review.hasPendingSync)
        XCTAssertEqual(review.pendingSyncAction, .save)
        XCTAssertTrue(sut.reviews.contains(where: { $0.id == review.id }))
    }

    // MARK: - Update Review

    func testUpdateReviewSuccess() async {
        let review = TestFactory.makeReview(title: "Bearbeitet")

        await sut.updateReview(review, modelContext: container.mainContext)

        XCTAssertEqual(mockDS.updateReviewCalled, 1)
        XCTAssertEqual(mockDS.lastUpdatedReview?.title, "Bearbeitet")
        XCTAssertFalse(sut.isSavingReview)
    }

    func testUpdateReviewOfflineFallback() async {
        mockDS.errorToThrow = NetworkError.timeout
        let review = TestFactory.makeReview(title: "Offline Update")

        await sut.updateReview(review, modelContext: container.mainContext)

        XCTAssertTrue(review.hasPendingSync)
        XCTAssertEqual(review.pendingSyncAction, .update)
    }

    // MARK: - Delete Review

    func testDeleteReviewSuccess() async {
        let review = TestFactory.makeReview(title: "Zum Löschen")
        mockDS.reviewsToReturn = [review]
        await sut.loadReviews()
        mockDS.errorToThrow = nil

        await sut.deleteReview(review, perfume: perfume, modelContext: container.mainContext)

        XCTAssertEqual(mockDS.deleteReviewCalled, 1)
        XCTAssertFalse(sut.reviews.contains(where: { $0.id == review.id }))
    }

    func testDeleteReviewOfflineFallback() async {
        let review = TestFactory.makeReview(title: "Offline Delete")
        mockDS.reviewsToReturn = [review]
        await sut.loadReviews()
        mockDS.errorToThrow = NetworkError.timeout

        await sut.deleteReview(review, perfume: perfume, modelContext: container.mainContext)

        XCTAssertTrue(review.hasPendingSync)
        XCTAssertEqual(review.pendingSyncAction, .delete)
        XCTAssertFalse(sut.reviews.contains(where: { $0.id == review.id }))
    }

    // MARK: - reviewCount

    func testReviewCountUsesServerCount() async {
        mockDS.reviewsToReturn = [TestFactory.makeReview()]
        mockDS.ratingStatsToReturn = TestFactory.makeRatingStats(
            perfumeId: perfume.id, avgRating: 4.0, reviewCount: 42
        )

        await sut.loadReviews()

        XCTAssertEqual(sut.reviewCount, 42)
    }

    func testDeleteDecrementsTotalCount() async {
        let review = TestFactory.makeReview()
        mockDS.reviewsToReturn = [review]
        mockDS.ratingStatsToReturn = TestFactory.makeRatingStats(
            perfumeId: perfume.id, avgRating: 4.0, reviewCount: 5
        )
        await sut.loadReviews()
        mockDS.errorToThrow = nil

        await sut.deleteReview(review, perfume: perfume, modelContext: container.mainContext)

        XCTAssertEqual(sut.reviewTotalCount, 4)
    }
}
