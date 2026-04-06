//
//  PerfumeDataLoader.swift
//  scentboxd
//

import Foundation
import SwiftData
import os

@Observable
@MainActor
final class PerfumeDataLoader {
    // MARK: - State

    var perfumes: [Perfume] = []
    var isLoading = false
    var isLoadingMore = false
    var errorMessage: String?
    var isOffline = false
    var lastSyncedAt: Date?
    var totalCount: Int?
    var ratingStatsMap: [UUID: RatingStats] = [:]

    // MARK: - Pagination

    private let pageSize = AppConfig.Pagination.perfumePageSize
    private var currentPage = 0
    private var hasMorePages = true

    // MARK: - Dependencies

    private let repository: PerfumeRepository
    private let reviewDataSource: any ReviewDataSourceProtocol
    private let cacheService: PerfumeCacheService
    private let networkMonitor: NetworkMonitor
    private let searchCache = PerfumeSearchCache()

    init(
        repository: PerfumeRepository,
        reviewDataSource: any ReviewDataSourceProtocol,
        cacheService: PerfumeCacheService,
        networkMonitor: NetworkMonitor
    ) {
        self.repository = repository
        self.reviewDataSource = reviewDataSource
        self.cacheService = cacheService
        self.networkMonitor = networkMonitor
    }

    // MARK: - Initial Load (Cache-First)

    func loadData(
        searchText: String,
        filter: PerfumeFilter,
        sort: PerfumeSortOption,
        cacheKey: String,
        modelContext: ModelContext?,
        forceRefresh: Bool = false
    ) async {
        isLoading = true
        defer { isLoading = false }

        currentPage = 0
        hasMorePages = true
        isOffline = !networkMonitor.isConnected
        lastSyncedAt = cacheService.lastSyncedAt

        // In-Memory-Cache prüfen
        if !forceRefresh, !cacheService.needsRefresh, let cached = searchCache.results(for: cacheKey) {
            self.perfumes = cached
            self.hasMorePages = cached.count >= pageSize
            self.errorMessage = nil
            return
        }

        // SwiftData-Cache laden
        var cacheLoaded = false
        if let ctx = modelContext {
            if let cached = fetchFromCache(searchText: searchText, page: 0, filter: filter, sort: sort, modelContext: ctx),
               !cached.isEmpty {
                self.perfumes = cached
                self.hasMorePages = cached.count >= pageSize
                cacheLoaded = true
            }
        }

        guard networkMonitor.isConnected else {
            if !cacheLoaded {
                self.perfumes = []
                self.errorMessage = searchText.isEmpty
                    ? "Keine Internetverbindung und kein lokaler Cache vorhanden."
                    : "Keine Internetverbindung. Offline-Suche ergab keine Treffer."
            }
            return
        }

        // Nur aus dem Cache zurückgeben, wenn kein Filter/Suche aktiv ist.
        // Der lokale Cache enthält nur die erste Seite ungefilteter Daten und ist
        // als vollständige Quelle für gefilterte Abfragen ungeeignet.
        if cacheLoaded && !forceRefresh && !cacheService.needsRefresh && filter.isEmpty && searchText.isEmpty {
            self.errorMessage = nil
            return
        }

        // Von Supabase laden — totalCount parallel zur Hauptabfrage
        do {
            async let countTask: Int? = {
                try? await self.repository.fetchTotalCount(searchQuery: searchText.isEmpty ? nil : searchText, filter: filter)
            }()

            let results = try await fetchFromRemote(searchText: searchText, page: 0, filter: filter, sort: sort)

            // Rating Stats parallel starten (braucht nur IDs aus results)
            async let statsTask = fetchRatingStats(for: results)

            if let count = await countTask {
                self.totalCount = count
            }

            searchCache.store(results, for: cacheKey)

            self.perfumes = cacheAndResolveManagedResults(
                results,
                searchText: searchText,
                page: 0,
                filter: filter,
                sort: sort,
                modelContext: modelContext,
                updateLastSynced: true
            )

            self.hasMorePages = results.count >= pageSize
            self.errorMessage = nil
            self.isOffline = false

            if let stats = await statsTask {
                for (key, value) in stats {
                    self.ratingStatsMap[key] = value
                }
            }
        } catch {
            let message = NetworkError.handle(error, logger: AppLogger.perfumes, context: "Parfums laden")
            if !cacheLoaded {
                self.errorMessage = message
            }
        }
    }

    // MARK: - Infinite Scrolling

    func loadMoreIfNeeded(
        currentItem: Perfume,
        searchText: String,
        filter: PerfumeFilter,
        sort: PerfumeSortOption,
        modelContext: ModelContext?
    ) async {
        let thresholdIndex = max(perfumes.count - 5, 0)
        guard let currentIndex = perfumes.firstIndex(where: { $0.id == currentItem.id }),
              currentIndex >= thresholdIndex,
              hasMorePages,
              !isLoading,
              !isLoadingMore else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        let previousPage = currentPage
        currentPage += 1

        // Offline → aus Cache nachladen
        if !networkMonitor.isConnected {
            if let ctx = modelContext,
               let cached = fetchFromCache(searchText: searchText, page: currentPage, filter: filter, sort: sort, modelContext: ctx) {
                self.perfumes.append(contentsOf: cached)
                self.hasMorePages = cached.count >= pageSize
            } else {
                currentPage = previousPage
            }
            return
        }

        // Online → von Supabase nachladen
        do {
            let results = try await fetchFromRemote(searchText: searchText, page: currentPage, filter: filter, sort: sort)

            let managed = cacheAndResolveManagedResults(
                results,
                searchText: searchText,
                page: currentPage,
                filter: filter,
                sort: sort,
                modelContext: modelContext
            )
            self.perfumes.append(contentsOf: managed)
            self.hasMorePages = results.count >= pageSize
        } catch {
            currentPage = previousPage
            self.errorMessage = NetworkError.handle(error, logger: AppLogger.perfumes, context: "Parfums nachladen")
        }
    }

    // MARK: - Shared Fetch Helpers

    /// Loads perfumes from SwiftData cache, branching on search vs browse.
    private func fetchFromCache(
        searchText: String,
        page: Int,
        filter: PerfumeFilter,
        sort: PerfumeSortOption,
        modelContext: ModelContext
    ) -> [Perfume]? {
        do {
            if searchText.isEmpty {
                return try cacheService.loadCachedPerfumes(modelContext: modelContext, page: page, pageSize: pageSize, filter: filter, sort: sort)
            } else {
                return try cacheService.searchCachedPerfumes(modelContext: modelContext, query: searchText, page: page, pageSize: pageSize, filter: filter, sort: sort)
            }
        } catch {
            AppLogger.cache.error("Cache-Laden fehlgeschlagen: \(error.localizedDescription)")
            return nil
        }
    }

    /// Fetches perfumes from repository with retry, branching on search vs browse.
    private func fetchFromRemote(
        searchText: String,
        page: Int,
        filter: PerfumeFilter,
        sort: PerfumeSortOption
    ) async throws -> [Perfume] {
        try await withRetry {
            if searchText.isEmpty {
                return try await self.repository.fetchPerfumes(page: page, pageSize: self.pageSize, filter: filter, sort: sort)
            } else {
                return try await self.repository.searchPerfumes(query: searchText, page: page, pageSize: self.pageSize, filter: filter, sort: sort)
            }
        }
    }

    /// Persists results to SwiftData cache (if applicable) and returns managed objects.
    private func cacheAndResolveManagedResults(
        _ results: [Perfume],
        searchText: String,
        page: Int,
        filter: PerfumeFilter,
        sort: PerfumeSortOption,
        modelContext: ModelContext?,
        updateLastSynced: Bool = false
    ) -> [Perfume] {
        guard let ctx = modelContext, searchText.isEmpty && filter.isEmpty else {
            return results
        }
        do {
            try cacheService.cachePerfumes(results, modelContext: ctx)
            if updateLastSynced { lastSyncedAt = cacheService.lastSyncedAt }
            return try cacheService.loadCachedPerfumes(modelContext: ctx, page: page, pageSize: pageSize, filter: filter, sort: sort)
        } catch {
            AppLogger.cache.error("Cache-Speichern fehlgeschlagen: \(error.localizedDescription)")
            return results
        }
    }

    // MARK: - Rating Stats

    func loadRatingStats(for perfumes: [Perfume]) async {
        if let stats = await fetchRatingStats(for: perfumes) {
            for (key, value) in stats {
                self.ratingStatsMap[key] = value
            }
        }
    }

    private func fetchRatingStats(for perfumes: [Perfume]) async -> [UUID: RatingStats]? {
        guard networkMonitor.isConnected, !perfumes.isEmpty else { return nil }
        let ids = perfumes.map(\.id)
        do {
            return try await reviewDataSource.fetchRatingStatsForPerfumes(ids)
        } catch {
            AppLogger.perfumes.error("Rating-Stats laden fehlgeschlagen: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Refresh

    func clearSearchCache() {
        searchCache.removeAll()
    }
}
