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
    
    private let repository: PerfumeRepository = PerfumeRemoteDataSource()
    private let cacheService = PerfumeCacheService()
    private let networkMonitor = NetworkMonitor.shared
    private let pageSize = 20
    private var currentPage = 0
    private var hasMorePages = true
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    var modelContext: ModelContext?
    
    init() {
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
        
        networkMonitor.$isConnected
            .receive(on: RunLoop.main)
            .sink { [weak self] isConnected in
                self?.isOffline = !isConnected
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Initial Load (Cache-First)
    
    func loadData(forceRefresh: Bool = false) async {
        isLoading = true
        defer { isLoading = false }
        
        currentPage = 0
        hasMorePages = true
        isOffline = !networkMonitor.isConnected
        lastSyncedAt = cacheService.lastSyncedAt
        
        // 1. Zuerst lokalen Cache laden und sofort anzeigen
        var cacheLoaded = false
        if let ctx = modelContext {
            do {
                let cached: [Perfume]
                if searchText.isEmpty {
                    cached = try cacheService.loadCachedPerfumes(modelContext: ctx, page: 0, pageSize: pageSize)
                } else {
                    cached = try cacheService.searchCachedPerfumes(modelContext: ctx, query: searchText, page: 0, pageSize: pageSize)
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
                    return try await self.repository.fetchPerfumes(page: 0, pageSize: self.pageSize)
                } else {
                    return try await self.repository.searchPerfumes(query: self.searchText, page: 0, pageSize: self.pageSize)
                }
            }
            
            // Ergebnisse in SwiftData cachen (nur für Katalog, nicht für Suche)
            if let ctx = modelContext, searchText.isEmpty {
                do {
                    try cacheService.cachePerfumes(results, modelContext: ctx)
                    lastSyncedAt = cacheService.lastSyncedAt
                    // Managed Objects aus SwiftData laden für konsistenten State
                    let managed = try cacheService.loadCachedPerfumes(modelContext: ctx, page: 0, pageSize: pageSize)
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
            
            // Gesamtanzahl laden
            Task {
                if let count = try? await self.repository.fetchTotalCount(searchQuery: self.searchText.isEmpty ? nil : self.searchText) {
                    self.totalCount = count
                }
            }
        } catch {
            let networkError = NetworkError.from(error)
            AppLogger.perfumes.error("Fehler beim Laden der Parfums: \(networkError.localizedDescription)")
            // Wenn Cache vorhanden, Fehler nicht anzeigen
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
                        cached = try cacheService.loadCachedPerfumes(modelContext: ctx, page: nextPage, pageSize: pageSize)
                    } else {
                        cached = try cacheService.searchCachedPerfumes(modelContext: ctx, query: searchText, page: nextPage, pageSize: pageSize)
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
                    return try await self.repository.fetchPerfumes(page: nextPage, pageSize: self.pageSize)
                } else {
                    return try await self.repository.searchPerfumes(query: self.searchText, page: nextPage, pageSize: self.pageSize)
                }
            }
            
            // Ergebnisse cachen und managed Objects laden
            if let ctx = modelContext, searchText.isEmpty {
                do {
                    try cacheService.cachePerfumes(results, modelContext: ctx)
                    let managed = try cacheService.loadCachedPerfumes(modelContext: ctx, page: nextPage, pageSize: pageSize)
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
        await loadData(forceRefresh: true)
    }
    
}
