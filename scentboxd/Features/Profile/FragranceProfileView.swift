//
//  FragranceProfileView.swift
//  scentboxd
//

import SwiftUI
import Charts

struct FragranceProfileView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var service: FragranceProfileService
    @State private var scentWheelService: ScentWheelService
    @State private var profileTask: Task<Void, Never>?

    init(service: FragranceProfileService, scentWheelService: ScentWheelService) {
        _service = State(initialValue: service)
        _scentWheelService = State(initialValue: scentWheelService)
    }

    var body: some View {
        ZStack {
            DesignSystem.Colors.appBackground.ignoresSafeArea()

            if service.isLoading {
                loadingView
            } else if let profile = service.profile, !profile.isEmpty {
                contentView(profile)
            } else if service.errorMessage != nil {
                errorView
            } else {
                emptyView
            }
        }
        .navigationTitle("Duftprofil")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            profileTask = Task {
                async let profileLoad: Void = service.loadProfile()
                async let wheelLoad: Void = scentWheelService.loadScentWheel()
                _ = await (profileLoad, wheelLoad)
            }
        }
        .onDisappear {
            profileTask?.cancel()
        }
        .errorAlert("Fehler", isPresented: $service.showErrorAlert, message: service.errorMessage) {
            await service.loadProfile()
        }
    }

    // MARK: - Content

    private func contentView(_ profile: FragranceProfileDTO) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection(profile)
                if !scentWheelService.segments.isEmpty {
                    ScentWheelView(segments: scentWheelService.segments)
                }
                topNotesSection(profile.topNotes)
                concentrationsSection(profile.concentrations)
                ratingsSection(profile)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Header

    private func headerSection(_ profile: FragranceProfileDTO) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(
                        colors: [DesignSystem.Colors.primary, Color(hex: "#fb7185")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Text("Dein Duftprofil")
                .font(DesignSystem.Fonts.serif(size: 28, weight: .bold))
                .foregroundStyle(Color.primary)

            Text("Basierend auf deinen Favoriten und deiner Sammlung")
                .font(DesignSystem.Fonts.display(size: 13))
                .foregroundStyle(Color(hex: "#94A3B8"))
                .multilineTextAlignment(.center)

            // Summary Stats
            HStack(spacing: 32) {
                summaryItem(value: "\(profile.totalCollectionCount)", label: String(localized: "Düfte"))
                summaryItem(value: "\(profile.totalReviewCount)", label: String(localized: "Reviews"))
                if profile.avgRating > 0 {
                    summaryItem(value: String(format: "%.1f", profile.avgRating), label: String(localized: "Ø Rating"))
                }
            }
            .padding(.top, 8)
        }
        .padding(.top, 16)
    }

    private func summaryItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(DesignSystem.Fonts.serif(size: 22, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.champagne)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color(hex: "#94A3B8"))
                .tracking(1.2)
        }
    }

    // MARK: - Top Notes

    private func topNotesSection(_ notes: [FragranceProfileDTO.NoteCount]) -> some View {
        Group {
            if !notes.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader(icon: "leaf", title: "TOP-NOTEN")

                    let maxCount = notes.map(\.count).max() ?? 1
                    ForEach(notes) { note in
                        HStack(spacing: 12) {
                            Text(note.name)
                                .font(DesignSystem.Fonts.display(size: 14))
                                .foregroundStyle(Color.primary)
                                .frame(width: 100, alignment: .leading)

                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [DesignSystem.Colors.primary, Color(hex: "#fb7185")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * CGFloat(note.count) / CGFloat(maxCount))
                            }
                            .frame(height: 20)

                            Text("\(note.count)")
                                .font(DesignSystem.Fonts.display(size: 13, weight: .semibold))
                                .foregroundStyle(DesignSystem.Colors.champagne)
                                .frame(width: 28, alignment: .trailing)
                        }
                    }
                }
                .padding(16)
                .glassPanel()
            }
        }
    }

    // MARK: - Concentrations

    private static let chartColors: [Color] = [
        DesignSystem.Colors.primary,
        DesignSystem.Colors.champagne,
        Color(hex: "#94A3B8"),
        Color(hex: "#fb7185"),
        Color(hex: "#60A5FA")
    ]

    private func concentrationsSection(_ concentrations: [FragranceProfileDTO.ConcentrationCount]) -> some View {
        Group {
            if !concentrations.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader(icon: "drop", title: "KONZENTRATIONEN")

                    Chart(concentrations) { item in
                        SectorMark(
                            angle: .value("Anzahl", item.count),
                            innerRadius: .ratio(0.55),
                            angularInset: 2
                        )
                        .foregroundStyle(Self.chartColors[min(concentrations.firstIndex(where: { $0.id == item.id }) ?? 0, Self.chartColors.count - 1)])
                        .cornerRadius(4)
                    }
                    .frame(height: 180)

                    // Legend
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(concentrations.enumerated()), id: \.element.id) { index, item in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Self.chartColors[min(index, Self.chartColors.count - 1)])
                                    .frame(width: 10, height: 10)
                                Text(item.type)
                                    .font(DesignSystem.Fonts.display(size: 13))
                                    .foregroundStyle(Color.primary)
                                Spacer()
                                Text("\(item.count)")
                                    .font(DesignSystem.Fonts.display(size: 13, weight: .semibold))
                                    .foregroundStyle(DesignSystem.Colors.champagne)
                            }
                        }
                    }
                }
                .padding(16)
                .glassPanel()
            }
        }
    }

    // MARK: - Ratings

    private func ratingsSection(_ profile: FragranceProfileDTO) -> some View {
        Group {
            if !profile.ratingDistribution.isEmpty {
                VStack(spacing: 16) {
                    sectionHeader(icon: "star", title: "DEINE BEWERTUNGEN")

                    // Average Rating
                    VStack(spacing: 4) {
                        Text(String(format: "%.1f", profile.avgRating))
                            .font(DesignSystem.Fonts.serif(size: 36, weight: .bold))
                            .foregroundStyle(DesignSystem.Colors.champagne)
                        Text("Durchschnitt aus \(profile.totalReviewCount) Bewertungen")
                            .font(DesignSystem.Fonts.display(size: 12))
                            .foregroundStyle(Color(hex: "#94A3B8"))
                    }

                    // Distribution Chart
                    let allRatings = (1...5).map { rating in
                        let existing = profile.ratingDistribution.first { $0.rating == rating }
                        return (rating: rating, count: existing?.count ?? 0)
                    }

                    Chart(allRatings, id: \.rating) { item in
                        BarMark(
                            x: .value("Sterne", "★\(item.rating)"),
                            y: .value("Anzahl", item.count)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [DesignSystem.Colors.primary, Color(hex: "#fb7185")],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .cornerRadius(4)
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) {
                            AxisValueLabel()
                                .foregroundStyle(Color(hex: "#94A3B8"))
                        }
                    }
                    .chartXAxis {
                        AxisMarks {
                            AxisValueLabel()
                                .foregroundStyle(Color(hex: "#94A3B8"))
                        }
                    }
                    .frame(height: 160)
                }
                .padding(16)
                .glassPanel()
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(icon: String, title: LocalizedStringKey) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(title)
                .tracking(1.5)
        }
        .font(DesignSystem.Fonts.display(size: 11, weight: .semibold))
        .foregroundStyle(Color(hex: "#94A3B8"))
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(DesignSystem.Colors.primary)
            Text("Duftprofil laden...")
                .font(DesignSystem.Fonts.display(size: 14))
                .foregroundStyle(Color(hex: "#94A3B8"))
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(Color(hex: "#94A3B8"))
            Text("Noch kein Duftprofil")
                .font(DesignSystem.Fonts.serif(size: 20, weight: .bold))
                .foregroundStyle(Color.primary)
            Text("Füge Düfte zu deiner Sammlung oder deinen Favoriten hinzu, um dein persönliches Duftprofil zu sehen.")
                .font(DesignSystem.Fonts.display(size: 14))
                .foregroundStyle(Color(hex: "#94A3B8"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text(service.errorMessage ?? "Ein Fehler ist aufgetreten.")
                .font(DesignSystem.Fonts.display(size: 14))
                .foregroundStyle(Color(hex: "#94A3B8"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Erneut versuchen") {
                profileTask?.cancel()
                profileTask = Task { await service.loadProfile() }
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityHint("Doppeltippen, um das Duftprofil erneut zu laden")
        }
    }
}

#Preview {
    NavigationStack {
        FragranceProfileView(
            service: FragranceProfileService(),
            scentWheelService: ScentWheelService()
        )
        .environment(\.dependencies, DependencyContainer())
    }
}
