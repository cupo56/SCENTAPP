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
    func fetchTotalCount(searchQuery: String?, filter: PerfumeFilter) async throws -> Int
    func fetchAvailableBrands() async throws -> [String]
    func fetchAvailableConcentrations() async throws -> [String]
}
