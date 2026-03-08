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
    var reviewTotalCount: Int? = nil
    var isSavingReview = false
    var averageRating: Double? = nil
    var serverReviewCount: Int? = nil
    var errorMessage: String? = nil
    var showErrorAlert = false

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
        } catch {
            errorMessage = NetworkError.handle(error, logger: AppLogger.reviews, context: "Bewertungen laden")
            showErrorAlert = true
        }
        isLoadingReviews = false
    }

    func loadMoreIfNeeded(currentReview: Review) async {
        guard let lastReview = reviews.last,
              lastReview.id == currentReview.id,
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

        var remoteSuccess = false
        do {
            try await reviewDataSource.saveReview(review, for: perfumeId)
            remoteSuccess = true
        } catch {
            review.hasPendingSync = true
            review.pendingSyncAction = .save
            NetworkError.handle(error, logger: AppLogger.reviews, context: "Review-Save (wird spaeter synchronisiert)")
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
                review.pendingSyncAction = .save
            }
            AppLogger.cache.error("SwiftData-Speichern fehlgeschlagen: \(error.localizedDescription)")
        }

        if !reviews.contains(where: { $0.id == review.id }) {
            reviews.append(review)
        }
        await loadRatingStats()
    }

    func updateReview(_ review: Review, modelContext: ModelContext) async {
        isSavingReview = true
        defer { isSavingReview = false }

        var remoteSuccess = false
        do {
            try await reviewDataSource.updateReview(review, for: perfumeId)
            remoteSuccess = true
        } catch {
            review.hasPendingSync = true
            review.pendingSyncAction = .update
            NetworkError.handle(error, logger: AppLogger.reviews, context: "Review-Update (wird spaeter synchronisiert)")
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
                review.pendingSyncAction = .update
            }
            AppLogger.cache.error("SwiftData-Speichern fehlgeschlagen: \(error.localizedDescription)")
        }

        await loadReviews()
    }

    func deleteReview(_ review: Review, perfume: Perfume, modelContext: ModelContext) async {
        isSavingReview = true
        defer { isSavingReview = false }

        do {
            try await reviewDataSource.deleteReview(id: review.id)
            reviews.removeAll { $0.id == review.id }
            perfume.reviews.removeAll { $0.id == review.id }
            if let count = reviewTotalCount {
                reviewTotalCount = max(0, count - 1)
            }
        } catch {
            review.hasPendingSync = true
            review.pendingSyncAction = .delete
            reviews.removeAll { $0.id == review.id }
            if let count = reviewTotalCount {
                reviewTotalCount = max(0, count - 1)
            }
            NetworkError.handle(error, logger: AppLogger.reviews, context: "Review-Delete (wird spaeter synchronisiert)")
        }

        do {
            try modelContext.save()
        } catch {
            AppLogger.cache.error("SwiftData-Speichern fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private func ensureInserted(perfume: Perfume, modelContext: ModelContext) {
        if perfume.modelContext == nil {
            modelContext.insert(perfume)
        }
    }
}
