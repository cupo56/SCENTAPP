//
//  PerfumeRepository.swift
//  scentboxd
//
//  Created by Cupo on 09.01.26.
//

import Foundation

protocol PerfumeRepository {
    func fetchAllPerfumes() async throws -> [Perfume]
    func addPerfume(_ perfume: Perfume) async throws
    func deletePerfume(_ perfume: Perfume) async throws
}
