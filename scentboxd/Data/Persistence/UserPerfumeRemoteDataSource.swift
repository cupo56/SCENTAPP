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
    func saveUserPerfume(perfumeId: UUID, isFavorite: Bool, isOwned: Bool, isEmpty: Bool) async throws {
        let userId = try await AuthSessionCache.shared.getUserId()

        let dto = UserPerfumeDTO(
            userId: userId,
            perfumeId: perfumeId,
            isFavorite: isFavorite,
            isOwned: isOwned,
            isEmpty: isEmpty,
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
}
