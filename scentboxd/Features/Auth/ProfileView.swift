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
                    authenticatedView
                } else {
                    LoginView()
                }
            }
        }
    }
    
    private var authenticatedView: some View {
        ZStack {
            DesignSystem.Colors.bgDark.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    ZStack {
                        // Magenta Glow
                        Circle()
                            .fill(DesignSystem.Colors.primary.opacity(0.2))
                            .blur(radius: 60)
                            .frame(width: 200, height: 200)
                        
                        VStack(spacing: 12) {
                            // Avatar
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [DesignSystem.Colors.primary, .purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "person.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            
                            if let username = authManager.username, !username.isEmpty {
                                Text(username)
                                    .font(DesignSystem.Fonts.serif(size: 22, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Text(authManager.currentUser?.email ?? "Unbekannt")
                                .font(DesignSystem.Fonts.display(size: 14))
                                .foregroundStyle(Color(hex: "#94A3B8"))
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 8)
                    
                    // Stats Grid
                    HStack(spacing: 12) {
                        statCard(icon: "calendar", label: "Mitglied seit", value: memberSinceText)
                    }
                    .padding(.horizontal, 20)
                    
                    // Username Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("BENUTZERNAME")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2)
                            .foregroundColor(DesignSystem.Colors.primary)
                        
                        if isEditingUsername {
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "at")
                                        .foregroundColor(Color(hex: "#94A3B8"))
                                        .frame(width: 24)
                                    TextField("Benutzername", text: $usernameInput)
                                        .textContentType(.username)
                                        .autocapitalization(.none)
                                        .autocorrectionDisabled()
                                        .submitLabel(.done)
                                        .onSubmit {
                                            saveUsername()
                                        }
                                        .foregroundColor(.white)
                                }
                                .padding(16)
                                .glassPanel()
                                
                                HStack(spacing: 12) {
                                    Button("Speichern") {
                                        saveUsername()
                                    }
                                    .buttonStyle(PrimaryButtonStyle())
                                    .disabled(usernameInput.trimmingCharacters(in: .whitespaces).isEmpty || authManager.isLoading)
                                    
                                    Button("Abbrechen") {
                                        isEditingUsername = false
                                    }
                                    .foregroundColor(Color(hex: "#94A3B8"))
                                }
                            }
                        } else {
                            HStack {
                                Image(systemName: "at")
                                    .foregroundColor(DesignSystem.Colors.primary)
                                Text(authManager.username ?? "Nicht festgelegt")
                                    .foregroundStyle(authManager.username != nil ? .white : Color(hex: "#94A3B8"))
                                Spacer()
                                Button("Bearbeiten") {
                                    usernameInput = authManager.username ?? ""
                                    isEditingUsername = true
                                }
                                .font(.subheadline)
                                .foregroundColor(DesignSystem.Colors.champagne)
                            }
                            .padding(16)
                            .glassPanel()
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
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 40)
                    
                    // Logout Button
                    Button(role: .destructive) {
                        Task {
                            await authManager.signOut()
                        }
                    } label: {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .tint(.red)
                            } else {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Abmelden")
                            }
                        }
                        .foregroundColor(.red.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .disabled(authManager.isLoading)
                    .padding(.horizontal, 20)
                    
                    // App Info
                    HStack {
                        Text("Version")
                            .foregroundColor(Color(hex: "#94A3B8"))
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–")
                            .foregroundColor(Color(hex: "#64748B"))
                    }
                    .font(.caption)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Profil")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
    
    // MARK: - Helper Views
    
    private func statCard(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(DesignSystem.Colors.primary)
            Text(value)
                .font(DesignSystem.Fonts.display(size: 14, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#94A3B8"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .glassPanel()
    }
    
    private var memberSinceText: String {
        if let createdAt = authManager.currentUser?.createdAt {
            return createdAt.formatted(date: .abbreviated, time: .omitted)
        }
        return "–"
    }
    
    // MARK: - Actions
    
    private func saveUsername() {
        let trimmed = usernameInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        Task {
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
}

#Preview("Logged In") {
    ProfileView()
        .environment(AuthManager())
}
