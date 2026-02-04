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
    
    func saveReview(_ review: Review, for perfumeId: UUID) async throws {
        // Hole die aktuelle User-ID und E-Mail aus der Session
        let session = try await client.auth.session
        let userId = session.user.id
        let userEmail = session.user.email ?? "Unbekannt"
        
        // Extrahiere Username aus E-Mail (Teil vor @)
        let authorName = userEmail.components(separatedBy: "@").first ?? "Unbekannt"
        
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
                authorName: dto.authorName
            )
        }
    }
}
