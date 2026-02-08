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
    
    // MARK: - Autorname aus Profil oder E-Mail
    
    private func resolveAuthorName() async throws -> String {
        let session = try await client.auth.session
        let userId = session.user.id
        
        // Versuche Username aus Profil zu laden
        if let profile: ProfileDTO = try? await client
            .from("profiles")
            .select("*")
            .eq("id", value: userId)
            .single()
            .execute()
            .value,
           let username = profile.username, !username.isEmpty {
            return username
        }
        
        // Fallback: E-Mail-Prefix
        let userEmail = session.user.email ?? "Unbekannt"
        return userEmail.components(separatedBy: "@").first ?? "Unbekannt"
    }
    
    // MARK: - Create
    
    func saveReview(_ review: Review, for perfumeId: UUID) async throws {
        let session = try await client.auth.session
        let userId = session.user.id
        let authorName = try await resolveAuthorName()
        
        let dto = ReviewDTO(
            id: review.id,
            perfumeId: perfumeId,
            userId: userId,
            authorName: authorName,
            title: review.title,
            text: review.text,
            rating: review.rating,
            createdAt: review.createdAt
        )
        
        try await client
            .from("reviews")
            .insert(dto)
            .execute()
    }
    
    // MARK: - Read
    
    func fetchReviews(for perfumeId: UUID) async throws -> [Review] {
        let dtos: [ReviewDTO] = try await client
            .from("reviews")
            .select("*")
            .eq("perfume_id", value: perfumeId)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return dtos.map { dto in
            Review(
                id: dto.id,
                title: dto.title,
                text: dto.text,
                rating: dto.rating,
                createdAt: dto.createdAt,
                authorName: dto.authorName,
                userId: dto.userId
            )
        }
    }
    
    /// Prüft ob der aktuelle Nutzer bereits eine Review für dieses Parfum geschrieben hat
    func fetchExistingReview(for perfumeId: UUID) async throws -> Review? {
        let session = try await client.auth.session
        let userId = session.user.id
        
        let dtos: [ReviewDTO] = try await client
            .from("reviews")
            .select("*")
            .eq("perfume_id", value: perfumeId)
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
        
        guard let dto = dtos.first else { return nil }
        
        return Review(
            id: dto.id,
            title: dto.title,
            text: dto.text,
            rating: dto.rating,
            createdAt: dto.createdAt,
            authorName: dto.authorName,
            userId: dto.userId
        )
    }
    
    // MARK: - Update
    
    func updateReview(_ review: Review, for perfumeId: UUID) async throws {
        let authorName = try await resolveAuthorName()
        
        try await client
            .from("reviews")
            .update([
                "title": review.title,
                "text": review.text,
                "rating": String(review.rating),
                "author_name": authorName
            ])
            .eq("id", value: review.id)
            .execute()
    }
    
    // MARK: - Delete
    
    func deleteReview(id: UUID) async throws {
        try await client
            .from("reviews")
            .delete()
            .eq("id", value: id)
            .execute()
    }
    
    // MARK: - Profil
    
    func fetchProfile() async throws -> ProfileDTO? {
        let session = try await client.auth.session
        let userId = session.user.id
        
        let profile: ProfileDTO? = try? await client
            .from("profiles")
            .select("*")
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        
        return profile
    }
    
    func saveProfile(username: String) async throws {
        let session = try await client.auth.session
        let userId = session.user.id
        
        let dto = ProfileDTO(
            id: userId,
            username: username,
            updatedAt: Date()
        )
        
        try await client
            .from("profiles")
            .upsert(dto)
            .execute()
    }
}
