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
    @Environment(CompareSelectionManager.self) private var compareManager
    @Environment(DeepLinkHandler.self) private var deepLinkHandler
    @State private var presentedPerfumeLink: PerfumeDeepLinkDestination?
    @State private var presentedCompareLink: CompareDeepLinkDestination?

    // Lokaler Helper, damit .overlay auf @Environment zugreifen kann, ohne Absturz
    private var showCompareBar: Bool {
        !compareManager.selectedPerfumes.isEmpty
    }

    init() {
        // Adaptive Tab Bar Appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0x34/255, green: 0x18/255, blue: 0x26/255, alpha: 1) // #341826
                : UIColor.systemBackground
        }
        
        // Inactive tabs
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(Color(hex: "#cb90ad"))
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(Color(hex: "#cb90ad"))
        ]
        
        // Active tabs
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color(hex: "#C20A66"))
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(Color(hex: "#C20A66"))
        ]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    @Environment(\.dependencies) private var dependencies

    var body: some View {
        TabView(selection: $selectedTab) {
            DailyPickView(weatherService: dependencies.weatherService)
                .tag(0)
                .tabItem {
                    Label("Heute", systemImage: "sun.horizon.fill")
                }

            PerfumeListView()
                .tag(1)
                .tabItem {
                    Label("Katalog", systemImage: "book.fill")
                }

            FavoritesView()
                .tag(2)
                .tabItem {
                    Label("Favoriten", systemImage: "heart.fill")
                }

            OwnedPerfumesView()
                .tag(3)
                .tabItem {
                    Label("Meine", systemImage: "star.fill")
                }

            NavigationStack {
                UserSearchView()
            }
                .tag(4)
                .tabItem {
                    Label("Community", systemImage: "person.2.fill")
                }

            ProfileView()
                .tag(5)
                .tabItem {
                    Label("Profil", systemImage: "person.fill")
                }
        }
        .tint(Color(hex: "#C20A66"))
        .environment(\.selectedTab, $selectedTab)
        .overlay(alignment: .bottom) {
            CompareFloatingBar()
                .padding(.bottom, 60) // Abstand zum TabBar-Rand
                .opacity(showCompareBar ? 1 : 0)
                .animation(.easeInOut, value: showCompareBar)
        }
        .onAppear {
            consumePendingDeepLinks()
        }
        .onChange(of: deepLinkHandler.pendingTab) { _, _ in
            consumePendingDeepLinks()
        }
        .onChange(of: deepLinkHandler.pendingPerfumeId) { _, _ in
            consumePendingDeepLinks()
        }
        .onChange(of: deepLinkHandler.pendingCompareIds) { _, _ in
            consumePendingDeepLinks()
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
                            Button("Schließen") {
                                presentedCompareLink = nil
                            }
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
    }
}

private struct PerfumeDeepLinkDestination: Identifiable {
    let id = UUID()
    let perfumeId: UUID
}

private struct CompareDeepLinkDestination: Identifiable {
    let id = UUID()
    let perfumeIds: [UUID]
}

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
