//
//  AppLogger.swift
//  scentboxd
//

import Foundation
import os

/// Zentrale Logger-Instanzen für strukturiertes Logging
enum AppLogger {
    static let perfumes = Logger(subsystem: Bundle.main.bundleIdentifier ?? "scentboxd", category: "Perfumes")
    static let reviews = Logger(subsystem: Bundle.main.bundleIdentifier ?? "scentboxd", category: "Reviews")
    static let userPerfumes = Logger(subsystem: Bundle.main.bundleIdentifier ?? "scentboxd", category: "UserPerfumes")
    static let sync = Logger(subsystem: Bundle.main.bundleIdentifier ?? "scentboxd", category: "Sync")
    static let auth = Logger(subsystem: Bundle.main.bundleIdentifier ?? "scentboxd", category: "Auth")
    static let cache = Logger(subsystem: Bundle.main.bundleIdentifier ?? "scentboxd", category: "Cache")
    static let notifications = Logger(subsystem: Bundle.main.bundleIdentifier ?? "scentboxd", category: "Notifications")
}
