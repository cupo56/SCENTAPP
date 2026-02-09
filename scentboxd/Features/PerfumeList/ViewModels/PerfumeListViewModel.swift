//
//  PerfumeListViewModel.swift
//  scentboxd
//
//  Created by Cupo on 09.01.26.
//

import SwiftUI
import Combine
import os

@MainActor
class PerfumeListViewModel: ObservableObject {
    @Published var perfumes: [Perfume] = []
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var errorMessage: String? = nil
    
    private let repository: PerfumeRepository = PerfumeRemoteDataSource()
    private let pageSize = 20
    private var currentPage = 0
    private var hasMorePages = true
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
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
    }
    
    // MARK: - Initial Load
    
    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        currentPage = 0
        hasMorePages = true
        
        do {
            let results: [Perfume] = try await withRetry {
                if self.searchText.isEmpty {
                    return try await self.repository.fetchPerfumes(page: 0, pageSize: self.pageSize)
                } else {
                    return try await self.repository.searchPerfumes(query: self.searchText, page: 0, pageSize: self.pageSize)
                }
            }
            self.perfumes = results
            self.hasMorePages = results.count >= pageSize
            self.errorMessage = nil
        } catch {
            let networkError = NetworkError.from(error)
            AppLogger.perfumes.error("Fehler beim Laden der Parfums: \(networkError.localizedDescription)")
            self.errorMessage = networkError.localizedDescription
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
        
        do {
            let results: [Perfume] = try await withRetry {
                if self.searchText.isEmpty {
                    return try await self.repository.fetchPerfumes(page: nextPage, pageSize: self.pageSize)
                } else {
                    return try await self.repository.searchPerfumes(query: self.searchText, page: nextPage, pageSize: self.pageSize)
                }
            }
            self.perfumes.append(contentsOf: results)
            self.currentPage = nextPage
            self.hasMorePages = results.count >= pageSize
        } catch {
            let networkError = NetworkError.from(error)
            AppLogger.perfumes.error("Fehler beim Nachladen: \(networkError.localizedDescription)")
            self.errorMessage = networkError.localizedDescription
        }
    }
    
    // MARK: - Pull-to-Refresh
    
    func refresh() async {
        await loadData()
    }
    
}
