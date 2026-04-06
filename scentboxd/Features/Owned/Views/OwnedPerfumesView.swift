//
//  OwnedPerfumesView.swift
//  scentboxd
//
//  Created by Cupo on 16.01.26.
//

import SwiftUI
import SwiftData

struct OwnedPerfumesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dependencies) private var dependencies
    @Environment(AuthManager.self) private var authManager

    @Query(filter: #Predicate<Perfume> { perfume in
        perfume.userMetadata?.isOwned == true
    }, sort: \Perfume.name)
    var ownedPerfumes: [Perfume]

    @State private var isRefreshing = false
    @State private var syncErrorMessage: String?
    @State private var showSyncErrorAlert = false
    
    var body: some View {
        PerfumeCollectionView(
            perfumes: ownedPerfumes,
            emptyTitle: "Sammlung leer",
            emptyIcon: "cabinet",
            emptyDescription: Text("Füge Parfums hinzu, die du bereits besitzt."),
            navigationTitle: "Meine Sammlung",
            refreshAction: refreshOwnedPerfumes,
            isRefreshing: isRefreshing,
            headerContent: {
                VStack(spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Parfums gesamt: \(ownedPerfumes.count)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(hex: "#94A3B8"))
                                .textCase(.uppercase)
                                .tracking(1)
                        }
                        Spacer()
                    }

                    NavigationLink(destination: RecommendationsView()) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(DesignSystem.Colors.primary.opacity(0.12))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "sparkles")
                                    .font(.system(size: 17))
                                    .foregroundStyle(DesignSystem.Colors.primary)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Für dich empfohlen")
                                    .font(DesignSystem.Fonts.display(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.primary)
                                Text("Passende Düfte basierend auf deiner Sammlung")
                                    .font(.system(size: 12))
                                    .foregroundStyle(DesignSystem.Colors.appTextSecondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(hex: "#94A3B8"))
                        }
                        .padding(14)
                        .glassPanel()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Für dich empfohlen")
                    .accessibilityHint("Öffnet personalisierte Parfum-Empfehlungen")
                }
            }
        )
        .errorAlert("Synchronisierungsfehler", isPresented: $showSyncErrorAlert, message: syncErrorMessage, retryAction: refreshOwnedPerfumes)
    }

    @MainActor
    private func refreshOwnedPerfumes() async {
        guard authManager.isAuthenticated else { return }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let allPerfumes = try modelContext.fetch(FetchDescriptor<Perfume>())
            try await dependencies.makeSyncService().syncFromSupabase(
                modelContext: modelContext,
                perfumes: allPerfumes
            )
        } catch {
            syncErrorMessage = NetworkError.handle(error, logger: AppLogger.sync, context: "Sammlungs-Sync")
            showSyncErrorAlert = true
        }
    }
}

#Preview {
    OwnedPerfumesView()
        .modelContainer(for: [Perfume.self, UserPersonalData.self], inMemory: true)
}
