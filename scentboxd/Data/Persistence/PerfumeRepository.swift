//
//  PerfumeRepository.swift
//  scentboxd
//
//  Created by Cupo on 09.01.26.
//

import Foundation

protocol PerfumeRepository {
    func fetchPerfumes(page: Int, pageSize: Int, filter: PerfumeFilter, sort: PerfumeSortOption) async throws -> [Perfume]
    func searchPerfumes(query: String, page: Int, pageSize: Int, filter: PerfumeFilter, sort: PerfumeSortOption) async throws -> [Perfume]
    func fetchSearchSuggestions(query: String) async throws -> [SearchSuggestionDTO]
    func fetchTotalCount(searchQuery: String?, filter: PerfumeFilter) async throws -> Int
    func fetchAvailableBrands() async throws -> [String]
    func fetchAvailableConcentrations() async throws -> [String]
    func fetchPerfumesByIds(_ ids: [UUID]) async throws -> [Perfume]
    func fetchSimilarPerfumes(for perfumeId: UUID, limit: Int) async throws -> [Perfume]
    func fetchPerfumeByBarcode(ean: String) async throws -> Perfume?
}
