//
//  RecommendationsViewModel.swift
//  scentboxd
//

import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class RecommendationsViewModel {

    // MARK: - State

    var recommendations: [RecommendationEngine.RecommendedPerfume] = []
    var isLoading = false
    var errorMessage: String?

    /// IDs von Düften, die der Nutzer als "Nicht interessiert" markiert hat.
    /// Wird per `UserDefaults` zwischen Sessions gespeichert.
    private(set) var dislikedIds: Set<UUID> = []

    // MARK: - Dependencies

    private let engine = RecommendationEngine()
    private let repository: PerfumeRepository
    private let defaultsKey = "recommendations.dislikedIds"

    // MARK: - Init

    init(repository: PerfumeRepository) {
        self.repository = repository
        loadDislikedIds()
    }

    // MARK: - Load

    /// Berechnet Empfehlungen basierend auf owned + favorisierten Parfums.
    /// Die Katalog-Grundlage wird aus dem lokalen Cache bezogen (offline-fähig).
    func loadRecommendations(
        ownedPerfumes: [Perfume],
        favoritePerfumes: [Perfume],
        allCachedPerfumes: [Perfume]
    ) async {
        guard !ownedPerfumes.isEmpty || !favoritePerfumes.isEmpty else {
            recommendations = []
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var catalog = allCachedPerfumes

        // Falls Cache zu klein: Remote-Fallback (erste Seite 100 Parfums)
        if catalog.count < 30 {
            do {
                catalog = try await repository.fetchPerfumes(
                    page: 0,
                    pageSize: 100,
                    filter: PerfumeFilter(),
                    sort: .popular
                )
            } catch {
                if catalog.isEmpty {
                    errorMessage = NetworkError.handle(
                        error,
                        logger: AppLogger.perfumes,
                        context: "Empfehlungen laden"
                    )
                    return
                }
                // Cache reicht aus, Fehler ignorieren
            }
        }

        let computed = await engine.calculateRecommendations(
            ownedPerfumes: ownedPerfumes,
            favoritePerfumes: favoritePerfumes,
            allPerfumes: catalog
        )

        recommendations = computed.filter { !dislikedIds.contains($0.perfume.id) }
    }

    // MARK: - User Actions

    /// Markiert ein Parfum als "Nicht interessiert" und entfernt es aus der Liste.
    func markAsNotInterested(_ perfume: Perfume) {
        dislikedIds.insert(perfume.id)
        recommendations.removeAll { $0.perfume.id == perfume.id }
        saveDislikedIds()
    }

    // MARK: - Persistence

    private func loadDislikedIds() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let ids = try? JSONDecoder().decode([UUID].self, from: data) else { return }
        dislikedIds = Set(ids)
    }

    private func saveDislikedIds() {
        guard let data = try? JSONEncoder().encode(Array(dislikedIds)) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
