//
//  MockReviewDataSource.swift
//  scentboxdTests
//

import Foundation
@testable import scentboxd

@MainActor
final class MockReviewDataSource: ReviewDataSourceProtocol {
    
    // MARK: - Configurable Responses
    
    var reviewsToReturn: [Review] = []
    var ratingStatsToReturn: RatingStats = RatingStats(
        perfumeId: UUID(),
        avgRating: 0,
        reviewCount: 0
    )
    var errorToThrow: Error?
    var userReviewsToReturn: [ReviewDTO] = []
    var batchRatingStatsToReturn: [UUID: RatingStats] = [:]
    var reviewCountToReturn: Int = 0
    
    // MARK: - Call Tracking
    
    private(set) var fetchReviewsCalled = 0
    private(set) var fetchRatingStatsCalled = 0
    private(set) var saveReviewCalled = 0
    private(set) var updateReviewCalled = 0
    private(set) var deleteReviewCalled = 0
    
    private(set) var lastSavedReview: Review?
    private(set) var lastUpdatedReview: Review?
    private(set) var lastDeletedId: UUID?
    private(set) var fetchUserReviewsCalled = 0
    private(set) var fetchReviewCountCalled = 0
    private(set) var fetchBatchRatingStatsCalled = 0
    
    // MARK: - ReviewDataSourceProtocol
    
    func fetchReviews(for perfumeId: UUID, page: Int, pageSize: Int) async throws -> [Review] {
        fetchReviewsCalled += 1
        if let error = errorToThrow { throw error }
        return reviewsToReturn
    }
    
    func fetchRatingStats(for perfumeId: UUID) async throws -> RatingStats {
        fetchRatingStatsCalled += 1
        if let error = errorToThrow { throw error }
        return ratingStatsToReturn
    }
    
    func saveReview(_ review: Review, for perfumeId: UUID) async throws {
        saveReviewCalled += 1
        lastSavedReview = review
        if let error = errorToThrow { throw error }
    }
    
    func updateReview(_ review: Review, for perfumeId: UUID) async throws {
        updateReviewCalled += 1
        lastUpdatedReview = review
        if let error = errorToThrow { throw error }
    }
    
    func deleteReview(id: UUID) async throws {
        deleteReviewCalled += 1
        lastDeletedId = id
        if let error = errorToThrow { throw error }
    }
    
    func fetchUserReviews() async throws -> [ReviewDTO] {
        fetchUserReviewsCalled += 1
        if let error = errorToThrow { throw error }
        return userReviewsToReturn
    }
    
    func fetchReviewsByUser(userId: UUID) async throws -> [ReviewDTO] {
        if let error = errorToThrow { throw error }
        return userReviewsToReturn
    }

    func fetchReviewCount(for userId: String) async throws -> Int {
        fetchReviewCountCalled += 1
        if let error = errorToThrow { throw error }
        return reviewCountToReturn
    }

    func fetchRatingStatsForPerfumes(_ perfumeIds: [UUID]) async throws -> [UUID: RatingStats] {
        fetchBatchRatingStatsCalled += 1
        if let error = errorToThrow { throw error }
        return batchRatingStatsToReturn
    }
}
