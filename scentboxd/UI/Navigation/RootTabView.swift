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
    @Environment(\.dependencies) private var dependencies
    @State private var presentedPerfumeLink: PerfumeDeepLinkDestination?
    @State private var presentedCompareLink: CompareDeepLinkDestination?

    private var showCompareBar: Bool {
        !compareManager.selectedPerfumes.isEmpty
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab-Inhalte: alle im Speicher halten, per Opacity umschalten
            ZStack {
                NavigationStack {
                    DailyPickView(weatherService: dependencies.weatherService)
                }
                .opacity(selectedTab == 0 ? 1 : 0)
                .allowsHitTesting(selectedTab == 0)

                PerfumeListView()
                    .opacity(selectedTab == 1 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 1)

                FavoritesView()
                    .opacity(selectedTab == 2 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 2)

                OwnedPerfumesView()
                    .opacity(selectedTab == 3 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 3)

                NavigationStack {
                    UserSearchView()
                }
                .opacity(selectedTab == 4 ? 1 : 0)
                .allowsHitTesting(selectedTab == 4)

                ProfileView()
                    .opacity(selectedTab == 5 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Compare Floating Bar über der Tab-Bar
            if showCompareBar {
                CompareFloatingBar()
                    .padding(.bottom, 60)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Custom native-looking Tab Bar (6 Tabs, kein Mehr-Tab)
            NativeStyleTabBar(selectedTab: $selectedTab)
        }
        .animation(.easeInOut(duration: 0.2), value: showCompareBar)
        .environment(\.selectedTab, $selectedTab)
        .onAppear { consumePendingDeepLinks() }
        .onChange(of: deepLinkHandler.pendingTab) { _, _ in consumePendingDeepLinks() }
        .onChange(of: deepLinkHandler.pendingPerfumeId) { _, _ in consumePendingDeepLinks() }
        .onChange(of: deepLinkHandler.pendingCompareIds) { _, _ in consumePendingDeepLinks() }
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
    }
}

// MARK: - Native Style Tab Bar

/// Custom Tab Bar, die den nativen iOS-Look nachbildet, aber garantiert alle 6 Tabs
/// ohne einen "Mehr"-Tab darstellt (nativer SwiftUI `TabView` klappt auf iPhone
/// bei >5 Items automatisch in einen More-Tab, dessen Navigation unzuverlässig ist).
private struct NativeStyleTabBar: View {
    @Binding var selectedTab: Int

    private struct TabDefinition {
        let icon: String
        let filledIcon: String
        let label: String
    }

    private let tabs: [TabDefinition] = [
        .init(icon: "sun.horizon", filledIcon: "sun.horizon.fill", label: "Heute"),
        .init(icon: "book", filledIcon: "book.fill", label: "Katalog"),
        .init(icon: "heart", filledIcon: "heart.fill", label: "Favoriten"),
        .init(icon: "star", filledIcon: "star.fill", label: "Meine"),
        .init(icon: "person.2", filledIcon: "person.2.fill", label: "Community"),
        .init(icon: "person", filledIcon: "person.fill", label: "Profil")
    ]

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                ForEach(tabs.indices, id: \.self) { index in
                    let tab = tabs[index]
                    let isActive = selectedTab == index
                    Button {
                        selectedTab = index
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: isActive ? tab.filledIcon : tab.icon)
                                .font(.system(size: 22, weight: .regular))
                                .frame(height: 26)
                            Text(tab.label)
                                .font(.system(size: 10, weight: .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(isActive ? DesignSystem.Colors.primary : Color(uiColor: .secondaryLabel))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 6)
                        .padding(.bottom, 2)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.label)
                    .accessibilityAddTraits(isActive ? [.isSelected] : [])
                }
            }
            .padding(.bottom, 2)
        }
        .background(.bar)
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
