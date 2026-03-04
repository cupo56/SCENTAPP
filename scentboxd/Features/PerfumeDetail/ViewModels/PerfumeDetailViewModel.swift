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
    
    // MARK: - Status Check

    func isFavorite() -> Bool {
        perfume.userMetadata?.isFavorite ?? false
    }

    func isOwned() -> Bool {
        perfume.userMetadata?.isOwned ?? false
    }

    // MARK: - Toggle

    func toggleFavorite(modelContext: ModelContext, isAuthenticated: Bool) {
        guard throttleToggle() else { return }
        ensureInserted(modelContext: modelContext)

        if let metadata = perfume.userMetadata {
            metadata.isFavorite.toggle()
            metadata.hasPendingSync = true
        } else {
            perfume.userMetadata = UserPersonalData(isFavorite: true, hasPendingSync: true)
        }

        saveAndSync(modelContext: modelContext, isAuthenticated: isAuthenticated)
    }

    func toggleOwned(modelContext: ModelContext, isAuthenticated: Bool) {
        guard throttleToggle() else { return }
        ensureInserted(modelContext: modelContext)

        if let metadata = perfume.userMetadata {
            metadata.isOwned.toggle()
            metadata.hasPendingSync = true
        } else {
            perfume.userMetadata = UserPersonalData(isOwned: true, hasPendingSync: true)
        }

        saveAndSync(modelContext: modelContext, isAuthenticated: isAuthenticated)
    }

    // MARK: - Private Helpers

    private func throttleToggle() -> Bool {
        let now = Date()
        guard now.timeIntervalSince(lastToggleTime) >= 0.5 else { return false }
        lastToggleTime = now
        return true
    }

    private func ensureInserted(modelContext: ModelContext) {
        if perfume.modelContext == nil {
            modelContext.insert(perfume)
        }
    }

    private func saveAndSync(modelContext: ModelContext, isAuthenticated: Bool) {
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
                    isFavorite: meta?.isFavorite ?? false,
                    isOwned: meta?.isOwned ?? false,
                    isEmpty: meta?.isEmpty ?? false
                )
            }
        }
    }

    // MARK: - Supabase Sync

    private func syncStatusToSupabase(perfumeId: UUID, isFavorite: Bool, isOwned: Bool, isEmpty: Bool) async {
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
            let networkError = NetworkError.from(error)
            AppLogger.userPerfumes.error("Fehler beim Sync mit Supabase: \(networkError.localizedDescription)")
            syncErrorMessage = networkError.localizedDescription
            showSyncErrorAlert = true
        }
    }
}
