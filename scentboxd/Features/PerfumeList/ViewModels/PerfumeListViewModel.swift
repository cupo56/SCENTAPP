//
//  PerfumeListViewModel.swift
//  scentboxd
//
//  Created by Cupo on 09.01.26.
//

import SwiftUI
import SwiftData
import Combine
import os

@Observable
@MainActor
class PerfumeListViewModel {
    var searchText: String = "" {
        didSet { searchTextSubject.send(searchText) }
    }

    let dataLoader: PerfumeDataLoader
    let filterVM: PerfumeFilterViewModel

    var modelContext: ModelContext?

    private let networkMonitor: NetworkMonitor
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private let searchTextSubject = PassthroughSubject<String, Never>()

    init(
        dataLoader: PerfumeDataLoader,
        networkMonitor: NetworkMonitor,
        filterVM: PerfumeFilterViewModel
    ) {
        self.dataLoader = dataLoader
        self.networkMonitor = networkMonitor
        self.filterVM = filterVM

        setupBindings()
    }

    // MARK: - Reactive Bindings

    private func setupBindings() {
        searchTextSubject
            .debounce(for: .milliseconds(AppConfig.Timing.searchDebounceMs), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in self?.triggerReload() }
            .store(in: &cancellables)

        filterVM.filterSubject
            .debounce(for: .milliseconds(AppConfig.Timing.filterDebounceMs), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in self?.triggerReload() }
            .store(in: &cancellables)

        filterVM.sortSubject
            .removeDuplicates()
            .sink { [weak self] _ in self?.triggerReload() }
            .store(in: &cancellables)

        networkMonitor.connectionSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] isConnected in
                self?.dataLoader.isOffline = !isConnected
            }
            .store(in: &cancellables)
    }

    private func triggerReload() {
        searchTask?.cancel()
        searchTask = Task { await loadData() }
    }

    // MARK: - Cache Key

    private var currentCacheKey: String {
        "\(searchText)|\(filterVM.activeFilter.cacheKeyComponent)|\(filterVM.sortOption.rawValue)"
    }

    // MARK: - Public API

    func loadData(forceRefresh: Bool = false) async {
        await dataLoader.loadData(
            searchText: searchText,
            filter: filterVM.activeFilter,
            sort: filterVM.sortOption,
            cacheKey: currentCacheKey,
            modelContext: modelContext,
            forceRefresh: forceRefresh
        )
    }

    func loadMoreIfNeeded(currentItem: Perfume) async {
        await dataLoader.loadMoreIfNeeded(
            currentItem: currentItem,
            searchText: searchText,
            filter: filterVM.activeFilter,
            sort: filterVM.sortOption,
            modelContext: modelContext
        )
    }

    func refresh() async {
        guard networkMonitor.isConnected else {
            dataLoader.isOffline = true
            return
        }
        dataLoader.clearSearchCache()
        await loadData(forceRefresh: true)
    }
}
