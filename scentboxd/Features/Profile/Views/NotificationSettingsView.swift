import SwiftUI

struct NotificationSettingsView: View {
    @State private var notificationManager = NotificationManager.shared
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            DesignSystem.Colors.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    permissionSection
                    if notificationManager.isPermissionGranted {
                        preferencesSection
                    }
                }
                .padding(.vertical, 24)
            }
        }
        .navigationTitle("Benachrichtigungen")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await notificationManager.checkPermissionStatus()
            if notificationManager.isPermissionGranted {
                await notificationManager.loadPreferences()
            }
        }
        .onDisappear {
            saveTask?.cancel()
        }
    }

    // MARK: - Permission Section

    private var permissionSection: some View {
        settingsSection(title: "BERECHTIGUNG") {
            if notificationManager.isPermissionGranted {
                HStack(spacing: 12) {
                    permissionIcon("bell.fill", color: .green)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Benachrichtigungen aktiviert")
                            .font(DesignSystem.Fonts.display(size: 15, weight: .medium))
                            .foregroundStyle(Color.primary)
                        Text("Du erhältst Push-Nachrichten von Scentboxd")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#94A3B8"))
                    }

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            } else if notificationManager.isPermissionDetermined {
                // Abgelehnt → Link zu Einstellungen
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        permissionIcon("bell.slash.fill", color: .orange)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Benachrichtigungen deaktiviert")
                                .font(DesignSystem.Fonts.display(size: 15, weight: .medium))
                                .foregroundStyle(Color.primary)
                            Text("Erlaube Benachrichtigungen in den Systemeinstellungen")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#94A3B8"))
                        }

                        Spacer()
                    }

                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("Zu den Einstellungen")
                            .font(DesignSystem.Fonts.display(size: 14, weight: .medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            } else {
                // Noch nicht gefragt
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        permissionIcon("bell.badge", color: DesignSystem.Colors.champagne)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Benachrichtigungen erlauben")
                                .font(DesignSystem.Fonts.display(size: 15, weight: .medium))
                                .foregroundStyle(Color.primary)
                            Text("Erhalte Updates zu Reviews, Likes und mehr")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#94A3B8"))
                        }

                        Spacer()
                    }

                    Button {
                        Task {
                            await notificationManager.requestPermission()
                            if notificationManager.isPermissionGranted {
                                await notificationManager.loadPreferences()
                            }
                        }
                    } label: {
                        Text("Benachrichtigungen aktivieren")
                            .font(DesignSystem.Fonts.display(size: 14, weight: .medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
    }

    // MARK: - Preferences Section

    private var preferencesSection: some View {
        settingsSection(title: "BENACHRICHTIGUNGEN") {
            preferenceToggle(
                icon: "text.bubble",
                iconColor: DesignSystem.Colors.champagne,
                title: "Neue Reviews",
                subtitle: "Wenn jemand ein Parfum aus deiner Sammlung bewertet",
                isOn: Binding(
                    get: { notificationManager.preferences.newReviews },
                    set: { newValue in
                        notificationManager.preferences.newReviews = newValue
                        scheduleSave()
                    }
                )
            )

            Divider().overlay(Color.primary.opacity(0.06))

            preferenceToggle(
                icon: "heart",
                iconColor: Color(hex: "#F472B6"),
                title: "Likes auf Bewertungen",
                subtitle: "Wenn jemand eine deiner Bewertungen liked",
                isOn: Binding(
                    get: { notificationManager.preferences.reviewLikes },
                    set: { newValue in
                        notificationManager.preferences.reviewLikes = newValue
                        scheduleSave()
                    }
                )
            )

            Divider().overlay(Color.primary.opacity(0.06))

            preferenceToggle(
                icon: "sparkles",
                iconColor: Color(hex: "#A78BFA"),
                title: "Ähnliche Düfte",
                subtitle: "Wenn ein Parfum ähnlich zu deiner Sammlung hinzugefügt wird",
                isOn: Binding(
                    get: { notificationManager.preferences.similarAdded },
                    set: { newValue in
                        notificationManager.preferences.similarAdded = newValue
                        scheduleSave()
                    }
                )
            )

            Divider().overlay(Color.primary.opacity(0.06))

            preferenceToggle(
                icon: "person.2",
                iconColor: Color(hex: "#60A5FA"),
                title: "Community-Updates",
                subtitle: "Neuigkeiten aus der Scentboxd-Community",
                isOn: Binding(
                    get: { notificationManager.preferences.communityUpdates },
                    set: { newValue in
                        notificationManager.preferences.communityUpdates = newValue
                        scheduleSave()
                    }
                )
            )
        }
    }

    // MARK: - Helpers

    private func settingsSection(title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
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

    private func permissionIcon(_ name: String, color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 14))
            .foregroundColor(color)
            .frame(width: 32, height: 32)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func preferenceToggle(
        icon: String,
        iconColor: Color,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            permissionIcon(icon, color: iconColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignSystem.Fonts.display(size: 15, weight: .medium))
                    .foregroundStyle(Color.primary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#94A3B8"))
            }

            Spacer()

            Toggle("", isOn: isOn)
                .tint(DesignSystem.Colors.primary)
                .labelsHidden()
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            await notificationManager.savePreferences()
        }
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}
