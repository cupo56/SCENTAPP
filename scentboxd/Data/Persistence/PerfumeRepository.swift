//
//  PerfumeRepository.swift
//  scentboxd
//
//  Created by Cupo on 09.01.26.
//

import Foundation

protocol PerfumeRepository {
    func fetchPerfumes(page: Int, pageSize: Int) async throws -> [Perfume]
    func searchPerfumes(query: String, page: Int, pageSize: Int) async throws -> [Perfume]
    func fetchTotalCount(searchQuery: String?) async throws -> Int
}
