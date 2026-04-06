//
//  DailyPickAlternativeCard.swift
//  scentboxd
//
//  Kompakte Card für alternative Parfum-Empfehlungen.
//

import SwiftUI
import NukeUI

struct DailyPickAlternativeCard: View {
    let recommendation: RecommendedPerfume

    var body: some View {
        HStack(spacing: 12) {
            // Parfum-Bild
            ZStack {
                if let url = recommendation.perfume.imageUrl {
                    Color.clear
                        .frame(width: 70, height: 90)
                        .overlay {
                            LazyImage(url: url) { state in
                                if let image = state.image {
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    imagePlaceholder
                                }
                            }
                            .transition(.opacity)
                        }
                        .clipped()
                } else {
                    imagePlaceholder
                        .frame(width: 70, height: 90)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.perfume.name)
                    .font(DesignSystem.Fonts.serif(size: 15, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.appText)
                    .lineLimit(1)

                if let brand = recommendation.perfume.brand?.name {
                    Text(brand)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.primary.opacity(0.8))
                        .lineLimit(1)
                }

                Text(recommendation.reason)
                    .font(.system(size: 11))
                    .foregroundStyle(DesignSystem.Colors.appTextSecondary)
                    .lineLimit(2)
            }

            Spacer()

            // Match Percentage
            VStack(spacing: 2) {
                Text("\(recommendation.matchPercentage)%")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(DesignSystem.Colors.primary)

                Text("Match")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.appTextSecondary)
                    .textCase(.uppercase)
            }
        }
        .padding(12)
        .glassPanel()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(recommendation.perfume.name), \(recommendation.matchPercentage) Prozent Match")
        .accessibilityHint("Doppeltippen für Details")
    }

    private var imagePlaceholder: some View {
        ZStack {
            DesignSystem.Colors.appSurface
            Image(systemName: "flame.circle.fill")
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundColor(DesignSystem.Colors.primary.opacity(0.3))
        }
    }
}
