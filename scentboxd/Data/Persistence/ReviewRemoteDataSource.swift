//
//  ReviewRemoteDataSource.swift
//  scentboxd
//
//  Created by Cupo on 22.01.26.
//

import Foundation
import Supabase

@MainActor
class ReviewRemoteDataSource: ReviewDataSourceProtocol {
    private let client = AppConfig.client
    private let profileService = ProfileService()

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
    
    // MARK: - Create
    
    func saveReview(_ review: Review, for perfumeId: UUID) async throws {
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
            sillage: review.sillage
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
        let to = from + pageSize - 1
        
        let dtos: [ReviewDTO] = try await withRetry {
            try await self.client
                .from("reviews")
                .select("*")
                .eq("perfume_id", value: perfumeId)
                .order("created_at", ascending: false)
                .range(from: from, to: to)
                .execute()
                .value
        }
        
        return dtos.map { dto in
            Review(
                id: dto.id,
                title: dto.title,
                text: dto.text,
                rating: dto.rating,
                longevity: dto.longevity,
                sillage: dto.sillage,
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
        return dtos
    }
    
    // MARK: - Update
    
    func updateReview(_ review: Review, for perfumeId: UUID) async throws {
        let authorName = try await profileService.resolveAuthorName()

        let dto = ReviewUpdateDTO(
            title: review.title,
            text: review.text,
            rating: review.rating,
            longevity: review.longevity,
            sillage: review.sillage,
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
        try await withRetry {
            try await self.client
                .from("reviews")
                .delete()
                .eq("id", value: id)
                .execute()
        }
    }
}
