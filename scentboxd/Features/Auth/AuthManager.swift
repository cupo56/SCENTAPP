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

@Observable
@MainActor
class AuthManager {
    private let client = AppConfig.client
    
    var currentUser: User?
    var isAuthenticated: Bool { currentUser != nil }
    var isLoading = false
    var errorMessage: String?
    var username: String?
    var pendingEmailConfirmation = false

    private var sessionTask: Task<Void, Never>?
    private var pendingUsername: String?
    
    init() {
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
            // Ausstehenden Username speichern, falls der User seine E-Mail bestätigt hat
            if username == nil, let pending = pendingUsername {
                _ = await saveUsername(pending)
                pendingUsername = nil
            }
            pendingEmailConfirmation = false
        } catch {
            currentUser = nil
            AuthSessionCache.shared.clear()
        }
    }
    
    /// Anmeldung mit E-Mail und Passwort
    func signIn(email: String, password: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let session = try await client.auth.signIn(email: email, password: password)
            currentUser = session.user
            // Auth-Cache aktualisieren
            try? await AuthSessionCache.shared.refreshSession()
            await loadUsername()
            // Ausstehenden Username speichern, falls der User seine E-Mail bestätigt hat
            if username == nil, let pending = pendingUsername {
                _ = await saveUsername(pending)
                pendingUsername = nil
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
            AuthSessionCache.shared.clear()
        } catch {
            errorMessage = "Abmeldung fehlgeschlagen: \(error.localizedDescription)"
        }
    }
    
    /// Lädt den Username aus der profiles-Tabelle
    func loadUsername() async {
        guard let userId = currentUser?.id else { return }
        
        let profile: ProfileDTO? = try? await client
            .from("profiles")
            .select("*")
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        
        username = profile?.username
    }
    
    /// Speichert den Username in der profiles-Tabelle
    func saveUsername(_ newUsername: String) async -> Bool {
        guard let userId = currentUser?.id else { return false }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let dto = ProfileDTO(
                id: userId,
                username: newUsername,
                updatedAt: Date()
            )
            
            try await client
                .from("profiles")
                .upsert(dto)
                .execute()
            
            username = newUsername
            return true
        } catch {
            errorMessage = "Fehler beim Speichern des Benutzernamens: \(error.localizedDescription)"
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
                return "Ungültige E-Mail oder Passwort."
            case "email_not_confirmed":
                return "Bitte bestätige deine E-Mail-Adresse."
            case "user_already_exists", "email_address_in_use":
                return "Diese E-Mail-Adresse ist bereits registriert. Bitte melde dich an."
            case "weak_password":
                return "Das Passwort ist zu schwach. Mindestens 6 Zeichen."
            case "invalid_email", "validation_failed":
                return "Bitte gib eine gültige E-Mail-Adresse ein."
            default:
                return "Authentifizierungsfehler: \(errorCode.rawValue)"
            }
        }

        return "Ein Fehler ist aufgetreten. Bitte versuche es erneut."
    }
}
