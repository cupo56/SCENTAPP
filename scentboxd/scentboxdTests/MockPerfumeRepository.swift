//
//  MockPerfumeRepository.swift
//  scentboxdTests
//

import Foundation
@testable import scentboxd

@MainActor
final class MockPerfumeRepository: PerfumeRepository {
    
    // MARK: - Configurable Responses
    
    var perfumesToReturn: [Perfume] = []
    var searchResultsToReturn: [Perfume] = []
    var searchSuggestionsToReturn: [SearchSuggestionDTO] = []
    var totalCountToReturn: Int = 0
    var brandsToReturn: [String] = []
    var concentrationsToReturn: [String] = []
    var errorToThrow: Error?
    
    // MARK: - Call Tracking
    
    private(set) var fetchPerfumesCalled = 0
    private(set) var searchPerfumesCalled = 0
    private(set) var fetchSearchSuggestionsCalled = 0
    private(set) var fetchTotalCountCalled = 0
    private(set) var fetchBrandsCalled = 0
    private(set) var fetchConcentrationsCalled = 0
    
    private(set) var lastPage: Int?
    private(set) var lastPageSize: Int?
    private(set) var lastFilter: PerfumeFilter?
    private(set) var lastSort: PerfumeSortOption?
    private(set) var lastSearchQuery: String?
    private(set) var lastSuggestionQuery: String?
    
    // MARK: - PerfumeRepository
    
    func fetchPerfumes(page: Int, pageSize: Int, filter: PerfumeFilter, sort: PerfumeSortOption) async throws -> [Perfume] {
        fetchPerfumesCalled += 1
        lastPage = page
        lastPageSize = pageSize
        lastFilter = filter
        lastSort = sort
        if let error = errorToThrow { throw error }
        return perfumesToReturn
    }
    
    func searchPerfumes(query: String, page: Int, pageSize: Int, filter: PerfumeFilter, sort: PerfumeSortOption) async throws -> [Perfume] {
        searchPerfumesCalled += 1
        lastSearchQuery = query
        lastPage = page
        lastPageSize = pageSize
        lastFilter = filter
        lastSort = sort
        if let error = errorToThrow { throw error }
        return searchResultsToReturn
    }

    func fetchSearchSuggestions(query: String) async throws -> [SearchSuggestionDTO] {
        fetchSearchSuggestionsCalled += 1
        lastSuggestionQuery = query
        if let error = errorToThrow { throw error }
        return searchSuggestionsToReturn
    }
    
    func fetchTotalCount(searchQuery: String?, filter: PerfumeFilter) async throws -> Int {
        fetchTotalCountCalled += 1
        if let error = errorToThrow { throw error }
        return totalCountToReturn
    }
    
    func fetchAvailableBrands() async throws -> [String] {
        fetchBrandsCalled += 1
        if let error = errorToThrow { throw error }
        return brandsToReturn
    }
    
    func fetchAvailableConcentrations() async throws -> [String] {
        fetchConcentrationsCalled += 1
        if let error = errorToThrow { throw error }
        return concentrationsToReturn
    }

    func fetchPerfumesByIds(_ ids: [UUID]) async throws -> [Perfume] {
        if let error = errorToThrow { throw error }
        return perfumesToReturn.filter { ids.contains($0.id) }
    }

    func fetchSimilarPerfumes(for perfumeId: UUID, limit: Int) async throws -> [Perfume] {
        if let error = errorToThrow { throw error }
        return perfumesToReturn.prefix(limit).map { $0 }
    }
}
