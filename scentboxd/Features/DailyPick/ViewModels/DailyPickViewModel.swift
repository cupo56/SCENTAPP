//
//  DailyPickViewModel.swift
//  scentboxd
//
//  ViewModel für die "Was trage ich heute?" Ansicht.
//  Orchestriert WeatherService + DailyPickService.
//

import Foundation
import SwiftData
import os

@Observable @MainActor
final class DailyPickViewModel {

    // MARK: - Public State

    var topPick: RecommendedPerfume?
    var alternatives: [RecommendedPerfume] = []
    var selectedOccasion: Occasion = .casual
    var isLoading = false
    var isEmpty = false
    var errorMessage: String?

    // MARK: - Dependencies

    let weatherService: WeatherService
    private let dailyPickService: DailyPickService
    private let logger = Logger(subsystem: "scentboxd", category: "DailyPick")

    init(weatherService: WeatherService, dailyPickService: DailyPickService? = nil) {
        self.weatherService = weatherService
        self.dailyPickService = dailyPickService ?? DailyPickService()

        // Auto-detect passenden Anlass basierend auf Tageszeit
        let timeOfDay = TimeOfDay.current
        switch timeOfDay {
        case .morning:   selectedOccasion = .work
        case .afternoon: selectedOccasion = .casual
        case .evening:   selectedOccasion = .evening
        case .night:     selectedOccasion = .casual
        }
    }

    // MARK: - Public API

    /// Lädt Wetter und berechnet die tägliche Empfehlung.
    func loadDailyPick(modelContext: ModelContext) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        // 1. Wetter laden (falls noch nicht vorhanden)
        if weatherService.currentCondition == nil {
            await weatherService.fetchCurrentWeather()
        }

        // 2. Owned Parfums aus SwiftData holen
        let ownedPerfumes = fetchOwnedPerfumes(modelContext: modelContext)

        guard !ownedPerfumes.isEmpty else {
            isEmpty = true
            isLoading = false
            return
        }

        isEmpty = false

        // 3. Kriterien aufbauen
        let criteria = DailyPickCriteria(
            temperature: weatherService.currentTemperature,
            humidity: weatherService.humidity,
            occasion: selectedOccasion,
            timeOfDay: TimeOfDay.current,
            season: Season.current
        )

        // 4. Empfehlungen berechnen
        let recommendations = dailyPickService.calculateRecommendations(
            ownedPerfumes: ownedPerfumes,
            criteria: criteria,
            maxResults: 4
        )

        if let first = recommendations.first {
            topPick = first
            alternatives = Array(recommendations.dropFirst())
        } else {
            topPick = nil
            alternatives = []
        }

        logger.info("Daily Pick berechnet: \(recommendations.count) Empfehlungen für \(self.selectedOccasion.rawValue)")
        isLoading = false
    }

    /// Neuen Vorschlag generieren (mit neuem Zufalls-Bonus).
    func refreshPick(modelContext: ModelContext) async {
        topPick = nil
        alternatives = []
        await loadDailyPick(modelContext: modelContext)
    }

    /// Occasion wechseln → Empfehlungen neu berechnen.
    func selectOccasion(_ occasion: Occasion, modelContext: ModelContext) async {
        selectedOccasion = occasion
        await loadDailyPick(modelContext: modelContext)
    }

    // MARK: - Private Helpers

    private func fetchOwnedPerfumes(modelContext: ModelContext) -> [Perfume] {
        let descriptor = FetchDescriptor<Perfume>(
            predicate: #Predicate<Perfume> { perfume in
                perfume.userMetadata?.isOwned == true
            },
            sortBy: [SortDescriptor(\Perfume.name)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            logger.error("Owned Parfums konnten nicht geladen werden: \(error.localizedDescription)")
            return []
        }
    }
}
