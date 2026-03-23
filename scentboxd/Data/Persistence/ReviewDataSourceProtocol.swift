//
//  ReviewDataSourceProtocol.swift
//  scentboxd
//

import Foundation

/// Protocol for review data source operations, enabling dependency injection and testability.
@MainActor
protocol ReviewDataSourceProtocol {
    /// Fetches paginated reviews for a perfume.
    func fetchReviews(for perfumeId: UUID, page: Int, pageSize: Int) async throws -> [Review]
    
    /// Fetches aggregated rating statistics for a perfume.
    func fetchRatingStats(for perfumeId: UUID) async throws -> RatingStats
    
    /// Saves a new review for a perfume (upsert).
    func saveReview(_ review: Review, for perfumeId: UUID) async throws
    
    /// Updates an existing review.
    func updateReview(_ review: Review, for perfumeId: UUID) async throws
    
    /// Deletes a review by ID.
    func deleteReview(id: UUID) async throws
    
    /// Fetches all reviews written by the current user.
    func fetchUserReviews() async throws -> [ReviewDTO]
    
    /// Fetches all reviews written by a specific user (for public profiles).
    func fetchReviewsByUser(userId: UUID) async throws -> [ReviewDTO]

    /// Fetches the total count of reviews written by a specific user.
    func fetchReviewCount(for userId: String) async throws -> Int
    
    /// Fetches aggregated rating statistics for multiple perfumes (batch).
    func fetchRatingStatsForPerfumes(_ perfumeIds: [UUID]) async throws -> [UUID: RatingStats]
}
