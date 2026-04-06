//
//  DailyPickHeroCard.swift
//  scentboxd
//
//  Große Hero-Card für die tägliche Parfum-Empfehlung.
//

import SwiftUI
import NukeUI

struct DailyPickHeroCard: View {
    let recommendation: RecommendedPerfume

    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image Section
            ZStack(alignment: .bottomLeading) {
                Color.clear
                    .aspectRatio(4/5, contentMode: .fit)
                    .overlay {
                        if let url = recommendation.perfume.imageUrl {
                            LazyImage(url: url) { state in
                                if let image = state.image {
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } else if state.isLoading {
                                    DesignSystem.Colors.appSurface
                                        .overlay {
                                            ProgressView()
                                                .tint(DesignSystem.Colors.primary)
                                        }
                                } else {
                                    perfumePlaceholder
                                }
                            }
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        } else {
                            perfumePlaceholder
                        }
                    }
                    .clipped()

                // Gradient Overlay
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.3),
                        .init(color: Color.black.opacity(0.7), location: 0.85),
                        .init(color: Color.black.opacity(0.9), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Match Badge (top right)
                VStack {
                    HStack {
                        Spacer()
                        matchBadge
                            .padding(12)
                    }
                    Spacer()
                }

                // Bottom Info
                VStack(alignment: .leading, spacing: 6) {
                    // Name
                    Text(recommendation.perfume.name)
                        .font(DesignSystem.Fonts.serif(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    // Brand
                    if let brand = recommendation.perfume.brand?.name {
                        Text(brand)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.primary)
                    }

                    // Concentration Badge
                    if let concentration = recommendation.perfume.concentration, !concentration.isEmpty {
                        Text(concentration.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.white.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
                .padding(20)
            }

            // Reason Section
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.Colors.champagne)
                    Text("Warum dieser Duft?")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.champagne)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }

                Text(recommendation.reason)
                    .font(.system(size: 14))
                    .foregroundStyle(DesignSystem.Colors.appTextSecondary)
                    .lineLimit(2)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignSystem.Colors.appSurface.opacity(0.6))
            .background(.ultraThinMaterial)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(DesignSystem.Colors.primary.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: DesignSystem.Colors.primary.opacity(0.15), radius: 20, y: 10)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isPressed)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tagesempfehlung: \(recommendation.perfume.name) von \(recommendation.perfume.brand?.name ?? "Unbekannt"), \(recommendation.matchPercentage) Prozent Übereinstimmung")
        .accessibilityHint("Doppeltippen für Details")
    }

    // MARK: - Sub-Views

    private var matchBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 11))
            Text("\(recommendation.matchPercentage)%")
                .font(.system(size: 14, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(DesignSystem.Colors.primary)
                .shadow(color: DesignSystem.Colors.primary.opacity(0.5), radius: 8, y: 2)
        )
    }

    private var perfumePlaceholder: some View {
        ZStack {
            DesignSystem.Colors.appSurface
            VStack(spacing: 8) {
                Image(systemName: "flame.circle.fill")
                    .resizable()
                    .frame(width: 50, height: 50)
                    .foregroundColor(DesignSystem.Colors.primary.opacity(0.3))
                Text("Kein Bild")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Colors.appTextSecondary)
            }
        }
    }
}
