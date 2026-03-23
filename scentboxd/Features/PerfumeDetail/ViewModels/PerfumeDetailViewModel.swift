//
//  PerfumeDetailViewModel.swift
//  scentboxd
//
//  Created by Cupo on 09.02.26.
//

import Foundation
import SwiftData
import Observation
import os

@Observable
@MainActor
class PerfumeDetailViewModel {
    // MARK: - State

    var showReviewSheet = false
    var showLoginAlert = false
    var editingReview: Review?
    var currentUserId: UUID?

    // MARK: - Services

    let reviewService: ReviewManagementService
    let statusService: PerfumeStatusService
    let similarService: SimilarPerfumesService
    let perfume: Perfume

    // MARK: - Init

    init(
        perfume: Perfume,
        reviewService: ReviewManagementService,
        statusService: PerfumeStatusService,
        similarService: SimilarPerfumesService
    ) {
        self.perfume = perfume
        self.reviewService = reviewService
        self.statusService = statusService
        self.similarService = similarService
    }

    // MARK: - Computed (forwarded)

    var hasExistingReview: Bool {
        guard let userId = currentUserId else { return false }
        return reviewService.reviews.contains { $0.userId == userId }
    }

    // MARK: - Auth

    func loadCurrentUserId() async {
        do {
            currentUserId = try await AuthSessionCache.shared.getUserId()
        } catch {
            currentUserId = nil
        }
    }

    // MARK: - Review Actions

    func handleReviewButtonTapped() async {
        if let existing = reviewService.reviews.first(where: { $0.userId == currentUserId }) {
            editingReview = existing
            showReviewSheet = true
        } else {
            editingReview = nil
            showReviewSheet = true
        }
    }

    func saveReview(_ review: Review, modelContext: ModelContext) async {
        await reviewService.saveReview(review, perfume: perfume, modelContext: modelContext)
    }

    func updateReview(_ review: Review, modelContext: ModelContext) async {
        await reviewService.updateReview(review, modelContext: modelContext)
    }

    func deleteReview(_ review: Review, modelContext: ModelContext) async {
        await reviewService.deleteReview(review, perfume: perfume, modelContext: modelContext)
    }

    // MARK: - Status

    func toggleFavorite(modelContext: ModelContext, isAuthenticated: Bool) {
        statusService.toggleFavorite(perfume: perfume, modelContext: modelContext, isAuthenticated: isAuthenticated)
    }

    func toggleOwned(modelContext: ModelContext, isAuthenticated: Bool) {
        statusService.toggleOwned(perfume: perfume, modelContext: modelContext, isAuthenticated: isAuthenticated)
    }
}
