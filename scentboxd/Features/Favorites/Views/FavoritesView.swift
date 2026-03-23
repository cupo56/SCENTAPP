//
//  FavoritesView.swift
//  scentboxd
//
//  Created by Cupo on 16.01.26.
//

import SwiftUI
import SwiftData

struct FavoritesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dependencies) private var dependencies
    @Environment(AuthManager.self) private var authManager

    @Query(filter: #Predicate<Perfume> { perfume in
        perfume.userMetadata?.isFavorite == true
    }, sort: \Perfume.name)
    var favoritePerfumes: [Perfume]

    @State private var isRefreshing = false
    @State private var syncErrorMessage: String?
    @State private var showSyncErrorAlert = false
    
    var body: some View {
        PerfumeCollectionView(
            perfumes: favoritePerfumes,
            emptyTitle: "Keine Favoriten",
            emptyIcon: "heart.slash",
            emptyDescription: Text("Markiere Parfums mit dem Herz-Symbol, um sie hier zu sehen."),
            navigationTitle: "Favoriten",
            refreshAction: refreshFavorites,
            isRefreshing: isRefreshing,
            headerContent: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Favoriten gesamt: \(favoritePerfumes.count)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(hex: "#94A3B8"))
                            .textCase(.uppercase)
                            .tracking(1)
                    }
                    Spacer()
                }
            }
        )
        .errorAlert("Synchronisierungsfehler", isPresented: $showSyncErrorAlert, message: syncErrorMessage, retryAction: refreshFavorites)
    }

    @MainActor
    private func refreshFavorites() async {
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
            syncErrorMessage = NetworkError.handle(error, logger: AppLogger.sync, context: "Favoriten-Sync")
            showSyncErrorAlert = true
        }
    }
}

#Preview {
    FavoritesView()
        .modelContainer(for: [Perfume.self, UserPersonalData.self], inMemory: true)
}
