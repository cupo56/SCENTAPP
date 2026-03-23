//
//  AuthManager.swift
//  scentboxd
//
//  Created by Cupo on 25.01.26.
//

import Foundation
import Supabase
import Auth
import Observation

// MARK: - Client-Side Auth Rate Limiter

/// Sliding-window rate limiter for authentication attempts.
/// Prevents brute-force attacks client-side (Supabase also has server-side limits).
@MainActor
final class AuthRateLimiter {
    private let maxAttempts: Int
    private let windowSeconds: TimeInterval
    private var timestamps: [Date] = []

    init(maxAttempts: Int = 5, windowSeconds: TimeInterval = 60) {
        self.maxAttempts = maxAttempts
        self.windowSeconds = windowSeconds
    }

    /// Records an attempt and returns `nil` if allowed,
    /// or the number of seconds until the next attempt is permitted.
    func recordAttempt() -> Int? {
        let now = Date()
        // Remove expired timestamps outside the window
        timestamps.removeAll { now.timeIntervalSince($0) > windowSeconds }

        if timestamps.count >= maxAttempts {
            // Cooldown = time until the oldest attempt expires
            guard let oldest = timestamps.first else { return 1 }
            let cooldown = Int(ceil(windowSeconds - now.timeIntervalSince(oldest)))
            return max(cooldown, 1)
        }

        timestamps.append(now)
        return nil
    }
}

// MARK: - AuthManager

@Observable
@MainActor
class AuthManager {
    private let client = AppConfig.client
    private let rateLimiter = AuthRateLimiter()
    private let profileService: ProfileService
    
    var currentUser: User?
    var isAuthenticated: Bool { currentUser != nil }
    var isLoading = false
    var errorMessage: String?
    var username: String?
    var pendingEmailConfirmation = false

    private var sessionTask: Task<Void, Never>?
    private var pendingUsername: String?
    
    init(profileService: ProfileService) {
        self.profileService = profileService
        sessionTask = Task { [weak self] in
            await self?.checkSession()
        }
    }
    
    /// Prüft beim App-Start, ob eine gültige Session existiert
    func checkSession() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await client.auth.session
            currentUser = session.user
            // Auth-Cache aktualisieren
            try? await AuthSessionCache.shared.refreshSession()
            await loadUsername()
            if username == nil, let pending = pendingUsername {
                if await saveUsername(pending) {
                    pendingUsername = nil
                }
            }
            pendingEmailConfirmation = false
        } catch {
            currentUser = nil
            await AuthSessionCache.shared.clear()
        }
    }
    
    /// Anmeldung mit E-Mail und Passwort
    func signIn(email: String, password: String) async -> Bool {
        // Rate limit check
        if let cooldown = rateLimiter.recordAttempt() {
            errorMessage = String(localized: "Zu viele Anmeldeversuche. Bitte warte \(cooldown) Sekunden.")
            return false
        }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let session = try await client.auth.signIn(email: email, password: password)
            currentUser = session.user
            // Auth-Cache aktualisieren
            try? await AuthSessionCache.shared.refreshSession()
            await loadUsername()
            if username == nil, let pending = pendingUsername {
                if await saveUsername(pending) {
                    pendingUsername = nil
                }
            }
            pendingEmailConfirmation = false
            return true
        } catch {
            errorMessage = mapAuthError(error)
            return false
        }
    }
    
    /// Registrierung mit E-Mail und Passwort
    /// - Parameter username: Optionaler Username, der nach Bestätigung der E-Mail gespeichert wird
    /// - Returns: `true` wenn der User sofort eingeloggt ist (E-Mail bereits bestätigt), `false` bei ausstehender Bestätigung oder Fehler
    func signUp(email: String, password: String, username: String? = nil) async -> Bool {
        // Rate limit check
        if let cooldown = rateLimiter.recordAttempt() {
            errorMessage = String(localized: "Zu viele Versuche. Bitte warte \(cooldown) Sekunden.")
            return false
        }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await client.auth.signUp(email: email, password: password)
            let user = response.user
            if user.emailConfirmedAt != nil {
                // E-Mail bereits bestätigt (z.B. Supabase ohne Confirmation konfiguriert)
                currentUser = user
                pendingEmailConfirmation = false
                if let username = username {
                    _ = await saveUsername(username)
                }
                return true
            }
            // E-Mail-Bestätigung erforderlich — Username für späteres Speichern merken
            pendingEmailConfirmation = true
            pendingUsername = username
            return false
        } catch {
            errorMessage = mapAuthError(error)
            return false
        }
    }
    
    /// Abmeldung
    func signOut() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            try await client.auth.signOut()
            currentUser = nil
            username = nil
            await AuthSessionCache.shared.clear()
        } catch {
            errorMessage = String(localized: "Abmeldung fehlgeschlagen: \(error.localizedDescription)")
        }
    }
    
    /// Sendet eine E-Mail zum Zurücksetzen des Passworts
    func resetPassword(email: String) async -> Bool {
        if let cooldown = rateLimiter.recordAttempt() {
            errorMessage = String(localized: "Zu viele Versuche. Bitte warte \(cooldown) Sekunden.")
            return false
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await client.auth.resetPasswordForEmail(email)
            return true
        } catch {
            errorMessage = mapAuthError(error)
            return false
        }
    }

    /// Lädt den Username aus der profiles-Tabelle
    func loadUsername() async {
        guard let userId = currentUser?.id else { return }
        guard let profile = try? await profileService.fetchProfile(userId: userId) else { return }
        username = profile.username
    }

    /// Speichert den Username in der profiles-Tabelle
    func saveUsername(_ newUsername: String) async -> Bool {
        guard let userId = currentUser?.id else { return false }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await profileService.saveProfile(userId: userId, username: newUsername)
            username = newUsername
            return true
        } catch {
            errorMessage = String(localized: "Fehler beim Speichern des Benutzernamens: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Übersetzt Auth-Fehler in benutzerfreundliche Nachrichten
    private func mapAuthError(_ error: Error) -> String {
        // Supabase AuthError strukturiert prüfen (robuster als String-Matching)
        if let authError = error as? AuthError,
           case .api(_, let errorCode, _, _) = authError {
            switch errorCode.rawValue {
            case "invalid_credentials":
                return String(localized: "Ungültige E-Mail oder Passwort.")
            case "email_not_confirmed":
                return String(localized: "Bitte bestätige deine E-Mail-Adresse.")
            case "user_already_exists", "email_address_in_use":
                return String(localized: "Diese E-Mail-Adresse ist bereits registriert. Bitte melde dich an.")
            case "weak_password":
                return String(localized: "Das Passwort ist zu schwach. Mindestens 6 Zeichen.")
            case "invalid_email", "validation_failed":
                return String(localized: "Bitte gib eine gültige E-Mail-Adresse ein.")
            default:
                return String(localized: "Authentifizierungsfehler: \(errorCode.rawValue)")
            }
        }

        return String(localized: "Ein Fehler ist aufgetreten. Bitte versuche es erneut.")
    }
}
