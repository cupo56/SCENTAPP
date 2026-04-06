//
//  RecommendationCard.swift
//  scentboxd
//

import SwiftUI
import NukeUI
import Nuke

/// Karte für eine einzelne Parfum-Empfehlung.
struct RecommendationCard: View {
    let recommendation: RecommendationEngine.RecommendedPerfume
    let onNotInterested: () -> Void

    @State private var showNotInterested = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            mainCard
            if showNotInterested {
                notInterestedOverlay
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(recommendation.perfume.name), \(recommendation.perfume.brand?.name ?? "")")
        .accessibilityHint("Empfohlen. \(recommendation.reason)")
    }

    // MARK: - Main Card

    private var mainCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Parfum-Bild
            perfumeImage

            // Info-Bereich
            VStack(alignment: .leading, spacing: 6) {
                Text(recommendation.perfume.name)
                    .font(DesignSystem.Fonts.serif(size: 14, weight: .bold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(recommendation.perfume.brand?.name ?? "")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.primary.opacity(0.8))
                    .lineLimit(1)

                // Begründung
                Text(recommendation.reason)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(DesignSystem.Colors.appTextSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                matchScoreBar
            }
            .padding(10)
        }
        .frame(width: 160)
        .background(DesignSystem.Colors.appSurface.opacity(0.6))
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(DesignSystem.Colors.primary.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        // "Nicht interessiert" per Long Press
        .contextMenu {
            Button(role: .destructive) {
                withAnimation(.easeOut(duration: 0.2)) {
                    onNotInterested()
                }
            } label: {
                Label("Nicht interessiert", systemImage: "hand.thumbsdown")
            }
        }
    }

    // MARK: - Bild

    private var perfumeImage: some View {
        Color.clear
            .frame(width: 160, height: 200)
            .overlay {
                if let url = recommendation.perfume.imageUrl {
                    let request = ImageRequest(
                        url: url,
                        processors: [.resize(
                            size: CGSize(width: 320, height: 400),
                            contentMode: .aspectFill
                        )],
                        priority: .normal
                    )
                    LazyImage(request: request) { state in
                        if let image = state.image {
                            image
                                .resizable()
                                .scaledToFill()
                        } else {
                            imagePlaceholder
                        }
                    }
                    .transition(.opacity)
                } else {
                    imagePlaceholder
                }
            }
            .clipped()
    }

    private var imagePlaceholder: some View {
        ZStack {
            DesignSystem.Colors.appSurface
            Image(systemName: "flame.circle.fill")
                .resizable()
                .frame(width: 36, height: 36)
                .foregroundColor(DesignSystem.Colors.primary.opacity(0.25))
        }
    }

    // MARK: - Match-Score Balken

    private var matchScoreBar: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: "waveform.path")
                    .font(.system(size: 8))
                    .foregroundStyle(DesignSystem.Colors.primary)
                Text("Match \(Int(recommendation.score * 100))%")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.primary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(DesignSystem.Colors.primary.opacity(0.12))
                        .frame(height: 3)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [DesignSystem.Colors.primary, DesignSystem.Colors.champagne],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * recommendation.score, height: 3)
                }
            }
            .frame(height: 3)
        }
    }

    // MARK: - Not Interested Overlay

    private var notInterestedOverlay: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color.black.opacity(0.5))
            .frame(width: 160)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "hand.thumbsdown.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                    Text("Nicht interessiert")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
    }
}
