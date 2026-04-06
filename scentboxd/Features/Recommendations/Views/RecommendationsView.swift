//
//  RecommendationsView.swift
//  scentboxd
//
//  Personalisierte Parfum-Empfehlungen basierend auf der eigenen Sammlung.
//

import SwiftUI
import SwiftData

struct RecommendationsView: View {

    // MARK: - Queries (SwiftData, gleiche Logik wie ProfileView)

    @Query(filter: #Predicate<Perfume> { $0.userMetadata?.isOwned == true }, sort: \Perfume.name)
    private var ownedPerfumes: [Perfume]

    @Query(filter: #Predicate<Perfume> { $0.userMetadata?.isFavorite == true }, sort: \Perfume.name)
    private var favoritePerfumes: [Perfume]

    @Query
    private var allCachedPerfumes: [Perfume]

    // MARK: - Dependencies

    @Environment(\.dependencies) private var dependencies
    @State private var viewModel: RecommendationsViewModel?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.appBackground.ignoresSafeArea()
                content
            }
            .navigationTitle("Für dich")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel?.isLoading == true {
                        ProgressView()
                            .tint(DesignSystem.Colors.primary)
                    } else {
                        Button {
                            Task { await reload() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(DesignSystem.Colors.primary)
                        }
                        .accessibilityLabel("Empfehlungen neu berechnen")
                    }
                }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = dependencies.makeRecommendationsViewModel()
            }
            await reload()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if let vm = viewModel {
            if vm.isLoading && vm.recommendations.isEmpty {
                loadingView
            } else if let error = vm.errorMessage {
                errorView(message: error)
            } else if vm.recommendations.isEmpty {
                emptyView
            } else {
                recommendationsList(vm: vm)
            }
        } else {
            loadingView
        }
    }

    // MARK: - Recommendations List

    private func recommendationsList(vm: RecommendationsViewModel) -> some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                headerBanner
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 20)

                recommendationsGrid(vm: vm)
                    .padding(.horizontal, 16)

                Spacer(minLength: 32)
            }
        }
        .refreshable {
            await reload()
        }
    }

    // MARK: - Header Banner

    private var headerBanner: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.primary.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: "sparkles")
                    .font(.system(size: 20))
                    .foregroundStyle(DesignSystem.Colors.primary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Personalisierte Empfehlungen")
                    .font(DesignSystem.Fonts.display(size: 15, weight: .semibold))
                    .foregroundStyle(Color.primary)
                Text("Basierend auf deinen \(ownedPerfumes.count + favoritePerfumes.count) Düften")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Colors.appTextSecondary)
            }

            Spacer()
        }
        .padding(14)
        .glassPanel()
    }

    // MARK: - Grid

    private func recommendationsGrid(vm: RecommendationsViewModel) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]

        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(vm.recommendations) { rec in
                NavigationLink(destination: PerfumeDetailView(perfume: rec.perfume)) {
                    RecommendationCard(recommendation: rec) {
                        vm.markAsNotInterested(rec.perfume)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Empty State

    private var emptyView: some View {
        ContentUnavailableView {
            Label("Noch keine Empfehlungen", systemImage: "sparkles.slash")
                .foregroundStyle(DesignSystem.Colors.primary)
        } description: {
            Text("Füge Parfums zu deiner Sammlung oder Favoriten hinzu, damit wir passende Düfte für dich finden können.")
                .multilineTextAlignment(.center)
        } actions: {
            NavigationLink(destination: PerfumeListView()) {
                Text("Katalog entdecken")
                    .buttonStyle(.borderedProminent)
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignSystem.Colors.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Loading State

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.4)
                .tint(DesignSystem.Colors.primary)
            Text("Empfehlungen werden berechnet…")
                .font(.system(size: 14))
                .foregroundStyle(DesignSystem.Colors.appTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error State

    private func errorView(message: String) -> some View {
        ContentUnavailableView {
            Label("Fehler", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
                .multilineTextAlignment(.center)
        } actions: {
            Button("Erneut versuchen") {
                Task { await reload() }
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignSystem.Colors.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func reload() async {
        guard let vm = viewModel else { return }
        await vm.loadRecommendations(
            ownedPerfumes: ownedPerfumes,
            favoritePerfumes: favoritePerfumes,
            allCachedPerfumes: allCachedPerfumes
        )
    }
}
