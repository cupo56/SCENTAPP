//
//  ContentView.swift
//  scentboxd
//
//  Created by Cupo on 24.01.26.
//

import SwiftUI
import SwiftData
import os

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var filterVM: PerfumeFilterViewModel
    @State private var viewModel: PerfumeListViewModel
    @State private var authManager: AuthManager
    @State private var isLoading = true
    @State private var showSplash = true
    @State private var syncErrorMessage: String?
    @State private var showSyncErrorAlert = false
    @State private var compareManager = CompareSelectionManager()

    private let container: DependencyContainer
    private let syncService: UserPerfumeSyncService
    private let reviewSyncService: ReviewSyncService

    @MainActor
    init() {
        let container = DependencyContainer()
        self.container = container
        let filterVM = container.makePerfumeFilterViewModel()
        self._filterVM = State(initialValue: filterVM)
        self._viewModel = State(initialValue: container.makePerfumeListViewModel(filterVM: filterVM))
        self._authManager = State(initialValue: container.makeAuthManager())
        self.syncService = container.makeSyncService()
        self.reviewSyncService = container.makeReviewSyncService()
    }

    @MainActor
    init(container: DependencyContainer) {
        self.container = container
        let filterVM = container.makePerfumeFilterViewModel()
        self._filterVM = State(initialValue: filterVM)
        self._viewModel = State(initialValue: container.makePerfumeListViewModel(filterVM: filterVM))
        self._authManager = State(initialValue: container.makeAuthManager())
        self.syncService = container.makeSyncService()
        self.reviewSyncService = container.makeReviewSyncService()
    }
    
    private let minimumSplashDuration = AppConfig.Timing.splashMinDuration
    
    var body: some View {
        ZStack {
            // Hauptinhalt (TabView)
            RootTabView()
                .environment(viewModel)
                .environment(filterVM)
                .environment(authManager)
                .environment(compareManager)
                .environment(\.dependencies, container)
                .opacity(showSplash ? 0 : 1)
            
            // Splash Screen Overlay
            if showSplash {
                SplashScreenView()
                    .transition(.opacity.combined(with: .scale(scale: 1.1)))
            }
        }
        .task {
            // ModelContext an ViewModel übergeben für SwiftData-Zugriff
            viewModel.modelContext = modelContext
            
            // Starte beides gleichzeitig: Datenladen und Mindest-Wartezeit
            await withTaskGroup(of: Void.self) { group in
                // Task 1: Daten laden (Cache-First)
                group.addTask {
                    await viewModel.loadData()
                }
                
                // Task 2: Mindest-Splash-Dauer
                group.addTask {
                    try? await Task.sleep(for: .seconds(minimumSplashDuration))
                }
                
                // Warte bis beide fertig sind
                await group.waitForAll()
            }
            
            // Synchronisierung (wenn eingeloggt)
            if authManager.isAuthenticated {
                do {
                    try await syncService.syncFromSupabase(
                        modelContext: modelContext,
                        perfumes: viewModel.dataLoader.perfumes
                    )
                } catch {
                    syncErrorMessage = NetworkError.handle(error, logger: AppLogger.sync, context: "Sync")
                    showSyncErrorAlert = true
                }
                // Ausstehende Reviews hochladen
                await reviewSyncService.uploadPendingReviews(modelContext: modelContext)
            }

            // Smooth Übergang zum Hauptinhalt
            withAnimation(.easeInOut(duration: 0.5)) {
                showSplash = false
            }
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                Task {
                    do {
                        try await syncService.syncFromSupabase(
                            modelContext: modelContext,
                            perfumes: viewModel.dataLoader.perfumes
                        )
                    } catch {
                        syncErrorMessage = NetworkError.handle(error, logger: AppLogger.sync, context: "Sync")
                        showSyncErrorAlert = true
                    }
                    await reviewSyncService.uploadPendingReviews(modelContext: modelContext)
                }
            } else {
                clearUserData()
            }
        }
        .errorAlert("Synchronisierungsfehler", isPresented: $showSyncErrorAlert, message: syncErrorMessage)
        .preferredColorScheme(.dark)
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    // MARK: - Logout Cleanup

    /// Entfernt alle User-spezifischen Daten aus SwiftData beim Logout.
    private func clearUserData() {
        // UserPersonalData von ALLEN Perfumes entfernen (nicht nur aktuelle Seite)
        let descriptor = FetchDescriptor<Perfume>(
            predicate: #Predicate { $0.userMetadata != nil }
        )
        if let allWithMetadata = try? modelContext.fetch(descriptor) {
            for perfume in allWithMetadata {
                perfume.userMetadata = nil
            }
        }

        // Alle lokalen Reviews löschen
        do {
            try modelContext.delete(model: Review.self)
            try modelContext.save()
        } catch {
            AppLogger.cache.error("Logout-Cleanup fehlgeschlagen: \(error.localizedDescription)")
        }

        // In-Memory-Cache leeren und Liste neu laden
        viewModel.dataLoader.clearSearchCache()
        Task {
            await viewModel.loadData(forceRefresh: true)
        }
    }
}

#Preview {
    ContentView()
        .environment(DeepLinkHandler())
}
