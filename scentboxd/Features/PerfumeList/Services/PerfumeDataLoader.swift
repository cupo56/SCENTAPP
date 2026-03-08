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
    var errorMessage: String? = nil
    var isOffline = false
    var lastSyncedAt: Date? = nil
    var totalCount: Int? = nil
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
        if !forceRefresh, let cached = searchCache.results(for: cacheKey) {
            self.perfumes = cached
            self.hasMorePages = cached.count >= pageSize
            self.errorMessage = nil
            return
        }

        // SwiftData-Cache laden
        var cacheLoaded = false
        if let ctx = modelContext {
            do {
                let cached: [Perfume]
                if searchText.isEmpty {
                    cached = try cacheService.loadCachedPerfumes(modelContext: ctx, page: 0, pageSize: pageSize, filter: filter, sort: sort)
                } else {
                    cached = try cacheService.searchCachedPerfumes(modelContext: ctx, query: searchText, page: 0, pageSize: pageSize, filter: filter, sort: sort)
                }
                if !cached.isEmpty {
                    self.perfumes = cached
                    self.hasMorePages = cached.count >= pageSize
                    cacheLoaded = true
                }
            } catch {
                AppLogger.cache.error("Cache-Laden fehlgeschlagen: \(error.localizedDescription)")
            }
        }

        guard networkMonitor.isConnected else {
            if perfumes.isEmpty {
                self.errorMessage = "Keine Internetverbindung und kein lokaler Cache vorhanden."
            }
            return
        }

        if cacheLoaded && !forceRefresh && !cacheService.needsRefresh {
            self.errorMessage = nil
            return
        }

        // Von Supabase laden
        do {
            let results: [Perfume] = try await withRetry {
                if searchText.isEmpty {
                    return try await self.repository.fetchPerfumes(page: 0, pageSize: self.pageSize, filter: filter, sort: sort)
                } else {
                    return try await self.repository.searchPerfumes(query: searchText, page: 0, pageSize: self.pageSize, filter: filter, sort: sort)
                }
            }

            searchCache.store(results, for: cacheKey)

            if let ctx = modelContext, searchText.isEmpty && filter.isEmpty {
                do {
                    try cacheService.cachePerfumes(results, modelContext: ctx)
                    lastSyncedAt = cacheService.lastSyncedAt
                    let managed = try cacheService.loadCachedPerfumes(modelContext: ctx, page: 0, pageSize: pageSize, filter: filter, sort: sort)
                    self.perfumes = managed
                } catch {
                    AppLogger.cache.error("Cache-Speichern fehlgeschlagen: \(error.localizedDescription)")
                    self.perfumes = results
                }
            } else {
                self.perfumes = results
            }

            self.hasMorePages = results.count >= pageSize
            self.errorMessage = nil
            self.isOffline = false

            Task {
                if let count = try? await self.repository.fetchTotalCount(searchQuery: searchText.isEmpty ? nil : searchText, filter: filter) {
                    self.totalCount = count
                }
            }
            Task {
                await self.loadRatingStats(for: results)
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
        guard let lastItem = perfumes.last,
              lastItem.id == currentItem.id,
              hasMorePages,
              !isLoading,
              !isLoadingMore else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        let nextPage = currentPage + 1

        // Offline → aus Cache nachladen
        if !networkMonitor.isConnected {
            if let ctx = modelContext {
                do {
                    let cached: [Perfume]
                    if searchText.isEmpty {
                        cached = try cacheService.loadCachedPerfumes(modelContext: ctx, page: nextPage, pageSize: pageSize, filter: filter, sort: sort)
                    } else {
                        cached = try cacheService.searchCachedPerfumes(modelContext: ctx, query: searchText, page: nextPage, pageSize: pageSize, filter: filter, sort: sort)
                    }
                    self.perfumes.append(contentsOf: cached)
                    self.currentPage = nextPage
                    self.hasMorePages = cached.count >= pageSize
                } catch {
                    AppLogger.cache.error("Cache-Nachladen fehlgeschlagen: \(error.localizedDescription)")
                }
            }
            return
        }

        // Online → von Supabase nachladen
        do {
            let results: [Perfume] = try await withRetry {
                if searchText.isEmpty {
                    return try await self.repository.fetchPerfumes(page: nextPage, pageSize: self.pageSize, filter: filter, sort: sort)
                } else {
                    return try await self.repository.searchPerfumes(query: searchText, page: nextPage, pageSize: self.pageSize, filter: filter, sort: sort)
                }
            }

            if let ctx = modelContext, searchText.isEmpty && filter.isEmpty {
                do {
                    try cacheService.cachePerfumes(results, modelContext: ctx)
                    let managed = try cacheService.loadCachedPerfumes(modelContext: ctx, page: nextPage, pageSize: pageSize, filter: filter, sort: sort)
                    self.perfumes.append(contentsOf: managed)
                } catch {
                    AppLogger.cache.error("Cache-Speichern fehlgeschlagen (loadMore): \(error.localizedDescription)")
                    self.perfumes.append(contentsOf: results)
                }
            } else {
                self.perfumes.append(contentsOf: results)
            }

            self.currentPage = nextPage
            self.hasMorePages = results.count >= pageSize
        } catch {
            self.errorMessage = NetworkError.handle(error, logger: AppLogger.perfumes, context: "Parfums nachladen")
        }
    }

    // MARK: - Rating Stats

    func loadRatingStats(for perfumes: [Perfume]) async {
        guard networkMonitor.isConnected, !perfumes.isEmpty else { return }
        let ids = perfumes.map(\.id)
        do {
            let stats = try await reviewDataSource.fetchRatingStatsForPerfumes(ids)
            for (key, value) in stats {
                self.ratingStatsMap[key] = value
            }
        } catch {
            AppLogger.perfumes.error("Rating-Stats laden fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    // MARK: - Refresh

    func clearSearchCache() {
        searchCache.removeAll()
    }
}
