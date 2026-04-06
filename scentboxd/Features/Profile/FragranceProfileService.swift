//
//  FragranceProfileService.swift
//  scentboxd
//

import Foundation
import Observation
import os
import Supabase

@Observable
@MainActor
final class FragranceProfileService {
    // MARK: - State

    var profile: FragranceProfileDTO?
    var isLoading = false
    var errorMessage: String?
    var showErrorAlert = false

    // MARK: - Private

    private let client = AppConfig.client

    // MARK: - Load Profile

    func loadProfile() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let userId = try await AuthSessionCache.shared.getUserId()

            let result: FragranceProfileDTO = try await withRetry {
                try await self.client
                    .rpc("get_user_fragrance_profile", params: ["p_user_id": userId])
                    .execute()
                    .value
            }

            self.profile = result
        } catch {
            errorMessage = NetworkError.handle(error, logger: AppLogger.perfumes, context: "Duftprofil laden")
            showErrorAlert = true
        }
    }
}
