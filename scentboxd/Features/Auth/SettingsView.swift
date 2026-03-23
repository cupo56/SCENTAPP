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
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showLogoutConfirmation = false
    @State private var showCacheCleared = false
    @State private var isClearingCache = false
    @State private var clearCacheTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            DesignSystem.Colors.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    appearanceSection
                    cacheSection
                    notificationSection
                    accountSection
                    aboutSection
                }
                .padding(.vertical, 24)
            }
        }
        .navigationTitle("Einstellungen")
        .navigationBarTitleDisplayMode(.inline)
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
        .onDisappear {
            clearCacheTask?.cancel()
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        settingsSection(title: "ERSCHEINUNGSBILD") {
            darkModeToggleRow
        }
    }

    /// Eine Zeile mit Label + erklärendem Text; rechts ein klarer Toggle (Bar-Stil).
    private var darkModeToggleRow: some View {
        HStack(alignment: .center, spacing: 14) {
            settingsIcon("moon.stars.fill", color: DesignSystem.Colors.primary)

            VStack(alignment: .leading, spacing: 4) {
                Text("Dunkelmodus")
                    .font(DesignSystem.Fonts.display(size: 15, weight: .semibold))
                    .foregroundStyle(Color.primary)

                Text(themeManager.prefersDarkAppearance
                     ? "Dunkles Design ist aktiv"
                     : "Helles Design ist aktiv")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondary)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: Bindable(themeManager).prefersDarkAppearance)
                .labelsHidden()
                .tint(DesignSystem.Colors.primary)
                .accessibilityLabel(String(localized: "Dunkelmodus"))
                .accessibilityHint(String(localized: "Schaltet zwischen hellem und dunklem Erscheinungsbild"))
        }
        .padding(.vertical, 4)
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
                            .foregroundStyle(Color.primary)

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
            .accessibilityLabel("Cache leeren")
            .accessibilityHint("Löscht lokale Daten und zwischengespeicherte Bilder")
        }
    }

    // MARK: - Notification Section

    private var notificationSection: some View {
        settingsSection(title: "BENACHRICHTIGUNGEN") {
            NavigationLink(destination: NotificationSettingsView()) {
                HStack(spacing: 12) {
                    settingsIcon("bell", color: DesignSystem.Colors.champagne)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Benachrichtigungen")
                            .font(DesignSystem.Fonts.display(size: 15, weight: .medium))
                            .foregroundStyle(Color.primary)

                        Text("Push-Nachrichten verwalten")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#94A3B8"))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "#94A3B8"))
                }
            }
            .accessibilityLabel("Benachrichtigungen")
            .accessibilityHint("Öffnet die Benachrichtigungseinstellungen")
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
                            .foregroundStyle(Color.primary)

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
                            .foregroundStyle(Color.primary)

                        Text(createdAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#94A3B8"))
                    }

                    Spacer()
                }
            }

            Divider()
                .overlay(Color.primary.opacity(0.06))

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
            .accessibilityLabel("Abmelden")
            .accessibilityHint("Doppeltippen, um dich abzumelden")
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
                .foregroundStyle(Color.primary)
            Spacer()
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#94A3B8"))
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
        clearCacheTask?.cancel()
        isClearingCache = true

        clearCacheTask = Task {
            // Yield so SwiftUI renders the spinner before blocking work
            try? await Task.sleep(for: .milliseconds(300))

            do {
                try modelContext.delete(model: Perfume.self)
                try modelContext.delete(model: Review.self)
                try modelContext.save()
            } catch {
                AppLogger.cache.error("Failed to clear SwiftData cache: \(error.localizedDescription)")
            }

            ImagePipeline.shared.cache.removeAll()
            UserDefaults.standard.removeObject(forKey: "PerfumeCatalog_lastSyncedAt")

            withAnimation {
                isClearingCache = false
                showCacheCleared = true
            }

            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled {
                withAnimation {
                    showCacheCleared = false
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(AuthManager(profileService: ProfileService()))
    }
}
