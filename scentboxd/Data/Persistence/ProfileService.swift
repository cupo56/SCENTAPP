//
//  ProfileService.swift
//  scentboxd
//

import Foundation
import Supabase

/// Zentraler Zugriff auf die profiles-Tabelle in Supabase.
@MainActor
final class ProfileService {
    private let client = AppConfig.client

    /// Lädt das Profil für die angegebene User-ID.
    func fetchProfile(userId: UUID) async throws -> ProfileDTO? {
        try await withRetry {
            try await self.client
                .from("profiles")
                .select("*")
                .eq("id", value: userId)
                .single()
                .execute()
                .value
        }
    }

    /// Speichert (upsert) den Username für die angegebene User-ID.
    func saveProfile(userId: UUID, username: String) async throws {
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

    /// Gibt den Anzeigenamen für den aktuellen User zurück (Username oder E-Mail-Prefix).
    func resolveAuthorName() async throws -> String {
        let userId = try await AuthSessionCache.shared.getUserId()

        if let profile = try? await fetchProfile(userId: userId),
           let username = profile.username, !username.isEmpty {
            return username
        }

        let userEmail = try await AuthSessionCache.shared.getUserEmail() ?? String(localized: "Unbekannt")
        return userEmail.components(separatedBy: "@").first ?? String(localized: "Unbekannt")
    }
}
