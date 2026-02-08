//
//  AuthManager.swift
//  scentboxd
//
//  Created by Cupo on 25.01.26.
//

import Foundation
import Supabase
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
    
    init() {
        Task {
            await checkSession()
        }
    }
    
    /// Prüft beim App-Start, ob eine gültige Session existiert
    func checkSession() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let session = try await client.auth.session
            currentUser = session.user
            await loadUsername()
        } catch {
            currentUser = nil
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
            await loadUsername()
            return true
        } catch {
            errorMessage = mapAuthError(error)
            return false
        }
    }
    
    /// Registrierung mit E-Mail und Passwort
    func signUp(email: String, password: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let response = try await client.auth.signUp(email: email, password: password)
            // Bei manchen Konfigurationen muss der User die E-Mail bestätigen
            let user = response.user
            // Prüfe ob die E-Mail bereits bestätigt wurde
            if user.emailConfirmedAt != nil {
                currentUser = user
                return true
            }
            errorMessage = "Bitte bestätige deine E-Mail-Adresse."
            return true // Registrierung war erfolgreich, aber E-Mail-Bestätigung steht aus
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
        let errorString = error.localizedDescription.lowercased()
        
        if errorString.contains("invalid login credentials") || errorString.contains("invalid_credentials") {
            return "Ungültige E-Mail oder Passwort."
        } else if errorString.contains("email not confirmed") {
            return "Bitte bestätige deine E-Mail-Adresse."
        } else if errorString.contains("user already registered") {
            return "Diese E-Mail ist bereits registriert."
        } else if errorString.contains("password") && errorString.contains("weak") {
            return "Das Passwort ist zu schwach. Mindestens 6 Zeichen."
        } else if errorString.contains("invalid email") {
            return "Bitte gib eine gültige E-Mail-Adresse ein."
        }
        
        return "Ein Fehler ist aufgetreten: \(error.localizedDescription)"
    }
}
