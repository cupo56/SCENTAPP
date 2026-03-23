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

    var syncErrorMessage: String?
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
        toggleStatus(
            perfume: perfume,
            modelContext: modelContext,
            isAuthenticated: isAuthenticated,
            keyPath: \.isFavorite,
            defaultMetadata: UserPersonalData(isFavorite: true, hasPendingSync: true)
        )
    }

    func toggleOwned(perfume: Perfume, modelContext: ModelContext, isAuthenticated: Bool) {
        toggleStatus(
            perfume: perfume,
            modelContext: modelContext,
            isAuthenticated: isAuthenticated,
            keyPath: \.isOwned,
            defaultMetadata: UserPersonalData(isOwned: true, hasPendingSync: true)
        )
    }

    private func toggleStatus(
        perfume: Perfume,
        modelContext: ModelContext,
        isAuthenticated: Bool,
        keyPath: ReferenceWritableKeyPath<UserPersonalData, Bool>,
        defaultMetadata: UserPersonalData
    ) {
        guard !isToggling, throttleToggle() else { return }
        isToggling = true
        ensureInserted(perfume: perfume, modelContext: modelContext)

        if let metadata = perfume.userMetadata {
            metadata[keyPath: keyPath].toggle()
            metadata.hasPendingSync = true
        } else {
            perfume.userMetadata = defaultMetadata
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
                    perfumeId: perfumeId,
                    modelContext: modelContext,
                    isFavorite: meta?.isFavorite ?? false,
                    isOwned: meta?.isOwned ?? false,
                    isWantToTry: meta?.isWantToTry ?? false
                )
                isToggling = false
            }
        } else {
            isToggling = false
        }
    }

    private func syncStatusToSupabase(perfumeId: UUID, modelContext: ModelContext, isFavorite: Bool, isOwned: Bool, isWantToTry: Bool) async {
        do {
            if !isFavorite && !isOwned && !isWantToTry {
                try await userPerfumeDataSource.deleteUserPerfume(perfumeId: perfumeId)
            } else {
                try await userPerfumeDataSource.saveUserPerfume(
                    perfumeId: perfumeId,
                    isFavorite: isFavorite,
                    isOwned: isOwned,
                    isWantToTry: isWantToTry
                )
            }
            let predicate = #Predicate<Perfume> { $0.id == perfumeId }
            var descriptor = FetchDescriptor<Perfume>(predicate: predicate)
            descriptor.fetchLimit = 1
            if let perfume = try? modelContext.fetch(descriptor).first {
                perfume.userMetadata?.hasPendingSync = false
            }
        } catch {
            syncErrorMessage = NetworkError.handle(error, logger: AppLogger.userPerfumes, context: "Supabase-Sync")
            showSyncErrorAlert = true
        }
    }
}
