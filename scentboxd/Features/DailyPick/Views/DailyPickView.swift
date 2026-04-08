//
//  DailyPickView.swift
//  scentboxd
//
//  Hauptansicht für "Was trage ich heute?" — Tägliche Parfum-Empfehlung
//  basierend auf Wetter, Anlass und Parfum-Noten.
//

import SwiftUI
import SwiftData

struct DailyPickView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dependencies) private var dependencies

    @State private var viewModel: DailyPickViewModel

    init(weatherService: WeatherService) {
        _viewModel = State(initialValue: DailyPickViewModel(weatherService: weatherService))
    }

    var body: some View {
        ZStack {
            DesignSystem.Colors.appBackground
                .ignoresSafeArea()

            if viewModel.isLoading && viewModel.topPick == nil {
                loadingView
            } else if viewModel.isEmpty {
                emptyCollectionView
            } else {
                mainContent
            }
        }
        .navigationTitle("Heute")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                ProfileToolbarButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await viewModel.refreshPick(modelContext: modelContext)
                    }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.primary)
                        .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                        .animation(
                            viewModel.isLoading
                                ? .linear(duration: 1).repeatForever(autoreverses: false)
                                : .default,
                            value: viewModel.isLoading
                        )
                }
                .accessibilityLabel("Neuer Vorschlag")
                .disabled(viewModel.isLoading)
            }
        }
        .task {
            await viewModel.loadDailyPick(modelContext: modelContext)
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Wetter-Header
                WeatherHeaderView(weatherService: viewModel.weatherService)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))

                // Occasion Chips
                VStack(alignment: .leading, spacing: 8) {
                    Text("ANLASS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.appTextSecondary)
                        .textCase(.uppercase)
                        .tracking(1.5)
                        .padding(.horizontal, 16)

                    OccasionChipBar(
                        selectedOccasion: $viewModel.selectedOccasion
                    ) { occasion in
                        Task {
                            await viewModel.selectOccasion(occasion, modelContext: modelContext)
                        }
                    }
                }

                // Hero Card — Tagesempfehlung
                if let topPick = viewModel.topPick {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12))
                                .foregroundStyle(DesignSystem.Colors.champagne)
                            Text("DEINE EMPFEHLUNG")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(DesignSystem.Colors.champagne)
                                .tracking(1.5)
                        }
                        .padding(.horizontal, 16)

                        NavigationLink(destination: PerfumeDetailView(perfume: topPick.perfume)) {
                            DailyPickHeroCard(recommendation: topPick)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
                }

                // "Anderer Vorschlag" Button
                Button {
                    Task {
                        await viewModel.refreshPick(modelContext: modelContext)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Anderer Vorschlag")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(DesignSystem.Colors.primary)
                    .padding(.horizontal, 24)
                    .frame(height: 44)
                    .background(DesignSystem.Colors.primary.opacity(0.1))
                    .clipShape(Capsule())
                }
                .padding(.horizontal, 16)
                .disabled(viewModel.isLoading)

                // Alternativen
                if !viewModel.alternatives.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("WEITERE VORSCHLÄGE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(DesignSystem.Colors.appTextSecondary)
                            .tracking(1.5)
                            .padding(.horizontal, 16)

                        VStack(spacing: 10) {
                            ForEach(viewModel.alternatives) { alt in
                                NavigationLink(destination: PerfumeDetailView(perfume: alt.perfume)) {
                                    DailyPickAlternativeCard(recommendation: alt)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer(minLength: 32)
            }
            .padding(.top, 8)
        }
        .refreshable {
            await viewModel.refreshPick(modelContext: modelContext)
        }
        .animation(.easeInOut(duration: 0.35), value: viewModel.topPick?.id)
        .animation(.easeInOut(duration: 0.35), value: viewModel.selectedOccasion)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(DesignSystem.Colors.primary)
                .scaleEffect(1.2)
            Text("Analysiere deine Sammlung…")
                .font(.system(size: 14))
                .foregroundStyle(DesignSystem.Colors.appTextSecondary)
        }
    }

    // MARK: - Empty State

    private var emptyCollectionView: some View {
        ContentUnavailableView {
            Label("Keine Parfums in der Sammlung", systemImage: "cabinet")
        } description: {
            Text("Füge Parfums zu deiner Sammlung hinzu, um tägliche Empfehlungen zu erhalten.")
        } actions: {
            Button {
                // Navigate to catalog
            } label: {
                Text("Zum Katalog")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 24)
    }
}
