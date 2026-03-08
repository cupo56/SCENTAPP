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
    var totalCountToReturn: Int = 0
    var brandsToReturn: [String] = []
    var concentrationsToReturn: [String] = []
    var errorToThrow: Error?
    
    // MARK: - Call Tracking
    
    private(set) var fetchPerfumesCalled = 0
    private(set) var searchPerfumesCalled = 0
    private(set) var fetchTotalCountCalled = 0
    private(set) var fetchBrandsCalled = 0
    private(set) var fetchConcentrationsCalled = 0
    
    private(set) var lastPage: Int?
    private(set) var lastPageSize: Int?
    private(set) var lastFilter: PerfumeFilter?
    private(set) var lastSort: PerfumeSortOption?
    private(set) var lastSearchQuery: String?
    
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
}
