//
//  ContentView.swift
//  scentboxd
//
//  Created by Cupo on 24.01.26.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = PerfumeListViewModel()
    @State private var authManager = AuthManager()
    @State private var isLoading = true
    @State private var showSplash = true
    
    private let syncService = UserPerfumeSyncService()
    
    // Minimale Splash-Dauer für bessere UX (auch bei schnellem Laden)
    private let minimumSplashDuration: Double = 1.5
    
    var body: some View {
        ZStack {
            // Hauptinhalt (TabView)
            RootTabView()
                .environmentObject(viewModel)
                .environment(authManager)
                .opacity(showSplash ? 0 : 1)
            
            // Splash Screen Overlay
            if showSplash {
                SplashScreenView()
                    .transition(.opacity.combined(with: .scale(scale: 1.1)))
            }
        }
        .task {
            // Starte beides gleichzeitig: Datenladen und Mindest-Wartezeit
            await withTaskGroup(of: Void.self) { group in
                // Task 1: Daten laden
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
            
            // User-Parfums aus Supabase synchronisieren (wenn eingeloggt)
            if authManager.isAuthenticated {
                await syncService.syncFromSupabase(
                    modelContext: modelContext,
                    perfumes: viewModel.perfumes
                )
            }
            
            // Smooth Übergang zum Hauptinhalt
            withAnimation(.easeInOut(duration: 0.5)) {
                showSplash = false
            }
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            // Sync wenn User sich einloggt
            if isAuthenticated {
                Task {
                    await syncService.syncFromSupabase(
                        modelContext: modelContext,
                        perfumes: viewModel.perfumes
                    )
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
