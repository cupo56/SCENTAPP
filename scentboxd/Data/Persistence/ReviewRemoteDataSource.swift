//
//  ReviewRemoteDataSource.swift
//  scentboxd
//
//  Created by Cupo on 22.01.26.
//

import Foundation
import Supabase

@MainActor
class ReviewRemoteDataSource {
    private let client = AppConfig.client
    
    // MARK: - Rating Aggregation (Server-Side via RPC)
    
    struct RatingStats: Codable {
        let perfumeId: UUID
        let avgRating: Double
        let reviewCount: Int
        
        enum CodingKeys: String, CodingKey {
            case perfumeId = "perfume_id"
            case avgRating = "avg_rating"
            case reviewCount = "review_count"
        }
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
    
    // MARK: - Autorname aus Profil oder E-Mail
    
    private func resolveAuthorName() async throws -> String {
        let userId = try await AuthSessionCache.shared.getUserId()
        
        // Versuche Username aus Profil zu laden
        if let profile: ProfileDTO = try? await withRetry(operation: {
            try await self.client
                .from("profiles")
                .select("*")
                .eq("id", value: userId)
                .single()
                .execute()
                .value
        }),
           let username = profile.username, !username.isEmpty {
            return username
        }
        
        // Fallback: E-Mail-Prefix
        let userEmail = try await AuthSessionCache.shared.getUserEmail() ?? "Unbekannt"
        return userEmail.components(separatedBy: "@").first ?? "Unbekannt"
    }
    
    // MARK: - Create
    
    func saveReview(_ review: Review, for perfumeId: UUID) async throws {
        let userId = try await AuthSessionCache.shared.getUserId()
        let authorName = try await resolveAuthorName()
        
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
    
    /// Gesamtanzahl der Reviews für ein Parfum
    func fetchReviewCount(for perfumeId: UUID) async throws -> Int {
        let response = try await withRetry {
            try await self.client
                .from("reviews")
                .select("id", head: true, count: .exact)
                .eq("perfume_id", value: perfumeId)
                .execute()
        }
        return response.count ?? 0
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
    
    /// Prüft ob der aktuelle Nutzer bereits eine Review für dieses Parfum geschrieben hat
    func fetchExistingReview(for perfumeId: UUID) async throws -> Review? {
        let userId = try await AuthSessionCache.shared.getUserId()
        
        let dtos: [ReviewDTO] = try await withRetry {
            try await self.client
                .from("reviews")
                .select("*")
                .eq("perfume_id", value: perfumeId)
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
                .value
        }
        
        guard let dto = dtos.first else { return nil }
        
        return Review(
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
    
    // MARK: - Update
    
    func updateReview(_ review: Review, for perfumeId: UUID) async throws {
        let authorName = try await resolveAuthorName()
        
        try await withRetry {
            try await self.client
                .from("reviews")
                .update([
                    "title": review.title,
                    "text": review.text,
                    "rating": String(review.rating),
                    "longevity": review.longevity != nil ? String(review.longevity!) : nil,
                    "sillage": review.sillage != nil ? String(review.sillage!) : nil,
                    "author_name": authorName
                ] as [String : String?])
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
    
    // MARK: - Profil
    
    func fetchProfile() async throws -> ProfileDTO? {
        let userId = try await AuthSessionCache.shared.getUserId()
        
        let profile: ProfileDTO? = try? await withRetry {
            try await self.client
                .from("profiles")
                .select("*")
                .eq("id", value: userId)
                .single()
                .execute()
                .value
        }
        
        return profile
    }
    
    func saveProfile(username: String) async throws {
        let userId = try await AuthSessionCache.shared.getUserId()
        
        let dto = ProfileDTO(
            id: userId,
            username: username,
            updatedAt: Date()
        )
        
        try await withRetry {
            try await self.client
                .from("profiles")
                .upsert(dto)
                .execute()
        }
    }
}
