//
//  PerfumeStatusService.swift
//  scentboxd
//

import Foundation
import SwiftData
import os

@Observable
@MainActor
final class PerfumeStatusService {
    // MARK: - State

    var syncErrorMessage: String? = nil
    var showSyncErrorAlert = false

    // MARK: - Private

    private var isToggling = false
    private var syncTask: Task<Void, Never>?
    private var lastToggleTime: Date = .distantPast
    private let userPerfumeDataSource: any UserPerfumeDataSourceProtocol

    init(userPerfumeDataSource: any UserPerfumeDataSourceProtocol) {
        self.userPerfumeDataSource = userPerfumeDataSource
    }

    // MARK: - Status Checks

    func isFavorite(_ perfume: Perfume) -> Bool {
        perfume.userMetadata?.isFavorite ?? false
    }

    func isOwned(_ perfume: Perfume) -> Bool {
        perfume.userMetadata?.isOwned ?? false
    }

    // MARK: - Toggles

    func toggleFavorite(perfume: Perfume, modelContext: ModelContext, isAuthenticated: Bool) {
        guard !isToggling, throttleToggle() else { return }
        isToggling = true
        ensureInserted(perfume: perfume, modelContext: modelContext)

        if let metadata = perfume.userMetadata {
            metadata.isFavorite.toggle()
            metadata.hasPendingSync = true
        } else {
            perfume.userMetadata = UserPersonalData(isFavorite: true, hasPendingSync: true)
        }

        saveAndSync(perfume: perfume, modelContext: modelContext, isAuthenticated: isAuthenticated)
    }

    func toggleOwned(perfume: Perfume, modelContext: ModelContext, isAuthenticated: Bool) {
        guard !isToggling, throttleToggle() else { return }
        isToggling = true
        ensureInserted(perfume: perfume, modelContext: modelContext)

        if let metadata = perfume.userMetadata {
            metadata.isOwned.toggle()
            metadata.hasPendingSync = true
        } else {
            perfume.userMetadata = UserPersonalData(isOwned: true, hasPendingSync: true)
        }

        saveAndSync(perfume: perfume, modelContext: modelContext, isAuthenticated: isAuthenticated)
    }

    // MARK: - Private Helpers

    private func throttleToggle() -> Bool {
        let now = Date()
        guard now.timeIntervalSince(lastToggleTime) >= AppConfig.Timing.toggleThrottleInterval else { return false }
        lastToggleTime = now
        return true
    }

    private func ensureInserted(perfume: Perfume, modelContext: ModelContext) {
        if perfume.modelContext == nil {
            modelContext.insert(perfume)
        }
    }

    private func saveAndSync(perfume: Perfume, modelContext: ModelContext, isAuthenticated: Bool) {
        do {
            try modelContext.save()
        } catch {
            AppLogger.cache.error("SwiftData-Speichern fehlgeschlagen (toggleStatus): \(error.localizedDescription)")
        }

        if isAuthenticated {
            syncTask?.cancel()
            let meta = perfume.userMetadata
            let perfumeId = perfume.id
            syncTask = Task {
                await syncStatusToSupabase(
                    perfume: perfume,
                    perfumeId: perfumeId,
                    isFavorite: meta?.isFavorite ?? false,
                    isOwned: meta?.isOwned ?? false,
                    isEmpty: meta?.isEmpty ?? false
                )
                isToggling = false
            }
        } else {
            isToggling = false
        }
    }

    private func syncStatusToSupabase(perfume: Perfume, perfumeId: UUID, isFavorite: Bool, isOwned: Bool, isEmpty: Bool) async {
        do {
            if !isFavorite && !isOwned && !isEmpty {
                try await userPerfumeDataSource.deleteUserPerfume(perfumeId: perfumeId)
            } else {
                try await userPerfumeDataSource.saveUserPerfume(
                    perfumeId: perfumeId,
                    isFavorite: isFavorite,
                    isOwned: isOwned,
                    isEmpty: isEmpty
                )
            }
            perfume.userMetadata?.hasPendingSync = false
        } catch {
            syncErrorMessage = NetworkError.handle(error, logger: AppLogger.userPerfumes, context: "Supabase-Sync")
            showSyncErrorAlert = true
        }
    }
}
