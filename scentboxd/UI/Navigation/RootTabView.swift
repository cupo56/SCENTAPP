//
//  RootTabView.swift
//  scentboxd
//
//  Created by Cupo on 09.01.26.
//

import SwiftUI
import SwiftData

// Environment-Key für Tab-Navigation aus Child-Views heraus
private struct SelectedTabKey: EnvironmentKey {
    static let defaultValue: Binding<Int> = .constant(0)
}

extension EnvironmentValues {
    var selectedTab: Binding<Int> {
        get { self[SelectedTabKey.self] }
        set { self[SelectedTabKey.self] = newValue }
    }
}

struct RootTabView: View {
    @State private var selectedTab = 0
    @State private var showProfileSheet = false
    @Environment(CompareSelectionManager.self) private var compareManager
    @Environment(DeepLinkHandler.self) private var deepLinkHandler
    @Environment(\.dependencies) private var dependencies
    @State private var presentedPerfumeLink: PerfumeDeepLinkDestination?
    @State private var presentedCompareLink: CompareDeepLinkDestination?

    private var showCompareBar: Bool {
        !compareManager.selectedPerfumes.isEmpty
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    DailyPickView(weatherService: dependencies.weatherService)
                }
                .tabItem {
                    Label("Heute", systemImage: "sun.horizon")
                }
                .tag(0)

                PerfumeListView()
                    .tabItem {
                        Label("Katalog", systemImage: "book")
                    }
                    .tag(1)

                FavoritesView()
                    .tabItem {
                        Label("Favoriten", systemImage: "heart")
                    }
                    .tag(2)

                OwnedPerfumesView()
                    .tabItem {
                        Label("Meine", systemImage: "star")
                    }
                    .tag(3)

                NavigationStack {
                    UserSearchView()
                }
                .tabItem {
                    Label("Community", systemImage: "person.2")
                }
                .tag(4)
            }
            .tint(DesignSystem.Colors.primary)

            if showCompareBar {
                CompareFloatingBar()
                    .padding(.bottom, 56)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showCompareBar)
        .environment(\.selectedTab, $selectedTab)
        .environment(\.showProfileSheet, $showProfileSheet)
        .onAppear { consumePendingDeepLinks() }
        .onChange(of: deepLinkHandler.pendingTab) { _, _ in consumePendingDeepLinks() }
        .onChange(of: deepLinkHandler.pendingPerfumeId) { _, _ in consumePendingDeepLinks() }
        .onChange(of: deepLinkHandler.pendingCompareIds) { _, _ in consumePendingDeepLinks() }
        .onChange(of: deepLinkHandler.pendingProfileSheet) { _, _ in consumePendingDeepLinks() }
        .sheet(isPresented: $showProfileSheet) {
            ProfileView()
        }
        .sheet(item: $presentedPerfumeLink) { destination in
            NavigationStack {
                PerfumeDetailView(perfumeId: destination.perfumeId)
            }
        }
        .fullScreenCover(item: $presentedCompareLink) { destination in
            NavigationStack {
                CompareDeepLinkContainer(perfumeIds: destination.perfumeIds)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Schließen") { presentedCompareLink = nil }
                                .foregroundColor(DesignSystem.Colors.champagne)
                                .accessibilityLabel("Vergleich schließen")
                        }
                    }
            }
        }
    }

    private func consumePendingDeepLinks() {
        if let pendingTab = deepLinkHandler.pendingTab {
            selectedTab = pendingTab
            deepLinkHandler.consumePendingTab()
        }
        if let pendingPerfumeId = deepLinkHandler.pendingPerfumeId {
            presentedPerfumeLink = PerfumeDeepLinkDestination(perfumeId: pendingPerfumeId)
            deepLinkHandler.consumePendingPerfumeId()
        }
        if let pendingCompareIds = deepLinkHandler.pendingCompareIds {
            presentedCompareLink = CompareDeepLinkDestination(perfumeIds: pendingCompareIds)
            deepLinkHandler.consumePendingCompareIds()
        }
        if deepLinkHandler.pendingProfileSheet {
            showProfileSheet = true
            deepLinkHandler.consumePendingProfileSheet()
        }
    }
}

// MARK: - Deep Link Helpers

private struct PerfumeDeepLinkDestination: Identifiable {
    let id = UUID()
    let perfumeId: UUID
}

private struct CompareDeepLinkDestination: Identifiable {
    let id = UUID()
    let perfumeIds: [UUID]
}

// MARK: - Compare Deep Link Container

private struct CompareDeepLinkContainer: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.modelContext) private var modelContext
    @Environment(CompareSelectionManager.self) private var compareManager

    let perfumeIds: [UUID]

    @State private var perfumes: [Perfume] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ZStack {
                    DesignSystem.Colors.appBackground.ignoresSafeArea()
                    ProgressView("Vergleich wird geladen...")
                        .tint(DesignSystem.Colors.primary)
                }
            } else if perfumes.count >= 2 {
                CompareView(perfumes: perfumes)
            } else {
                ContentUnavailableView(
                    "Vergleich nicht verfuegbar",
                    systemImage: "square.3.layers.3d.slash",
                    description: Text(errorMessage ?? "Mindestens zwei gueltige Parfums werden fuer einen Vergleich benoetigt.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DesignSystem.Colors.appBackground)
            }
        }
        .task(id: perfumeIds) {
            await loadComparePerfumes()
        }
    }

    @MainActor
    private func loadComparePerfumes() async {
        isLoading = true
        errorMessage = nil
        do {
            let resolvedPerfumes = try await dependencies.makePerfumeResolver().resolvePerfumes(ids: perfumeIds, modelContext: modelContext)
            perfumes = resolvedPerfumes
            compareManager.selectedPerfumes = resolvedPerfumes
            if resolvedPerfumes.count < 2 {
                errorMessage = "Es konnten nicht genug Parfums fuer den Vergleich geladen werden."
            }
        } catch {
            errorMessage = NetworkError.handle(error, logger: AppLogger.perfumes, context: "Compare Deep Link")
        }
        isLoading = false
    }
}

#Preview {
    let container = DependencyContainer()
    let filterVM = container.makePerfumeFilterViewModel()
    RootTabView()
        .environment(container.makePerfumeListViewModel(filterVM: filterVM))
        .environment(filterVM)
        .environment(AuthManager(profileService: ProfileService()))
        .environment(CompareSelectionManager())
        .environment(DeepLinkHandler())
        .environment(\.dependencies, container)
}
