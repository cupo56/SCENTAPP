import SwiftUI
import SwiftData

struct PerfumeActionsSection: View {
    let perfume: Perfume
    let viewModel: PerfumeDetailViewModel
    let authManager: AuthManager
    let modelContext: ModelContext
    let compareManager: CompareSelectionManager
    let isRenderingShare: Bool
    let shareAction: () -> Void
    let listAction: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
            // Sammlung
            Button {
                if authManager.isAuthenticated {
                    viewModel.toggleOwned(modelContext: modelContext, isAuthenticated: authManager.isAuthenticated)
                } else {
                    viewModel.showLoginAlert = true
                }
            } label: {
                let isOwned = viewModel.statusService.isOwned(perfume)
                VStack(spacing: 6) {
                    Image(systemName: isOwned ? "star.fill" : "star")
                        .font(.system(size: 14))
                    Text("Sammlung")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(isOwned ? .white : DesignSystem.Colors.appText)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(isOwned ? DesignSystem.Colors.primary : Color.clear)
                .glassPanel()
                .shadow(color: isOwned ? DesignSystem.Colors.primary.opacity(0.25) : Color.clear, radius: 10, x: 0, y: 4)
            }
            .accessibilityLabel(viewModel.statusService.isOwned(perfume) ? "Aus Sammlung entfernen" : "Zur Sammlung hinzufügen")

            // Wunschliste
            Button {
                if authManager.isAuthenticated {
                    viewModel.toggleFavorite(modelContext: modelContext, isAuthenticated: authManager.isAuthenticated)
                } else {
                    viewModel.showLoginAlert = true
                }
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: viewModel.statusService.isFavorite(perfume) ? "heart.fill" : "heart")
                        .font(.system(size: 14))
                    Text("Wunschliste")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(DesignSystem.Colors.appText)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .glassPanel()
            }
            .accessibilityLabel(viewModel.statusService.isFavorite(perfume) ? "Von Wunschliste entfernen" : "Zur Wunschliste hinzufügen")

            // Vergleichen
            Button {
                withAnimation(.snappy) {
                    compareManager.toggle(perfume)
                }
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: compareManager.isSelected(perfume) ? "checkmark.circle.fill" : "plus.square.on.square")
                        .font(.system(size: 14))
                        .foregroundColor(compareManager.isSelected(perfume) ? DesignSystem.Colors.champagne : DesignSystem.Colors.appText)
                    Text("Vergleichen")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(compareManager.isSelected(perfume) ? DesignSystem.Colors.champagne : DesignSystem.Colors.appText)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .glassPanel()
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(compareManager.isSelected(perfume) ? DesignSystem.Colors.champagne.opacity(0.5) : Color.clear, lineWidth: 1)
                )
            }
            .accessibilityLabel(compareManager.isSelected(perfume) ? "Aus Vergleich entfernen" : "Zum Vergleich hinzufügen")

            // Teilen
            Button {
                shareAction()
            } label: {
                VStack(spacing: 6) {
                    if isRenderingShare {
                        ProgressView()
                            .tint(DesignSystem.Colors.appText)
                            .frame(width: 14, height: 14)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                    }
                    Text("Teilen")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(DesignSystem.Colors.appText)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .glassPanel()
            }
            .disabled(isRenderingShare)
            .accessibilityLabel("Teilen")
            .accessibilityHint("Erstellt ein Bild dieses Parfums zum Teilen")
            } // HStack

            // Liste
            Button {
                listAction()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 14))
                    Text("Zu Liste hinzufügen")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(DesignSystem.Colors.appText)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .glassPanel()
            }
            .accessibilityLabel("Zu Liste hinzufügen")
            .accessibilityHint("Öffnet die Listenauswahl für dieses Parfum")
        } // VStack
    }
}
