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

    init(repository: PerfumeRepository) {
        self.repository = repository
    }

    func loadAvailableFilterOptions() async {
        do {
            async let brands = repository.fetchAvailableBrands()
            async let concentrations = repository.fetchAvailableConcentrations()

            self.availableBrands = try await brands
            self.availableConcentrations = try await concentrations
        } catch {
            AppLogger.perfumes.error("Filter-Optionen laden fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    func resetFilters() {
        activeFilter = PerfumeFilter()
        sortOption = .nameAsc
    }
}
