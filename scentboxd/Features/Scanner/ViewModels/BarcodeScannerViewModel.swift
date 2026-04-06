//
//  BarcodeScannerViewModel.swift
//  scentboxd
//

import Foundation
import os

@Observable @MainActor
class BarcodeScannerViewModel {
    var foundPerfume: Perfume?
    var isSearching = false
    var errorMessage: String?
    private(set) var hasScanned = false

    private let repository: PerfumeRepository
    private let networkMonitor: NetworkMonitor
    private let logger = Logger(subsystem: "scentboxd", category: "BarcodeScanner")

    init(repository: PerfumeRepository, networkMonitor: NetworkMonitor) {
        self.repository = repository
        self.networkMonitor = networkMonitor
    }

    func handleScan(_ barcode: String) {
        guard !hasScanned && !isSearching else { return }
        hasScanned = true
        Task {
            await searchPerfume(ean: barcode)
        }
    }

    private func searchPerfume(ean: String) async {
        guard networkMonitor.isConnected else {
            errorMessage = NetworkError.noConnection.localizedDescription
            return
        }

        isSearching = true
        errorMessage = nil

        do {
            if let perfume = try await repository.fetchPerfumeByBarcode(ean: ean) {
                foundPerfume = perfume
            } else {
                errorMessage = String(localized: "Kein Parfum für diesen Barcode gefunden.")
            }
        } catch {
            errorMessage = NetworkError.handle(error, logger: logger, context: "fetchPerfumeByBarcode")
        }

        isSearching = false
    }

    func reset() {
        foundPerfume = nil
        isSearching = false
        errorMessage = nil
        hasScanned = false
    }
}
