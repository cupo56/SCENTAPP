//
//  SettingsView.swift
//  scentboxd
//

import SwiftUI
import SwiftData
import Auth
import Nuke
import os

struct SettingsView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showLogoutConfirmation = false
    @State private var showCacheCleared = false
    @State private var isClearingCache = false

    var body: some View {
        ZStack {
            DesignSystem.Colors.bgDark.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    cacheSection
                    accountSection
                    aboutSection
                }
                .padding(.vertical, 24)
            }
        }
        .navigationTitle("Einstellungen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .confirmationDialog(
            "Möchtest du dich wirklich abmelden?",
            isPresented: $showLogoutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Abmelden", role: .destructive) {
                Task {
                    await authManager.signOut()
                    dismiss()
                }
            }
            Button("Abbrechen", role: .cancel) {}
        }
    }

    // MARK: - Cache Section

    private var cacheSection: some View {
        settingsSection(title: "CACHE") {
            Button {
                clearCache()
            } label: {
                HStack(spacing: 12) {
                    settingsIcon("trash", color: .orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cache leeren")
                            .font(DesignSystem.Fonts.display(size: 15, weight: .medium))
                            .foregroundColor(.white)

                        Text("Lokale Daten und Bilder löschen")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#94A3B8"))
                    }

                    Spacer()

                    if isClearingCache {
                        ProgressView()
                            .tint(DesignSystem.Colors.primary)
                    } else if showCacheCleared {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .disabled(isClearingCache)
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        settingsSection(title: "ACCOUNT") {
            if let email = authManager.currentUser?.email {
                HStack(spacing: 12) {
                    settingsIcon("envelope", color: Color(hex: "#94A3B8"))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("E-Mail")
                            .font(DesignSystem.Fonts.display(size: 15, weight: .medium))
                            .foregroundColor(.white)

                        Text(email)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#94A3B8"))
                    }

                    Spacer()
                }
            }

            if let createdAt = authManager.currentUser?.createdAt {
                HStack(spacing: 12) {
                    settingsIcon("calendar", color: Color(hex: "#94A3B8"))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mitglied seit")
                            .font(DesignSystem.Fonts.display(size: 15, weight: .medium))
                            .foregroundColor(.white)

                        Text(createdAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#94A3B8"))
                    }

                    Spacer()
                }
            }

            Divider()
                .overlay(Color.white.opacity(0.06))

            Button {
                showLogoutConfirmation = true
            } label: {
                HStack(spacing: 12) {
                    settingsIcon("rectangle.portrait.and.arrow.right", color: .red.opacity(0.8))

                    Text("Abmelden")
                        .font(DesignSystem.Fonts.display(size: 15, weight: .medium))
                        .foregroundColor(.red.opacity(0.8))

                    Spacer()

                    if authManager.isLoading {
                        ProgressView()
                            .tint(.red.opacity(0.6))
                    }
                }
            }
            .disabled(authManager.isLoading)
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        settingsSection(title: "ÜBER") {
            aboutRow(label: "Version", value: appVersion)
            aboutRow(label: "Build", value: buildNumber)
        }
    }

    // MARK: - Helpers

    private func settingsSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundColor(DesignSystem.Colors.primary)
                .padding(.horizontal, 20)

            VStack(spacing: 16) {
                content()
            }
            .padding(16)
            .glassPanel()
            .padding(.horizontal, 16)
        }
    }

    private func settingsIcon(_ name: String, color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 14))
            .foregroundColor(color)
            .frame(width: 32, height: 32)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func aboutRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(DesignSystem.Fonts.display(size: 15, weight: .medium))
                .foregroundColor(.white)
            Spacer()
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#64748B"))
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
    }

    // MARK: - Actions

    private func clearCache() {
        isClearingCache = true

        // Clear SwiftData local cache
        do {
            try modelContext.delete(model: Perfume.self)
            try modelContext.delete(model: Review.self)
            try modelContext.save()
        } catch {
            AppLogger.cache.error("Failed to clear SwiftData cache: \(error.localizedDescription)")
        }

        // Clear Nuke image cache
        ImagePipeline.shared.cache.removeAll()

        // Reset catalog sync timestamp
        UserDefaults.standard.removeObject(forKey: "PerfumeCatalog_lastSyncedAt")

        isClearingCache = false

        withAnimation {
            showCacheCleared = true
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation {
                showCacheCleared = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(AuthManager())
    }
}
