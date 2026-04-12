//
//  CollectionAnalyticsView.swift
//  scentboxd
//
//  Dashboard mit Statistiken zur eigenen Sammlung. Verwendet rein lokale
//  Daten aus SwiftData (kein Server-Call) und Swift Charts fuer die Visualisierung.
//

import SwiftUI
import SwiftData
import Auth

struct CollectionAnalyticsView: View {
    @Environment(AuthManager.self) private var authManager

    @Query(filter: #Predicate<Perfume> { perfume in
        perfume.userMetadata?.isOwned == true
    }, sort: \Perfume.name)
    private var ownedPerfumes: [Perfume]

    @Query private var allReviews: [Review]

    private let analyticsService = CollectionAnalyticsService()

    private var userReviews: [Review] {
        guard let userId = authManager.currentUser?.id else { return [] }
        return allReviews.filter { $0.userId == userId }
    }

    private var analytics: CollectionAnalytics {
        analyticsService.calculateAnalytics(from: ownedPerfumes, userReviews: userReviews)
    }

    var body: some View {
        ZStack {
            DesignSystem.Colors.appBackground.ignoresSafeArea()

            if analytics.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .navigationTitle("Sammlung in Zahlen")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Content

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                header
                statCardsGrid

                if !analytics.topBrands.isEmpty {
                    section(title: "Top 5 Marken", icon: "crown.fill") {
                        TopBrandsChart(brands: analytics.topBrands)
                    }
                }

                if !analytics.concentrationDistribution.isEmpty {
                    section(title: "Konzentrationen", icon: "drop.fill") {
                        ConcentrationDonut(distribution: analytics.concentrationDistribution)
                    }
                }

                if !analytics.topNotes.isEmpty {
                    section(title: "Top 10 Noten", icon: "leaf.fill") {
                        NoteCloud(notes: analytics.topNotes)
                    }
                }

                if analytics.monthlyAdditions.contains(where: { $0.count > 0 }) {
                    section(title: "Neuzugaenge (12 Monate)", icon: "calendar") {
                        CollectionTimeline(monthlyAdditions: analytics.monthlyAdditions)
                    }
                }

                if !analytics.longevityDistribution.isEmpty || !analytics.sillageDistribution.isEmpty {
                    performanceSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            Text("Deine Sammlung in Zahlen")
                .font(DesignSystem.Fonts.serif(size: 22, weight: .semibold))
                .foregroundStyle(Color.primary)
            Text("Eine kleine Reise durch deine Duftwelt.")
                .font(.system(size: 13))
                .foregroundStyle(DesignSystem.Colors.appTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Stat Cards Grid

    private var statCardsGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]

        return LazyVGrid(columns: columns, spacing: 12) {
            statCard(
                value: "\(analytics.totalPerfumes)",
                label: "Parfums",
                icon: "drop.halffull",
                tint: DesignSystem.Colors.primary
            )
            statCard(
                value: "\(analytics.totalBrands)",
                label: "Marken",
                icon: "tag.fill",
                tint: DesignSystem.Colors.champagne
            )
            statCard(
                value: analytics.totalReviews > 0 ? String(format: "%.1f", analytics.averageRating) : "—",
                label: "Bewertung",
                icon: "star.fill",
                tint: Color(hex: "#F59E0B")
            )
            statCard(
                value: "\(analytics.totalReviews)",
                label: "Reviews",
                icon: "text.bubble.fill",
                tint: Color(hex: "#0EA5E9")
            )
        }
    }

    private func statCard(value: String, label: LocalizedStringKey, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(tint.opacity(0.12))
                    .clipShape(Circle())
                Spacer()
            }
            Text(value)
                .font(DesignSystem.Fonts.serif(size: 26, weight: .semibold))
                .foregroundStyle(Color.primary)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.appTextSecondary)
                .textCase(.uppercase)
                .tracking(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel()
    }

    // MARK: - Performance Section

    private var performanceSection: some View {
        section(title: "Performance", icon: "speedometer") {
            VStack(spacing: 16) {
                if !analytics.longevityDistribution.isEmpty {
                    histogramRow(title: "Haltbarkeit", distribution: analytics.longevityDistribution)
                }
                if !analytics.sillageDistribution.isEmpty {
                    histogramRow(title: "Sillage", distribution: analytics.sillageDistribution)
                }
            }
        }
    }

    private func histogramRow(title: LocalizedStringKey, distribution: [Int: Int]) -> some View {
        let maxCount = distribution.values.max() ?? 1
        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.appTextSecondary)
                .textCase(.uppercase)
                .tracking(1)
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(1...5, id: \.self) { value in
                    let count = distribution[value] ?? 0
                    let ratio = maxCount > 0 ? CGFloat(count) / CGFloat(maxCount) : 0
                    VStack(spacing: 4) {
                        Text("\(count)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.appTextSecondary)
                            .opacity(count > 0 ? 1 : 0.3)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(DesignSystem.Colors.primary.gradient)
                            .frame(height: max(8, ratio * 60))
                            .opacity(count > 0 ? 1 : 0.15)
                        Text("\(value)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.primary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Section Wrapper

    @ViewBuilder
    private func section<Content: View>(title: LocalizedStringKey, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.champagne)
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.appTextSecondary)
                    .textCase(.uppercase)
                    .tracking(1.2)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Sammlung ist leer", systemImage: "chart.bar.xaxis")
        } description: {
            Text("Fuege Parfums zu deiner Sammlung hinzu, um Statistiken zu sehen.")
        }
    }
}

#Preview {
    NavigationStack {
        CollectionAnalyticsView()
    }
}
