//
//  PerfumeListViewModel.swift
//  scentboxd
//
//  Created by Cupo on 09.01.26.
//

import SwiftUI
import Combine

@MainActor
class PerfumeListViewModel: ObservableObject {
    @Published var perfumes: [Perfume] = []
    @Published var searchText: String = "" {
        didSet { onSearchTextChanged() }
    }
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    
    private let repository: PerfumeRepository = PerfumeRemoteDataSource()
    private let pageSize = 20
    private var currentPage = 0
    private var hasMorePages = true
    private var searchTask: Task<Void, Never>?
    
    // MARK: - Initial Load
    
    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        currentPage = 0
        hasMorePages = true
        
        do {
            let results: [Perfume]
            if searchText.isEmpty {
                results = try await repository.fetchPerfumes(page: 0, pageSize: pageSize)
            } else {
                results = try await repository.searchPerfumes(query: searchText, page: 0, pageSize: pageSize)
            }
            self.perfumes = results
            self.hasMorePages = results.count >= pageSize
        } catch {
            print("Fehler beim Laden von Supabase: \(error)")
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
            let results: [Perfume]
            if searchText.isEmpty {
                results = try await repository.fetchPerfumes(page: nextPage, pageSize: pageSize)
            } else {
                results = try await repository.searchPerfumes(query: searchText, page: nextPage, pageSize: pageSize)
            }
            self.perfumes.append(contentsOf: results)
            self.currentPage = nextPage
            self.hasMorePages = results.count >= pageSize
        } catch {
            print("Fehler beim Nachladen: \(error)")
        }
    }
    
    // MARK: - Pull-to-Refresh
    
    func refresh() async {
        await loadData()
    }
    
    // MARK: - Server-Side Search
    
    private func onSearchTextChanged() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            guard !Task.isCancelled else { return }
            await loadData()
        }
    }
}
