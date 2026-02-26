//
//  AuthSessionCache.swift
//  scentboxd
//

import Foundation
import Supabase
import os

/// Cached den aktuellen User-ID, um wiederholte `client.auth.session`-Aufrufe zu vermeiden.
/// Jede Remote-Operation braucht die User-ID — ohne Cache wird bei jedem Aufruf
/// ein neuer Session-Fetch ausgelöst.
@MainActor
final class AuthSessionCache {
    
    static let shared = AuthSessionCache()
    
    private let client = AppConfig.client
    private var cachedUserId: UUID?
    private var cachedEmail: String?
    private var lastFetchedAt: Date?
    
    /// Maximale Gültigkeit des Cache (5 Minuten).
    /// Danach wird die Session beim nächsten Zugriff neu gefetcht.
    private let cacheTTL: TimeInterval = 300
    
    private init() {}
    
    // MARK: - Public API
    
    /// Gibt die gecachte User-ID zurück, oder fetcht die Session falls nötig.
    func getUserId() async throws -> UUID {
        if let userId = cachedUserId, isCacheValid {
            return userId
        }
        return try await refreshSession().user.id
    }
    
    /// Gibt die gecachte E-Mail zurück, oder fetcht die Session falls nötig.
    func getUserEmail() async throws -> String? {
        if let email = cachedEmail, isCacheValid {
            return email
        }
        return try await refreshSession().user.email
    }
    
    /// Aktualisiert den Cache mit frischen Session-Daten.
    /// Wird von AuthManager nach Login/Logout aufgerufen.
    @discardableResult
    func refreshSession() async throws -> Session {
        let session = try await client.auth.session
        cachedUserId = session.user.id
        cachedEmail = session.user.email
        lastFetchedAt = Date()
        return session
    }
    
    /// Löscht den Cache (z.B. bei Logout).
    func clear() {
        cachedUserId = nil
        cachedEmail = nil
        lastFetchedAt = nil
    }
    
    // MARK: - Private
    
    private var isCacheValid: Bool {
        guard let lastFetched = lastFetchedAt else { return false }
        return Date().timeIntervalSince(lastFetched) < cacheTTL
    }
}
