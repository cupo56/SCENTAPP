//
//  SimilarPerfumesService.swift
//  scentboxd
//

import Foundation
import Observation
import os

/// Service zum Laden ähnlicher Düfte basierend auf Noten-Übereinstimmung.
@Observable
@MainActor
final class SimilarPerfumesService {

    // MARK: - State

    var similarPerfumes: [Perfume] = []
    var isLoading = false
    var errorMessage: String?

    // MARK: - Dependencies

    private let repository: PerfumeRepository
    private var loadedPerfumeId: UUID?

    // MARK: - Init

    init(repository: PerfumeRepository) {
        self.repository = repository
    }

    // MARK: - Load

    func loadSimilarPerfumes(for perfumeId: UUID) async {
        guard loadedPerfumeId != perfumeId else { return }

        isLoading = true
        errorMessage = nil
        similarPerfumes = []
        defer { isLoading = false }

        do {
            self.similarPerfumes = try await repository.fetchSimilarPerfumes(for: perfumeId, limit: 6)
            loadedPerfumeId = perfumeId
        } catch {
            AppLogger.perfumes.error("Ähnliche Düfte laden fehlgeschlagen: \(error.localizedDescription)")
            self.errorMessage = NetworkError.handle(error, logger: AppLogger.perfumes, context: "Ähnliche Düfte laden")
        }
    }
}
