//
//  ProfileView.swift
//  scentboxd
//
//  Created by Cupo on 25.01.26.
//

import SwiftUI
import Auth

struct ProfileView: View {
    @Environment(AuthManager.self) private var authManager
    
    @State private var isEditingUsername = false
    @State private var usernameInput = ""
    @State private var showUsernameSaved = false
    
    var body: some View {
        NavigationStack {
            Group {
                if authManager.isAuthenticated {
                    // Eingeloggt: Profil anzeigen
                    authenticatedView
                } else {
                    // Nicht eingeloggt: Login View anzeigen
                    LoginView()
                }
            }
        }
    }
    
    private var authenticatedView: some View {
        List {
            // User Info Section
            Section {
                HStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(Color.accentColor)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        if let username = authManager.username, !username.isEmpty {
                            Text(username)
                                .font(.headline)
                        }
                        Text(authManager.currentUser?.email ?? "Unbekannt")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            
            // Benutzername Section
            Section("Benutzername") {
                if isEditingUsername {
                    HStack {
                        TextField("Benutzername", text: $usernameInput)
                            .textContentType(.username)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                        
                        Button("Speichern") {
                            Task {
                                let trimmed = usernameInput.trimmingCharacters(in: .whitespaces)
                                guard !trimmed.isEmpty else { return }
                                let success = await authManager.saveUsername(trimmed)
                                if success {
                                    isEditingUsername = false
                                    showUsernameSaved = true
                                    Task {
                                        try? await Task.sleep(for: .seconds(2))
                                        showUsernameSaved = false
                                    }
                                }
                            }
                        }
                        .disabled(usernameInput.trimmingCharacters(in: .whitespaces).isEmpty || authManager.isLoading)
                        
                        Button("Abbrechen") {
                            isEditingUsername = false
                        }
                        .foregroundStyle(.secondary)
                    }
                } else {
                    HStack {
                        Label(authManager.username ?? "Nicht festgelegt", systemImage: "at")
                            .foregroundStyle(authManager.username != nil ? .primary : .secondary)
                        Spacer()
                        Button("Bearbeiten") {
                            usernameInput = authManager.username ?? ""
                            isEditingUsername = true
                        }
                        .font(.subheadline)
                    }
                }
                
                if showUsernameSaved {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Benutzername gespeichert")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                
                if let error = authManager.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            
            // Statistics Section
            Section("Statistiken") {
                HStack {
                    Label("Mitglied seit", systemImage: "calendar")
                    Spacer()
                    if let createdAt = authManager.currentUser?.createdAt {
                        Text(createdAt, style: .date)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Actions Section
            Section {
                Button(role: .destructive) {
                    Task {
                        await authManager.signOut()
                    }
                } label: {
                    HStack {
                        if authManager.isLoading {
                            ProgressView()
                        } else {
                            Label("Abmelden", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                }
                .disabled(authManager.isLoading)
            }
            
            // App Info Section
            Section("Über die App") {
                HStack {
                    Label("Version", systemImage: "info.circle")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Profil")
    }
}

#Preview("Logged In") {
    ProfileView()
        .environment(AuthManager())
}
