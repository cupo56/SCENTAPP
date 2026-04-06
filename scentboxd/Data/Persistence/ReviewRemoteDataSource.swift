//
//  ReviewRemoteDataSource.swift
//  scentboxd
//
//  Created by Cupo on 22.01.26.
//

import Foundation
import Supabase
import os

@MainActor
class ReviewRemoteDataSource: ReviewDataSourceProtocol {
    private let client = AppConfig.client
    private let profileService: ProfileService
    private let rateLimiter = AuthRateLimiter(maxAttempts: 10, windowSeconds: 60)

    init(profileService: ProfileService) {
        self.profileService = profileService
    }

    /// Aggregierte Rating-Daten für ein einzelnes Parfum (Supabase RPC)
    func fetchRatingStats(for perfumeId: UUID) async throws -> RatingStats {
        let results: [RatingStats] = try await withRetry {
            try await self.client
                .rpc("get_rating_stats", params: ["p_perfume_id": perfumeId])
                .execute()
                .value
        }
        
        // Falls keine Reviews existieren → leere Stats zurückgeben
        return results.first ?? RatingStats(perfumeId: perfumeId, avgRating: 0, reviewCount: 0)
    }
    
    /// Aggregierte Ratings für mehrere Parfums (Batch via Supabase RPC)
    func fetchRatingStatsForPerfumes(_ perfumeIds: [UUID]) async throws -> [UUID: RatingStats] {
        guard !perfumeIds.isEmpty else { return [:] }
        
        let results: [RatingStats] = try await withRetry {
            try await self.client
                .rpc("get_batch_rating_stats", params: ["p_perfume_ids": perfumeIds])
                .execute()
                .value
        }
        
        var stats: [UUID: RatingStats] = [:]
        for stat in results {
            stats[stat.perfumeId] = stat
        }
        return stats
    }
    
    // MARK: - Rate Limiting

    private func checkRateLimit() throws {
        if let cooldown = rateLimiter.recordAttempt() {
            throw NetworkError.validationFailed("Zu viele Anfragen. Bitte warte \(cooldown) Sekunden.")
        }
    }

    // MARK: - Validation

    private func validateReview(_ review: Review) throws {
        let trimmedText = review.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedText.count >= AppConfig.ReviewDefaults.minTextLength else {
            throw NetworkError.validationFailed("Review-Text muss mindestens \(AppConfig.ReviewDefaults.minTextLength) Zeichen lang sein.")
        }
        guard review.text.count <= AppConfig.ReviewDefaults.maxTextLength else {
            throw NetworkError.validationFailed("Review-Text darf maximal \(AppConfig.ReviewDefaults.maxTextLength) Zeichen lang sein.")
        }
        guard review.title.count <= AppConfig.ReviewDefaults.maxTitleLength else {
            throw NetworkError.validationFailed("Titel darf maximal \(AppConfig.ReviewDefaults.maxTitleLength) Zeichen lang sein.")
        }
        guard (1...5).contains(review.rating) else {
            throw NetworkError.validationFailed("Bewertung muss zwischen 1 und 5 liegen.")
        }
    }

    // MARK: - Create

    func saveReview(_ review: Review, for perfumeId: UUID) async throws {
        try checkRateLimit()
        try validateReview(review)
        let userId = try await AuthSessionCache.shared.getUserId()
        let authorName = try await profileService.resolveAuthorName()

        let dto = ReviewInsertDTO(
            id: review.id,
            perfumeId: perfumeId,
            userId: userId,
            authorName: authorName,
            title: review.title,
            text: review.text,
            rating: review.rating,
            longevity: review.longevity,
            sillage: review.sillage,
            occasions: review.occasions.isEmpty ? nil : review.occasions
        )
        
        try await withRetry {
            try await self.client
                .from("reviews")
                .upsert(dto, onConflict: "user_id,perfume_id")
                .execute()
        }
    }
    
    // MARK: - Read (Paginated)
    
    func fetchReviews(for perfumeId: UUID, page: Int, pageSize: Int) async throws -> [Review] {
        let from = page * pageSize
        let end = from + pageSize - 1

        let dtos: [ReviewDTO] = try await withRetry {
            try await self.client
                .from("reviews")
                .select("*")
                .eq("perfume_id", value: perfumeId)
                .order("created_at", ascending: false)
                .range(from: from, to: end)
                .execute()
                .value
        }
        
        return dtos.compactMap { dto in
            guard let rating = dto.rating else {
                AppLogger.reviews.error("Review \(dto.id) uebersprungen: rating fehlt")
                return nil
            }

            return Review(
                id: dto.id,
                title: dto.title,
                text: dto.text,
                rating: rating,
                longevity: dto.longevity,
                sillage: dto.sillage,
                occasions: dto.occasions ?? [],
                createdAt: dto.createdAt,
                authorName: dto.authorName,
                userId: dto.userId
            )
        }
    }
    
    /// Lädt alle Reviews, die der aktuelle User geschrieben hat
    func fetchUserReviews() async throws -> [ReviewDTO] {
        let userId = try await AuthSessionCache.shared.getUserId()
        
        let dtos: [ReviewDTO] = try await withRetry {
            try await self.client
                .from("reviews")
                .select("*")
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value
        }
        return dtos.filter { dto in
            guard dto.perfumeId != nil, dto.rating != nil else {
                AppLogger.reviews.error("User-Review \(dto.id) uebersprungen: Pflichtfelder fehlen")
                return false
            }
            return true
        }
    }
    
    /// Lädt paginierte Reviews eines bestimmten Users (für öffentliche Profile).
    func fetchReviewsByUser(userId: UUID, page: Int, pageSize: Int) async throws -> [ReviewDTO] {
        let from = page * pageSize
        let end = from + pageSize - 1

        let dtos: [ReviewDTO] = try await withRetry {
            try await self.client
                .from("reviews")
                .select("*")
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .range(from: from, to: end)
                .execute()
                .value
        }
        return dtos.filter { $0.perfumeId != nil && $0.rating != nil }
    }

    /// Lädt die Anzahl der Reviews für einen bestimmten User
    func fetchReviewCount(for userId: String) async throws -> Int {
        let response = try await withRetry {
            try await self.client
                .from("reviews")
                .select("id", head: true, count: .exact)
                .eq("user_id", value: userId)
                .execute()
        }
        return response.count ?? 0
    }
    
    // MARK: - Update
    
    func updateReview(_ review: Review, for perfumeId: UUID) async throws {
        try checkRateLimit()
        try validateReview(review)
        let authorName = try await profileService.resolveAuthorName()

        let dto = ReviewUpdateDTO(
            title: review.title,
            text: review.text,
            rating: review.rating,
            longevity: review.longevity,
            sillage: review.sillage,
            occasions: review.occasions.isEmpty ? nil : review.occasions,
            authorName: authorName
        )

        try await withRetry {
            try await self.client
                .from("reviews")
                .update(dto)
                .eq("id", value: review.id)
                .execute()
        }
    }
    
    // MARK: - Delete
    
    func deleteReview(id: UUID) async throws {
        try checkRateLimit()
        try await withRetry {
            try await self.client
                .from("reviews")
                .delete()
                .eq("id", value: id)
                .execute()
        }
    }

    // MARK: - Likes

    func toggleLike(reviewId: UUID) async throws -> ReviewLikeResult {
        try checkRateLimit()
        let result: ReviewLikeResult = try await withRetry {
            try await self.client
                .rpc("toggle_review_like", params: ["p_review_id": reviewId])
                .execute()
                .value
        }
        return result
    }

    func fetchLikeStatus(reviewIds: [UUID]) async throws -> [UUID: ReviewLikeInfo] {
        guard !reviewIds.isEmpty else { return [:] }

        let infos: [ReviewLikeInfo] = try await withRetry {
            try await self.client
                .rpc("get_review_likes_batch", params: ["p_review_ids": reviewIds])
                .execute()
                .value
        }

        var result: [UUID: ReviewLikeInfo] = [:]
        for info in infos {
            result[info.reviewId] = info
        }
        return result
    }
}
