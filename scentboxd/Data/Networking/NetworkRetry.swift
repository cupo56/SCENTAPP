//
//  NetworkRetry.swift
//  scentboxd
//

import Foundation
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "scentboxd", category: "NetworkRetry")

/// Führt eine async Operation mit exponentiellem Backoff erneut aus.
/// - Parameters:
///   - maxAttempts: Maximale Anzahl Versuche (Standard: 3)
///   - initialDelay: Initiale Wartezeit in Sekunden (Standard: 1)
///   - operation: Die auszuführende async Operation
/// - Returns: Das Ergebnis der Operation
func withRetry<T>(
    maxAttempts: Int = 3,
    initialDelay: TimeInterval = 1.0,
    operation: () async throws -> T
) async throws -> T {
    var lastError: Error?
    
    for attempt in 1...maxAttempts {
        do {
            return try await operation()
        } catch {
            lastError = error
            let networkError = NetworkError.from(error)
            
            if attempt < maxAttempts && networkError.isTransient {
                let delay = initialDelay * pow(2.0, Double(attempt - 1))
                logger.warning("Versuch \(attempt)/\(maxAttempts) fehlgeschlagen, nächster Versuch in \(delay)s: \(error.localizedDescription)")
                try? await Task.sleep(for: .seconds(delay))
            } else {
                logger.error("Endgültig fehlgeschlagen nach \(attempt) Versuch(en): \(error.localizedDescription)")
                throw networkError
            }
        }
    }
    
    throw NetworkError.from(lastError!)
}
