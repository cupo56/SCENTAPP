//
//  ReviewManagementService.swift
//  scentboxd
//

import Foundation
import SwiftData
import os

@Observable
@MainActor
final class ReviewManagementService {
    // MARK: - State

    var reviews: [Review] = []
    var isLoadingReviews = false
    var isLoadingMoreReviews = false
    var reviewTotalCount: Int?
    var isSavingReview = false
    var averageRating: Double?
    var serverReviewCount: Int?
    var errorMessage: String?
    var showErrorAlert = false
    var syncErrorMessage: String?
    var showSyncErrorAlert = false
    var deleteErrorMessage: String?

    // MARK: - Like State (managed separately from SwiftData)

    var likeCounts: [UUID: Int] = [:]
    var likedByCurrentUser: Set<UUID> = []

    var reviewCount: Int {
        serverReviewCount ?? reviewTotalCount ?? reviews.count
    }

    // MARK: - Pagination

    private let pageSize = AppConfig.Pagination.reviewPageSize
    private var currentPage = 0
    private var hasMoreReviews = true

    // MARK: - Dependencies

    private let perfumeId: UUID
    private let reviewDataSource: any ReviewDataSourceProtocol

    init(perfumeId: UUID, reviewDataSource: any ReviewDataSourceProtocol) {
        self.perfumeId = perfumeId
        self.reviewDataSource = reviewDataSource
    }

    // MARK: - Load Reviews (Paginated)

    func loadReviews() async {
        isLoadingReviews = true
        currentPage = 0
        hasMoreReviews = true

        do {
            reviews = try await reviewDataSource.fetchReviews(for: perfumeId, page: 0, pageSize: pageSize)
            hasMoreReviews = reviews.count >= pageSize
            await loadRatingStats()
            await loadLikeStatus(for: reviews.map(\.id))
        } catch {
            errorMessage = NetworkError.handle(error, logger: AppLogger.reviews, context: "Bewertungen laden")
            showErrorAlert = true
        }
        isLoadingReviews = false
    }

    func loadMoreIfNeeded(currentReview: Review) async {
        let thresholdIndex = max(reviews.count - 3, 0)
        guard let currentIndex = reviews.firstIndex(where: { $0.id == currentReview.id }),
              currentIndex >= thresholdIndex,
              hasMoreReviews,
              !isLoadingReviews,
              !isLoadingMoreReviews else { return }

        isLoadingMoreReviews = true
        defer { isLoadingMoreReviews = false }

        let nextPage = currentPage + 1

        do {
            let moreReviews = try await reviewDataSource.fetchReviews(for: perfumeId, page: nextPage, pageSize: pageSize)
            self.reviews.append(contentsOf: moreReviews)
            self.currentPage = nextPage
            self.hasMoreReviews = moreReviews.count >= pageSize
            await loadLikeStatus(for: moreReviews.map(\.id))
        } catch {
            NetworkError.handle(error, logger: AppLogger.reviews, context: "Bewertungen nachladen")
        }
    }

    // MARK: - Rating Stats

    func loadRatingStats() async {
        do {
            let stats = try await reviewDataSource.fetchRatingStats(for: perfumeId)
            self.averageRating = stats.reviewCount > 0 ? stats.avgRating : nil
            self.serverReviewCount = stats.reviewCount
            self.reviewTotalCount = stats.reviewCount
        } catch {
            AppLogger.reviews.error("Rating-Stats laden fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    // MARK: - CRUD

    func saveReview(_ review: Review, perfume: Perfume, modelContext: ModelContext) async {
        isSavingReview = true
        defer { isSavingReview = false }

        ensureInserted(perfume: perfume, modelContext: modelContext)
        review.perfume = perfume
        if !perfume.reviews.contains(where: { $0.id == review.id }) {
            perfume.reviews.append(review)
        }

        await syncAndPersist(review: review, syncAction: .save, modelContext: modelContext) {
            try await self.reviewDataSource.saveReview(review, for: self.perfumeId)
        }

        if !reviews.contains(where: { $0.id == review.id }) {
            reviews.append(review)
        }
        await loadRatingStats()
    }

    func updateReview(_ review: Review, modelContext: ModelContext) async {
        isSavingReview = true
        defer { isSavingReview = false }

        await syncAndPersist(review: review, syncAction: .update, modelContext: modelContext) {
            try await self.reviewDataSource.updateReview(review, for: self.perfumeId)
        }

        if let index = reviews.firstIndex(where: { $0.id == review.id }) {
            reviews[index] = review
        }
        await loadRatingStats()
    }

    /// Shared sync logic: attempt remote operation, mark pending if failed, persist to SwiftData.
    private func syncAndPersist(
        review: Review,
        syncAction: ReviewSyncAction,
        modelContext: ModelContext,
        remoteOperation: () async throws -> Void
    ) async {
        var remoteSuccess = false
        do {
            try await remoteOperation()
            remoteSuccess = true
        } catch {
            review.hasPendingSync = true
            review.pendingSyncAction = syncAction
            NetworkError.handle(error, logger: AppLogger.reviews, context: "Review-\(syncAction) (wird spaeter synchronisiert)")
        }

        do {
            if remoteSuccess {
                review.hasPendingSync = false
                review.pendingSyncAction = nil
            }
            try modelContext.save()
        } catch {
            if remoteSuccess {
                review.hasPendingSync = true
                review.pendingSyncAction = syncAction
            }
            AppLogger.cache.error("SwiftData-Speichern fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    func deleteReview(_ review: Review, perfume: Perfume, modelContext: ModelContext) async {
        isSavingReview = true
        defer { isSavingReview = false }
        deleteErrorMessage = nil

        // Attempt remote delete FIRST, before mutating local state
        var remoteSuccess = false
        do {
            try await reviewDataSource.deleteReview(id: review.id)
            remoteSuccess = true
        } catch {
            review.hasPendingSync = true
            review.pendingSyncAction = .delete
            let msg = NetworkError.handle(error, logger: AppLogger.reviews, context: "Review-Delete")
            deleteErrorMessage = msg
        }

        // Remove from local state only after remote attempt
        reviews.removeAll { $0.id == review.id }
        perfume.reviews.removeAll { $0.id == review.id }
        if let count = reviewTotalCount {
            reviewTotalCount = max(0, count - 1)
        }

        do {
            try modelContext.save()
        } catch {
            AppLogger.cache.error("SwiftData-Speichern fehlgeschlagen: \(error.localizedDescription)")
        }

        if remoteSuccess {
            await loadRatingStats()
        }
    }

    // MARK: - Likes

    func likeCount(for reviewId: UUID) -> Int {
        likeCounts[reviewId, default: 0]
    }

    func isLiked(_ reviewId: UUID) -> Bool {
        likedByCurrentUser.contains(reviewId)
    }

    /// Loads like counts and current-user like status for the given review IDs.
    func loadLikeStatus(for reviewIds: [UUID]) async {
        guard !reviewIds.isEmpty else { return }
        do {
            let statusMap = try await reviewDataSource.fetchLikeStatus(reviewIds: reviewIds)
            for (id, info) in statusMap {
                likeCounts[id] = info.likeCount
                if info.isLiked {
                    likedByCurrentUser.insert(id)
                } else {
                    likedByCurrentUser.remove(id)
                }
            }
        } catch {
            AppLogger.reviews.error("Like-Status laden fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    /// Optimistic toggle: updates UI immediately, reverts on server error.
    func toggleLike(reviewId: UUID) async {
        let wasLiked = likedByCurrentUser.contains(reviewId)
        let previousCount = likeCounts[reviewId, default: 0]

        // Optimistic update
        if wasLiked {
            likedByCurrentUser.remove(reviewId)
            likeCounts[reviewId] = max(0, previousCount - 1)
        } else {
            likedByCurrentUser.insert(reviewId)
            likeCounts[reviewId] = previousCount + 1
        }

        do {
            let result = try await reviewDataSource.toggleLike(reviewId: reviewId)
            // Reconcile with server truth
            likeCounts[reviewId] = result.likeCount
            if result.liked {
                likedByCurrentUser.insert(reviewId)
            } else {
                likedByCurrentUser.remove(reviewId)
            }
        } catch {
            // Revert optimistic update
            if wasLiked {
                likedByCurrentUser.insert(reviewId)
            } else {
                likedByCurrentUser.remove(reviewId)
            }
            likeCounts[reviewId] = previousCount
            AppLogger.reviews.error("Like-Toggle fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private func ensureInserted(perfume: Perfume, modelContext: ModelContext) {
        if perfume.modelContext == nil {
            modelContext.insert(perfume)
        }
    }

}
