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
    var isLoadingMoreReviews = false
    var reviewTotalCount: Int? = nil
    var showLoginAlert = false
    var editingReview: Review? = nil
    var currentUserId: UUID? = nil
    var reviewErrorMessage: String? = nil
    var showReviewErrorAlert = false
    var syncErrorMessage: String? = nil
    var showSyncErrorAlert = false
    
    // Server-side Rating Aggregation
    var averageRating: Double? = nil
    var serverReviewCount: Int? = nil
    
    // Task-Tracking für Cancellation
    private var syncTask: Task<Void, Never>?
    private var lastToggleTime: Date = .distantPast
    
    // Pagination
    private let reviewPageSize = 10
    private var currentReviewPage = 0
    private var hasMoreReviews = true
    
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
        serverReviewCount ?? reviewTotalCount ?? reviews.count
    }
    
    // MARK: - Review Loading (Paginated)
    
    func loadCurrentUserId() async {
        do {
            currentUserId = try await AuthSessionCache.shared.getUserId()
        } catch {
            currentUserId = nil
        }
    }
    
    func loadReviews() async {
        isLoadingReviews = true
        currentReviewPage = 0
        hasMoreReviews = true
        
        do {
            reviews = try await reviewDataSource.fetchReviews(for: perfume.id, page: 0, pageSize: reviewPageSize)
            hasMoreReviews = reviews.count >= reviewPageSize

            // Rating-Statistik und Gesamtanzahl laden
            await loadRatingStats()
        } catch {
            let networkError = NetworkError.from(error)
            AppLogger.reviews.error("Fehler beim Laden der Bewertungen: \(networkError.localizedDescription)")
            reviewErrorMessage = networkError.localizedDescription
            showReviewErrorAlert = true
        }
        isLoadingReviews = false
    }
    
    func loadMoreReviewsIfNeeded(currentReview: Review) async {
        guard let lastReview = reviews.last,
              lastReview.id == currentReview.id,
              hasMoreReviews,
              !isLoadingReviews,
              !isLoadingMoreReviews else { return }
        
        isLoadingMoreReviews = true
        defer { isLoadingMoreReviews = false }
        
        let nextPage = currentReviewPage + 1
        
        do {
            let moreReviews = try await reviewDataSource.fetchReviews(for: perfume.id, page: nextPage, pageSize: reviewPageSize)
            self.reviews.append(contentsOf: moreReviews)
            self.currentReviewPage = nextPage
            self.hasMoreReviews = moreReviews.count >= reviewPageSize
        } catch {
            let networkError = NetworkError.from(error)
            AppLogger.reviews.error("Fehler beim Nachladen der Bewertungen: \(networkError.localizedDescription)")
        }
    }
    
    // MARK: - Server-Side Rating Stats
    
    func loadRatingStats() async {
        do {
            let stats = try await reviewDataSource.fetchRatingStats(for: perfume.id)
            self.averageRating = stats.reviewCount > 0 ? stats.avgRating : nil
            self.serverReviewCount = stats.reviewCount
            self.reviewTotalCount = stats.reviewCount
        } catch {
            AppLogger.reviews.error("Rating-Stats laden fehlgeschlagen: \(error.localizedDescription)")
        }
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
            try await reviewDataSource.saveReview(review, for: perfume.id)

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
            try await reviewDataSource.updateReview(review, for: perfume.id)
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
            try await reviewDataSource.deleteReview(id: review.id)
            // Erst nach erfolgreichem Remote-Delete lokal entfernen
            reviews.removeAll { $0.id == review.id }
            perfume.reviews.removeAll { $0.id == review.id }
            if let count = reviewTotalCount {
                reviewTotalCount = max(0, count - 1)
            }
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
            metadata.hasPendingSync = true
        } else {
            // Neu anlegen
            newStatus = targetStatus
            let newMeta = UserPersonalData(status: targetStatus, hasPendingSync: true)
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
            if status == .none {
                try await userPerfumeDataSource.deleteUserPerfume(perfumeId: perfumeId)
            } else {
                try await userPerfumeDataSource.saveUserPerfume(perfumeId: perfumeId, status: status)
            }
            // Upload erfolgreich → Pending-Flag löschen
            perfume.userMetadata?.hasPendingSync = false
        } catch {
            let networkError = NetworkError.from(error)
            AppLogger.userPerfumes.error("Fehler beim Sync mit Supabase: \(networkError.localizedDescription)")
            syncErrorMessage = networkError.localizedDescription
            showSyncErrorAlert = true
        }
    }
}
