//
//  PerfumeFilterViewModel.swift
//  scentboxd
//

import SwiftUI
import Combine
import os

@Observable
@MainActor
class PerfumeFilterViewModel {
    var activeFilter = PerfumeFilter() {
        didSet { filterSubject.send(activeFilter) }
    }
    var sortOption: PerfumeSortOption = .nameAsc {
        didSet { sortSubject.send(sortOption) }
    }
    var availableBrands: [String] = []
    var availableConcentrations: [String] = []
    var isFilterSheetPresented: Bool = false {
        didSet {
            if isFilterSheetPresented {
                Task {
                    await loadAvailableFilterOptions()
                }
            }
        }
    }

    /// Combine subjects for subscribers that need reactive pipelines (e.g. debounce).
    let filterSubject = PassthroughSubject<PerfumeFilter, Never>()
    let sortSubject = PassthroughSubject<PerfumeSortOption, Never>()

    private let repository: PerfumeRepository
    private var filterOptionsCachedAt: Date?
    private var isLoadingFilterOptions = false

    init(repository: PerfumeRepository) {
        self.repository = repository
    }

    func loadAvailableFilterOptions() async {
        // Skip if already loading (prevent duplicate calls)
        guard !isLoadingFilterOptions else { return }

        // Use cached data if still fresh
        if let cachedAt = filterOptionsCachedAt,
           Date().timeIntervalSince(cachedAt) < AppConfig.Cache.catalogTTL,
           !availableBrands.isEmpty {
            return
        }

        isLoadingFilterOptions = true
        defer { isLoadingFilterOptions = false }

        do {
            async let brands = repository.fetchAvailableBrands()
            async let concentrations = repository.fetchAvailableConcentrations()

            let fetchedBrands = try await brands
            let fetchedConcentrations = try await concentrations

            self.availableBrands = fetchedBrands
            self.availableConcentrations = fetchedConcentrations
            self.filterOptionsCachedAt = Date()
        } catch {
            AppLogger.perfumes.error("Filter-Optionen laden fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    func resetFilters() {
        activeFilter = PerfumeFilter()
        sortOption = .nameAsc
    }
}
