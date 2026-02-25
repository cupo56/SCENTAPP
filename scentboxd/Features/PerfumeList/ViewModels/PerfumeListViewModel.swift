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

@MainActor
class PerfumeListViewModel: ObservableObject {
    @Published var perfumes: [Perfume] = []
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var errorMessage: String? = nil
    @Published var isOffline: Bool = false
    @Published var lastSyncedAt: Date? = nil
    @Published var totalCount: Int? = nil
    
    // MARK: - Filter & Sort State
    @Published var activeFilter = PerfumeFilter()
    @Published var sortOption: PerfumeSortOption = .nameAsc
    @Published var availableBrands: [String] = []
    @Published var availableConcentrations: [String] = []
    @Published var isFilterSheetPresented: Bool = false
    
    // MARK: - Rating Stats (Server-Side Aggregation)
    @Published var ratingStatsMap: [UUID: ReviewRemoteDataSource.RatingStats] = [:]
    
    private let repository: PerfumeRepository
    private let reviewDataSource = ReviewRemoteDataSource()
    private let cacheService = PerfumeCacheService()
    private let networkMonitor = NetworkMonitor.shared
    private let pageSize = 20
    private var currentPage = 0
    private var hasMorePages = true
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - In-Memory Search Cache
    private var searchCache: [String: (results: [Perfume], timestamp: Date)] = [:]
    private let searchCacheTTL: TimeInterval = 120 // 2 Minuten
    
    var modelContext: ModelContext?
    
    init(repository: PerfumeRepository? = nil) {
        self.repository = repository ?? PerfumeRemoteDataSource()
        
        // Textsuche mit Debounce
        $searchText
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                guard let self else { return }
                self.searchTask?.cancel()
                self.searchTask = Task { await self.loadData() }
            }
            .store(in: &cancellables)
        
        // Filter-Änderungen lösen Neu-Laden aus
        $activeFilter
            .dropFirst()
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                guard let self else { return }
                self.searchTask?.cancel()
                self.searchTask = Task { await self.loadData() }
            }
            .store(in: &cancellables)
        
        // Sort-Änderungen lösen Neu-Laden aus
        $sortOption
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                guard let self else { return }
                self.searchTask?.cancel()
                self.searchTask = Task { await self.loadData() }
            }
            .store(in: &cancellables)
        
        networkMonitor.$isConnected
            .receive(on: RunLoop.main)
            .sink { [weak self] isConnected in
                self?.isOffline = !isConnected
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Cache Key
    
    private var currentCacheKey: String {
        "\(searchText)|\(activeFilter.cacheKeyComponent)|\(sortOption.rawValue)"
    }
    
    /// Prüft ob ein gültiger Cache-Eintrag existiert
    private func cachedResults(for key: String) -> [Perfume]? {
        guard let entry = searchCache[key] else { return nil }
        guard Date().timeIntervalSince(entry.timestamp) < searchCacheTTL else {
            searchCache.removeValue(forKey: key)
            return nil
        }
        return entry.results
    }
    
    // MARK: - Filter-Picker-Optionen laden
    
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
    
    // MARK: - Filter zurücksetzen
    
    func resetFilters() {
        activeFilter = PerfumeFilter()
        sortOption = .nameAsc
        searchCache.removeAll()
    }
    
    // MARK: - Rating Stats (Batch)
    
    func loadRatingStats(for perfumes: [Perfume]) async {
        guard networkMonitor.isConnected, !perfumes.isEmpty else { return }
        let ids = perfumes.map(\.id)
        do {
            let stats = try await reviewDataSource.fetchRatingStatsForPerfumes(ids)
            // Merge statt Replace, damit vorherige Seiten erhalten bleiben
            for (key, value) in stats {
                self.ratingStatsMap[key] = value
            }
        } catch {
            AppLogger.perfumes.error("Rating-Stats laden fehlgeschlagen: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Initial Load (Cache-First)
    
    func loadData(forceRefresh: Bool = false) async {
        isLoading = true
        defer { isLoading = false }
        
        currentPage = 0
        hasMorePages = true
        isOffline = !networkMonitor.isConnected
        lastSyncedAt = cacheService.lastSyncedAt
        
        let cacheKey = currentCacheKey
        
        // 0. In-Memory-Cache prüfen (nur wenn kein Force-Refresh)
        if !forceRefresh, let cached = cachedResults(for: cacheKey) {
            self.perfumes = cached
            self.hasMorePages = cached.count >= pageSize
            self.errorMessage = nil
            return
        }
        
        // 1. Zuerst lokalen SwiftData-Cache laden und sofort anzeigen
        var cacheLoaded = false
        if let ctx = modelContext {
            do {
                let cached: [Perfume]
                if searchText.isEmpty {
                    cached = try cacheService.loadCachedPerfumes(modelContext: ctx, page: 0, pageSize: pageSize, filter: activeFilter, sort: sortOption)
                } else {
                    cached = try cacheService.searchCachedPerfumes(modelContext: ctx, query: searchText, page: 0, pageSize: pageSize, filter: activeFilter, sort: sortOption)
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
        
        // 2. Wenn offline → Cache anzeigen und aufhören
        guard networkMonitor.isConnected else {
            if perfumes.isEmpty {
                self.errorMessage = "Keine Internetverbindung und kein lokaler Cache vorhanden."
            }
            return
        }
        
        // 3. Wenn Cache frisch genug ist und kein Force-Refresh → überspringe Remote-Fetch
        if cacheLoaded && !forceRefresh && !cacheService.needsRefresh {
            self.errorMessage = nil
            return
        }
        
        // 4. Im Hintergrund von Supabase aktualisieren
        do {
            let results: [Perfume] = try await withRetry {
                if self.searchText.isEmpty {
                    return try await self.repository.fetchPerfumes(page: 0, pageSize: self.pageSize, filter: self.activeFilter, sort: self.sortOption)
                } else {
                    return try await self.repository.searchPerfumes(query: self.searchText, page: 0, pageSize: self.pageSize, filter: self.activeFilter, sort: self.sortOption)
                }
            }
            
            // In-Memory-Cache aktualisieren
            searchCache[cacheKey] = (results: results, timestamp: Date())
            
            // Ergebnisse in SwiftData cachen (nur für Katalog ohne Suche)
            if let ctx = modelContext, searchText.isEmpty && activeFilter.isEmpty {
                do {
                    try cacheService.cachePerfumes(results, modelContext: ctx)
                    lastSyncedAt = cacheService.lastSyncedAt
                    let managed = try cacheService.loadCachedPerfumes(modelContext: ctx, page: 0, pageSize: pageSize, filter: activeFilter, sort: sortOption)
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
            
            // Gesamtanzahl und Rating-Stats laden
            Task {
                if let count = try? await self.repository.fetchTotalCount(searchQuery: self.searchText.isEmpty ? nil : self.searchText, filter: self.activeFilter) {
                    self.totalCount = count
                }
            }
            Task {
                await self.loadRatingStats(for: results)
            }
        } catch {
            let networkError = NetworkError.from(error)
            AppLogger.perfumes.error("Fehler beim Laden der Parfums: \(networkError.localizedDescription)")
            if !cacheLoaded {
                self.errorMessage = networkError.localizedDescription
            }
        }
    }
    
    // MARK: - Infinite Scrolling
    
    func loadMoreIfNeeded(currentItem: Perfume) async {
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
                        cached = try cacheService.loadCachedPerfumes(modelContext: ctx, page: nextPage, pageSize: pageSize, filter: activeFilter, sort: sortOption)
                    } else {
                        cached = try cacheService.searchCachedPerfumes(modelContext: ctx, query: searchText, page: nextPage, pageSize: pageSize, filter: activeFilter, sort: sortOption)
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
                if self.searchText.isEmpty {
                    return try await self.repository.fetchPerfumes(page: nextPage, pageSize: self.pageSize, filter: self.activeFilter, sort: self.sortOption)
                } else {
                    return try await self.repository.searchPerfumes(query: self.searchText, page: nextPage, pageSize: self.pageSize, filter: self.activeFilter, sort: self.sortOption)
                }
            }
            
            // Ergebnisse cachen und managed Objects laden
            if let ctx = modelContext, searchText.isEmpty && activeFilter.isEmpty {
                do {
                    try cacheService.cachePerfumes(results, modelContext: ctx)
                    let managed = try cacheService.loadCachedPerfumes(modelContext: ctx, page: nextPage, pageSize: pageSize, filter: activeFilter, sort: sortOption)
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
            let networkError = NetworkError.from(error)
            AppLogger.perfumes.error("Fehler beim Nachladen: \(networkError.localizedDescription)")
            self.errorMessage = networkError.localizedDescription
        }
    }
    
    // MARK: - Pull-to-Refresh (erzwingt Supabase-Fetch wenn online)
    
    func refresh() async {
        guard networkMonitor.isConnected else {
            isOffline = true
            return
        }
        searchCache.removeAll()
        await loadData(forceRefresh: true)
    }
    
}
