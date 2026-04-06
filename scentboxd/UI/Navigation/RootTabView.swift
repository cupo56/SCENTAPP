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
            // Tab Content — alle Views bleiben im Speicher (State bleibt erhalten)
            ZStack {
                DailyPickView(weatherService: dependencies.weatherService)
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

            // Compare Floating Bar
            if showCompareBar {
                CompareFloatingBar()
                    .padding(.bottom, 72)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Custom Tab Bar
            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
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

// MARK: - Custom Tab Bar

private struct CustomTabBar: View {
    @Binding var selectedTab: Int

    /// (activeIcon, inactiveIcon, label)
    private let tabs: [(activeIcon: String, inactiveIcon: String, label: String)] = [
        ("sun.horizon.fill", "sun.horizon", "Heute"),
        ("book.fill", "book", "Katalog"),
        ("heart.fill", "heart", "Favoriten"),
        ("star.fill", "star", "Meine"),
        ("person.2.fill", "person.2", "Community"),
        ("person.fill", "person", "Profil")
    ]

    private let barBackground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x34/255, green: 0x18/255, blue: 0x26/255, alpha: 1)
            : UIColor.systemBackground
    })

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(DesignSystem.Colors.primary.opacity(0.25))
                .frame(height: 0.5)

            HStack(spacing: 0) {
                ForEach(tabs.indices, id: \.self) { index in
                    TabItemView(
                        selectedTab: $selectedTab,
                        index: index,
                        activeIcon: tabs[index].activeIcon,
                        inactiveIcon: tabs[index].inactiveIcon,
                        label: tabs[index].label
                    )
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 4)
            .background(barBackground)

            barBackground
                .frame(height: safeAreaBottomInset)
        }
    }

    private var safeAreaBottomInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom ?? 0
    }
}

private struct TabItemView: View {
    @Binding var selectedTab: Int
    let index: Int
    let activeIcon: String
    let inactiveIcon: String
    let label: String

    @State private var isBouncing = false

    private var isActive: Bool { selectedTab == index }

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedTab = index
            }
            bounce()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: isActive ? activeIcon : inactiveIcon)
                    .font(.system(size: 20, weight: isActive ? .bold : .regular))
                    .symbolRenderingMode(.monochrome)
                    .scaleEffect(isBouncing ? 1.5 : (isActive ? 1.12 : 1.0))
                    .shadow(
                        color: isActive ? DesignSystem.Colors.primary.opacity(0.55) : .clear,
                        radius: isActive ? 7 : 0,
                        x: 0, y: 0
                    )

                Text(label)
                    .font(.system(size: 9, weight: isActive ? .semibold : .regular))
            }
            .foregroundStyle(
                isActive
                    ? DesignSystem.Colors.primary
                    : DesignSystem.Colors.primary.opacity(0.45)
            )
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.22, dampingFraction: 0.42), value: isBouncing)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }

    private func bounce() {
        isBouncing = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(230))
            isBouncing = false
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
