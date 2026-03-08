//
//  ReviewSyncService.swift
//  scentboxd
//

import Foundation
import SwiftData
import os

@MainActor
class ReviewSyncService {
    private let reviewDataSource: any ReviewDataSourceProtocol

    init(reviewDataSource: any ReviewDataSourceProtocol) {
        self.reviewDataSource = reviewDataSource
    }

    /// Laedt alle lokal ausstehenden Review-Aenderungen zu Supabase hoch.
    func uploadPendingReviews(modelContext: ModelContext) async {
        let descriptor = FetchDescriptor<Review>(
            predicate: #Predicate<Review> { $0.hasPendingSync == true }
        )

        let pendingReviews: [Review]
        do {
            pendingReviews = try modelContext.fetch(descriptor)
        } catch {
            AppLogger.sync.error("Pending Reviews laden fehlgeschlagen: \(error.localizedDescription)")
            return
        }

        guard !pendingReviews.isEmpty else { return }

        AppLogger.sync.info("Lade \(pendingReviews.count) ausstehende Review(s) hoch…")

        for review in pendingReviews {
            guard let perfumeId = review.perfume?.id else {
                AppLogger.sync.error("Review \(review.id) hat kein Parfum — ueberspringe")
                continue
            }

            do {
                guard let action = review.pendingSyncAction else { continue }

                switch action {
                case .save:
                    try await reviewDataSource.saveReview(review, for: perfumeId)
                case .update:
                    try await reviewDataSource.updateReview(review, for: perfumeId)
                case .delete:
                    try await reviewDataSource.deleteReview(id: review.id)
                    // Nach erfolgreichem Remote-Delete auch lokal entfernen
                    modelContext.delete(review)
                }

                // Upload erfolgreich
                if action != .delete {
                    review.hasPendingSync = false
                    review.pendingSyncAction = nil
                }
            } catch {
                AppLogger.sync.error("Review-Sync fehlgeschlagen fuer \(review.id): \(error.localizedDescription)")
                // Nicht fatal — beim naechsten Sync erneut versuchen
            }
        }

        do {
            try modelContext.save()
        } catch {
            AppLogger.cache.error("SwiftData-Speichern fehlgeschlagen (uploadPendingReviews): \(error.localizedDescription)")
        }
    }
}
