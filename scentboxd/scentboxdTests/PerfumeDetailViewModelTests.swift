//
//  PerfumeDetailViewModelTests.swift
//  scentboxdTests
//

import XCTest
import SwiftData
@testable import scentboxd

@MainActor
final class PerfumeDetailViewModelTests: XCTestCase {

    private var mockReviewDS: MockReviewDataSource!
    private var mockUserPerfumeDS: MockUserPerfumeDataSource!
    private var mockPerfumeRepo: MockPerfumeRepository!
    private var perfume: Perfume!
    private var sut: PerfumeDetailViewModel!
    private var container: ModelContainer!

    override func setUpWithError() throws {
        mockReviewDS = MockReviewDataSource()
        mockUserPerfumeDS = MockUserPerfumeDataSource()
        mockPerfumeRepo = MockPerfumeRepository()

        container = try TestFactory.makeModelContainer()
        perfume = TestFactory.makePerfume(name: "Bleu de Chanel")
        container.mainContext.insert(perfume)

        let reviewService = ReviewManagementService(
            perfumeId: perfume.id,
            reviewDataSource: mockReviewDS
        )
        let statusService = PerfumeStatusService(
            userPerfumeDataSource: mockUserPerfumeDS
        )
        let similarService = SimilarPerfumesService(
            repository: mockPerfumeRepo
        )

        sut = PerfumeDetailViewModel(
            perfume: perfume,
            reviewService: reviewService,
            statusService: statusService,
            similarService: similarService
        )
    }

    override func tearDown() {
        sut = nil
        perfume = nil
        container = nil
        mockReviewDS = nil
        mockUserPerfumeDS = nil
        mockPerfumeRepo = nil
        super.tearDown()
    }

    // MARK: - Load Reviews

    func testLoadReviewsSuccess() async {
        // GIVEN
        let reviews = [
            TestFactory.makeReview(title: "Super Duft"),
            TestFactory.makeReview(title: "Nicht mein Fall", rating: 2)
        ]
        mockReviewDS.reviewsToReturn = reviews
        mockReviewDS.ratingStatsToReturn = TestFactory.makeRatingStats(
            perfumeId: perfume.id,
            avgRating: 3.5,
            reviewCount: 2
        )

        // WHEN
        await sut.reviewService.loadReviews()

        // THEN
        XCTAssertEqual(sut.reviewService.reviews.count, 2, "Sollte 2 Reviews geladen haben.")
        XCTAssertFalse(sut.reviewService.isLoadingReviews, "Ladevorgang sollte beendet sein.")
        XCTAssertEqual(mockReviewDS.fetchReviewsCalled, 1)
    }

    func testLoadReviewsError() async {
        // GIVEN
        mockReviewDS.errorToThrow = NetworkError.timeout

        // WHEN
        await sut.reviewService.loadReviews()

        // THEN
        XCTAssertTrue(sut.reviewService.reviews.isEmpty, "Bei Fehler keine Reviews erwartet.")
        XCTAssertTrue(sut.reviewService.showErrorAlert, "Fehler-Alert sollte angezeigt werden.")
        XCTAssertNotNil(sut.reviewService.errorMessage, "Fehlermeldung sollte gesetzt sein.")
    }

    // MARK: - Save Review

    func testSaveReviewCallsDataSource() async {
        // GIVEN
        let review = TestFactory.makeReview(title: "Neuer Review")

        // WHEN
        await sut.saveReview(review, modelContext: container.mainContext)

        // THEN
        XCTAssertEqual(mockReviewDS.saveReviewCalled, 1, "saveReview sollte aufgerufen werden.")
        XCTAssertEqual(mockReviewDS.lastSavedReview?.title, "Neuer Review")
    }

    // MARK: - Update Review

    func testUpdateReviewCallsDataSource() async {
        // GIVEN
        let review = TestFactory.makeReview(title: "Bearbeitet")

        // WHEN
        await sut.updateReview(review, modelContext: container.mainContext)

        // THEN
        XCTAssertEqual(mockReviewDS.updateReviewCalled, 1, "updateReview sollte aufgerufen werden.")
        XCTAssertEqual(mockReviewDS.lastUpdatedReview?.title, "Bearbeitet")
    }

    // MARK: - Delete Review

    func testDeleteReviewRemovesFromList() async {
        // GIVEN: Load reviews first
        let review = TestFactory.makeReview(title: "Zum Löschen")
        mockReviewDS.reviewsToReturn = [review]
        await sut.reviewService.loadReviews()
        XCTAssertEqual(sut.reviewService.reviews.count, 1)

        // Reset error so delete succeeds
        mockReviewDS.errorToThrow = nil

        // WHEN
        await sut.deleteReview(review, modelContext: container.mainContext)

        // THEN
        XCTAssertTrue(sut.reviewService.reviews.isEmpty, "Review sollte nach Löschen entfernt sein.")
        XCTAssertEqual(mockReviewDS.deleteReviewCalled, 1)
    }

    // MARK: - Computed Properties

    func testHasExistingReviewTrue() async {
        // GIVEN
        let userId = UUID()
        sut.currentUserId = userId
        let review = TestFactory.makeReview(userId: userId)
        mockReviewDS.reviewsToReturn = [review]
        await sut.reviewService.loadReviews()

        // THEN
        XCTAssertTrue(sut.hasExistingReview, "Sollte true sein, wenn User bereits reviewed hat.")
    }

    func testHasExistingReviewFalse() async {
        // GIVEN
        sut.currentUserId = UUID()
        mockReviewDS.reviewsToReturn = [TestFactory.makeReview(userId: UUID())]
        await sut.reviewService.loadReviews()

        // THEN
        XCTAssertFalse(sut.hasExistingReview, "Sollte false sein, wenn kein Review vom User existiert.")
    }

    // MARK: - Rating Stats

    func testLoadRatingStats() async {
        // GIVEN
        mockReviewDS.ratingStatsToReturn = TestFactory.makeRatingStats(
            perfumeId: perfume.id,
            avgRating: 4.5,
            reviewCount: 25
        )
        mockReviewDS.reviewsToReturn = [TestFactory.makeReview()]

        // WHEN
        await sut.reviewService.loadReviews()

        // THEN
        XCTAssertEqual(sut.reviewService.averageRating, 4.5, "Durchschnittliche Bewertung sollte 4.5 sein.")
        XCTAssertEqual(sut.reviewService.serverReviewCount, 25)
    }

    // MARK: - Handle Review Button

    func testHandleReviewButtonNewReview() async {
        // GIVEN: Kein existierender Review
        sut.currentUserId = UUID()
        mockReviewDS.reviewsToReturn = []
        await sut.reviewService.loadReviews()

        // WHEN
        await sut.handleReviewButtonTapped()

        // THEN
        XCTAssertNil(sut.editingReview, "Kein Review zum Bearbeiten erwartet.")
        XCTAssertTrue(sut.showReviewSheet, "Review-Sheet sollte angezeigt werden.")
    }

    func testHandleReviewButtonEditExisting() async {
        // GIVEN: Existierender Review
        let userId = UUID()
        sut.currentUserId = userId
        let existingReview = TestFactory.makeReview(title: "Mein Review", userId: userId)
        mockReviewDS.reviewsToReturn = [existingReview]
        await sut.reviewService.loadReviews()

        // WHEN
        await sut.handleReviewButtonTapped()

        // THEN
        XCTAssertNotNil(sut.editingReview, "Existierender Review sollte zum Bearbeiten gesetzt sein.")
        XCTAssertEqual(sut.editingReview?.title, "Mein Review")
        XCTAssertTrue(sut.showReviewSheet, "Review-Sheet sollte angezeigt werden.")
    }
}
