//
//  PublicProfileDataSource.swift
//  scentboxd
//

import Foundation
import Supabase

/// Zugriff auf öffentliche Benutzerprofile und deren Sammlungen.
@MainActor
final class PublicProfileDataSource: PublicProfileDataSourceProtocol {
    private let client = AppConfig.client

    /// Lädt das öffentliche Profil eines Users via RPC.
    func fetchPublicProfile(userId: UUID) async throws -> PublicProfileDTO {
        try await withRetry {
            try await self.client
                .rpc("get_public_user_profile", params: ["target_user_id": userId])
                .single()
                .execute()
                .value
        }
    }

    /// Lädt die öffentliche Sammlung eines Users (paginiert) via RPC.
    func fetchPublicCollection(userId: UUID, page: Int, pageSize: Int) async throws -> [PublicCollectionItemDTO] {
        try await withRetry {
            try await self.client
                .rpc("get_public_user_collection", params: [
                    "target_user_id": AnyJSON.string(userId.uuidString),
                    "p_page": AnyJSON.integer(page),
                    "p_page_size": AnyJSON.integer(pageSize)
                ])
                .execute()
                .value
        }
    }

    /// Sucht User anhand eines Suchbegriffs (Username).
    func searchUsers(query: String) async throws -> [PublicProfileDTO] {
        let sanitized = query
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")

        guard !sanitized.trimmingCharacters(in: .whitespaces).isEmpty else {
            return []
        }

        return try await withRetry {
            try await self.client
                .from("profiles")
                .select("id, username, bio, avatar_url, is_public")
                .eq("is_public", value: true)
                .ilike("username", pattern: "%\(sanitized)%")
                .limit(20)
                .execute()
                .value
        }
    }

    /// Aktualisiert die Sichtbarkeit des eigenen Profils.
    func updateProfileVisibility(userId: UUID, isPublic: Bool) async throws {
        try await withRetry {
            try await self.client
                .from("profiles")
                .update(["is_public": isPublic])
                .eq("id", value: userId)
                .execute()
        }
    }

    /// Aktualisiert die Bio des eigenen Profils.
    func updateBio(userId: UUID, bio: String) async throws {
        try await withRetry {
            try await self.client
                .from("profiles")
                .update(["bio": bio])
                .eq("id", value: userId)
                .execute()
        }
    }
}
