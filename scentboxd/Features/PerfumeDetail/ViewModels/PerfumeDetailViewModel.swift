//
//  PerfumeDetailViewModel.swift
//  scentboxd
//
//  Created by Cupo on 09.02.26.
//

import Foundation
import SwiftData
import Observation
import Supabase
import os

@Observable
@MainActor
class PerfumeDetailViewModel {
    // MARK: - State
    
    var showReviewSheet = false
    var isSavingReview = false
    var reviews: [Review] = []
    var isLoadingReviews = false
    var showLoginAlert = false
    var editingReview: Review? = nil
    var currentUserId: UUID? = nil
    var reviewErrorMessage: String? = nil
    var showReviewErrorAlert = false
    var syncErrorMessage: String? = nil
    var showSyncErrorAlert = false
    
    // Task-Tracking für Cancellation
    private var syncTask: Task<Void, Never>?
    private var lastToggleTime: Date = .distantPast
    
    // MARK: - Dependencies
    
    let perfume: Perfume
    private let reviewDataSource: ReviewRemoteDataSource
    private let userPerfumeDataSource: UserPerfumeRemoteDataSource
    
    // MARK: - Init
    
    init(
        perfume: Perfume,
        reviewDataSource: ReviewRemoteDataSource? = nil,
        userPerfumeDataSource: UserPerfumeRemoteDataSource? = nil
    ) {
        self.perfume = perfume
        self.reviewDataSource = reviewDataSource ?? ReviewRemoteDataSource()
        self.userPerfumeDataSource = userPerfumeDataSource ?? UserPerfumeRemoteDataSource()
    }
    
    // MARK: - Computed Properties
    
    var hasExistingReview: Bool {
        guard let userId = currentUserId else { return false }
        return reviews.contains { $0.userId == userId }
    }
    
    var reviewCount: Int {
        reviews.count
    }
    
    var averageRating: Double? {
        guard !reviews.isEmpty else { return nil }
        let sum = reviews.reduce(0) { $0 + $1.rating }
        return Double(sum) / Double(reviews.count)
    }
    
    // MARK: - Review Loading
    
    func loadCurrentUserId() async {
        do {
            let session = try await AppConfig.client.auth.session
            currentUserId = session.user.id
        } catch {
            currentUserId = nil
        }
    }
    
    func loadReviews() async {
        isLoadingReviews = true
        do {
            reviews = try await withRetry {
                try await self.reviewDataSource.fetchReviews(for: self.perfume.id)
            }
        } catch {
            let networkError = NetworkError.from(error)
            AppLogger.reviews.error("Fehler beim Laden der Bewertungen: \(networkError.localizedDescription)")
            reviewErrorMessage = networkError.localizedDescription
            showReviewErrorAlert = true
        }
        isLoadingReviews = false
    }
    
    // MARK: - Review Actions
    
    func handleReviewButtonTapped() async {
        if let existing = reviews.first(where: { $0.userId == currentUserId }) {
            editingReview = existing
            showReviewSheet = true
        } else {
            editingReview = nil
            showReviewSheet = true
        }
    }
    
    func saveReview(_ review: Review, modelContext: ModelContext) async {
        isSavingReview = true
        defer { isSavingReview = false }
        do {
            try await withRetry {
                try await self.reviewDataSource.saveReview(review, for: self.perfume.id)
            }

            // Lokal speichern (SwiftData)
            if perfume.modelContext == nil {
                modelContext.insert(perfume)
            }
            review.perfume = perfume
            // Nur anhängen wenn noch nicht vorhanden (verhindert Duplikate)
            if !perfume.reviews.contains(where: { $0.id == review.id }) {
                perfume.reviews.append(review)
            }
            do {
                try modelContext.save()
            } catch {
                AppLogger.cache.error("SwiftData-Speichern fehlgeschlagen (saveReview): \(error.localizedDescription)")
            }

            // Remote-Liste neu laden um userId etc. korrekt zu haben
            await loadReviews()
        } catch {
            let networkError = NetworkError.from(error)
            AppLogger.reviews.error("Fehler beim Speichern der Bewertung: \(networkError.localizedDescription)")
            reviewErrorMessage = networkError.localizedDescription
            showReviewErrorAlert = true
        }
    }
    
    func updateReview(_ review: Review) async {
        isSavingReview = true
        defer { isSavingReview = false }
        do {
            try await withRetry {
                try await self.reviewDataSource.updateReview(review, for: self.perfume.id)
            }
            await loadReviews()
        } catch {
            let networkError = NetworkError.from(error)
            AppLogger.reviews.error("Fehler beim Aktualisieren der Bewertung: \(networkError.localizedDescription)")
            reviewErrorMessage = networkError.localizedDescription
            showReviewErrorAlert = true
        }
    }
    
    func deleteReview(_ review: Review, modelContext: ModelContext) async {
        isSavingReview = true
        defer { isSavingReview = false }
        do {
            // Remote-Löschen zuerst — bei Fehler bleibt der lokale State unverändert
            try await withRetry {
                try await self.reviewDataSource.deleteReview(id: review.id)
            }
            // Erst nach erfolgreichem Remote-Delete lokal entfernen
            reviews.removeAll { $0.id == review.id }
            perfume.reviews.removeAll { $0.id == review.id }
            do {
                try modelContext.save()
            } catch {
                AppLogger.cache.error("SwiftData-Speichern fehlgeschlagen (deleteReview): \(error.localizedDescription)")
            }
        } catch {
            let networkError = NetworkError.from(error)
            AppLogger.reviews.error("Fehler beim Löschen der Bewertung: \(networkError.localizedDescription)")
            reviewErrorMessage = networkError.localizedDescription
            showReviewErrorAlert = true
        }
    }
    
    // MARK: - Status Toggle
    
    func isActive(_ status: UserPerfumeStatus) -> Bool {
        return perfume.userMetadata?.statusRaw == status.rawValue
    }
    
    func toggleStatus(_ targetStatus: UserPerfumeStatus, modelContext: ModelContext, isAuthenticated: Bool) {
        // Rate Limiting: Maximal 1 Toggle pro 0,5 Sekunden
        let now = Date()
        guard now.timeIntervalSince(lastToggleTime) >= 0.5 else { return }
        lastToggleTime = now
        
        // 1. Aus Cloud lokal übernehmen, falls nötig
        if perfume.modelContext == nil {
            modelContext.insert(perfume)
        }
        
        // 2. Bestimme den neuen Status
        let newStatus: UserPerfumeStatus
        if let metadata = perfume.userMetadata {
            // Toggle Logik: Wenn schon aktiv, dann deaktivieren (.none)
            if metadata.statusRaw == targetStatus.rawValue {
                newStatus = .none
            } else {
                newStatus = targetStatus
            }
            metadata.status = newStatus
        } else {
            // Neu anlegen
            newStatus = targetStatus
            let newMeta = UserPersonalData(status: targetStatus)
            perfume.userMetadata = newMeta
        }
        
        // 3. Lokal speichern
        do {
            try modelContext.save()
        } catch {
            AppLogger.cache.error("SwiftData-Speichern fehlgeschlagen (toggleStatus): \(error.localizedDescription)")
        }
        
        // 4. In Supabase speichern (wenn eingeloggt)
        if isAuthenticated {
            syncTask?.cancel()
            syncTask = Task {
                await syncStatusToSupabase(perfumeId: perfume.id, status: newStatus)
            }
        }
    }
    
    // MARK: - Supabase Sync
    
    private func syncStatusToSupabase(perfumeId: UUID, status: UserPerfumeStatus) async {
        do {
            try await withRetry {
                if status == .none {
                    try await self.userPerfumeDataSource.deleteUserPerfume(perfumeId: perfumeId)
                } else {
                    try await self.userPerfumeDataSource.saveUserPerfume(perfumeId: perfumeId, status: status)
                }
            }
        } catch {
            let networkError = NetworkError.from(error)
            AppLogger.userPerfumes.error("Fehler beim Sync mit Supabase: \(networkError.localizedDescription)")
            syncErrorMessage = networkError.localizedDescription
            showSyncErrorAlert = true
        }
    }
}
