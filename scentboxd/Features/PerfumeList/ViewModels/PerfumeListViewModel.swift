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
        didSet {
            searchSuggestionService.fetchSuggestions(for: searchText)
            searchTextSubject.send(searchText)
        }
    }

    let dataLoader: PerfumeDataLoader
    let filterVM: PerfumeFilterViewModel
    let searchSuggestionService: SearchSuggestionService

    var modelContext: ModelContext?

    private let networkMonitor: NetworkMonitor
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private let searchTextSubject = PassthroughSubject<String, Never>()

    init(
        dataLoader: PerfumeDataLoader,
        networkMonitor: NetworkMonitor,
        filterVM: PerfumeFilterViewModel,
        searchSuggestionService: SearchSuggestionService
    ) {
        self.dataLoader = dataLoader
        self.networkMonitor = networkMonitor
        self.filterVM = filterVM
        self.searchSuggestionService = searchSuggestionService

        setupBindings()
    }

    // MARK: - Reactive Bindings

    private func setupBindings() {
        // Merge all reload triggers into a single stream, debounce ONCE,
        // then trigger a single reload. Prevents task-cancellation-thrashing
        // when multiple inputs change near-simultaneously.
        let searchTrigger = searchTextSubject
            .removeDuplicates()
            .map { _ in () }

        let filterTrigger = filterVM.filterSubject
            .removeDuplicates()
            .map { _ in () }

        let sortTrigger = filterVM.sortSubject
            .removeDuplicates()
            .map { _ in () }

        Publishers.Merge3(searchTrigger, filterTrigger, sortTrigger)
            .debounce(for: .milliseconds(AppConfig.Timing.searchDebounceMs), scheduler: RunLoop.main)
            .sink { [weak self] in self?.triggerReload() }
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

    func clearSuggestions() {
        searchSuggestionService.clear()
    }
}
