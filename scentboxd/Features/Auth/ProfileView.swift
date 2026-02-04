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
                        Text("Angemeldet als")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(authManager.currentUser?.email ?? "Unbekannt")
                            .font(.headline)
                    }
                }
                .padding(.vertical, 8)
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
                    Text("1.0.0")
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
