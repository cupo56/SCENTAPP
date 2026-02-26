//
//  UserPerfumeRemoteDataSource.swift
//  scentboxd
//
//  Created by Cupo on 25.01.26.
//

import Foundation
import Supabase

@MainActor
class UserPerfumeRemoteDataSource {
    private let client = AppConfig.client
    
    /// Speichert oder aktualisiert den Status eines Parfums für den aktuellen User
    func saveUserPerfume(perfumeId: UUID, status: UserPerfumeStatus) async throws {
        let userId = try await AuthSessionCache.shared.getUserId()
        
        let dto = UserPerfumeDTO(
            userId: userId,
            perfumeId: perfumeId,
            status: status.rawValue,
            createdAt: Date()
        )
        
        // Upsert: Fügt ein oder aktualisiert, falls (user_id, perfume_id) existiert
        try await withRetry {
            try await self.client
                .from("user_perfumes")
                .upsert(dto, onConflict: "user_id,perfume_id")
                .execute()
        }
    }
    
    /// Löscht den Status eines Parfums für den aktuellen User
    func deleteUserPerfume(perfumeId: UUID) async throws {
        let userId = try await AuthSessionCache.shared.getUserId()
        
        try await withRetry {
            try await self.client
                .from("user_perfumes")
                .delete()
                .eq("user_id", value: userId)
                .eq("perfume_id", value: perfumeId)
                .execute()
        }
    }
    
    /// Lädt alle Parfums mit einem bestimmten Status für den aktuellen User
    func fetchUserPerfumes(withStatus status: UserPerfumeStatus) async throws -> [UUID] {
        let userId = try await AuthSessionCache.shared.getUserId()
        
        let dtos: [UserPerfumeDTO] = try await withRetry {
            try await self.client
                .from("user_perfumes")
                .select("*")
                .eq("user_id", value: userId)
                .eq("status", value: status.rawValue)
                .execute()
                .value
        }
        
        return dtos.map { $0.perfumeId }
    }
    
    /// Lädt alle User-Parfum-Zuordnungen für den aktuellen User
    func fetchAllUserPerfumes() async throws -> [UserPerfumeDTO] {
        let userId = try await AuthSessionCache.shared.getUserId()
        
        return try await withRetry {
            try await self.client
                .from("user_perfumes")
                .select("*")
                .eq("user_id", value: userId)
                .execute()
                .value
        }
    }
    
    /// Prüft, ob ein bestimmtes Parfum einen Status hat
    func getUserPerfumeStatus(perfumeId: UUID) async throws -> UserPerfumeStatus? {
        let userId = try await AuthSessionCache.shared.getUserId()
        
        let dtos: [UserPerfumeDTO] = try await withRetry {
            try await self.client
                .from("user_perfumes")
                .select("*")
                .eq("user_id", value: userId)
                .eq("perfume_id", value: perfumeId)
                .execute()
                .value
        }
        
        guard let dto = dtos.first else { return nil }
        return UserPerfumeStatus(rawValue: dto.status)
    }
}
