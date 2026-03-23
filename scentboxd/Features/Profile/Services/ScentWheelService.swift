//
//  ScentWheelService.swift
//  scentboxd
//

import Foundation
import Observation
import Supabase

@Observable
@MainActor
final class ScentWheelService {
    // MARK: - State

    var segments: [ScentWheelSegment] = []
    var isLoading = false
    var errorMessage: String?
    var showErrorAlert = false

    // MARK: - Private

    private let client = AppConfig.client

    // MARK: - Load

    func loadScentWheel() async {
        guard segments.isEmpty else { return } // Nur einmal laden (einfaches Caching)
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let userId = try await AuthSessionCache.shared.getUserId()

            let result: [ScentWheelSegment] = try await withRetry {
                try await self.client
                    .rpc("get_user_scent_wheel", params: ["p_user_id": userId])
                    .execute()
                    .value
            }

            self.segments = result
        } catch {
            errorMessage = NetworkError.handle(error, logger: AppLogger.perfumes, context: "Duftrad laden")
            showErrorAlert = true
        }
    }

    /// Erzwingt einen Reload (z.B. nach Pull-to-Refresh).
    func reload() async {
        segments = []
        await loadScentWheel()
    }
}
