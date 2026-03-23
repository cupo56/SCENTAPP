//
//  SimilarPerfumesSection.swift
//  scentboxd
//

import SwiftUI
import Nuke
import NukeUI

/// Horizontale Scroll-Section mit ähnlichen Düften in der Detailansicht.
struct SimilarPerfumesSection: View {
    let service: SimilarPerfumesService

    var body: some View {
        if service.isLoading {
            loadingState
        } else if !service.similarPerfumes.isEmpty {
            contentSection
        }
        // Bei leer oder Fehler: nichts anzeigen (Section versteckt)
    }

    // MARK: - Content

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundStyle(DesignSystem.Colors.champagne)

                Text("ÄHNLICHE DÜFTE")
                    .font(DesignSystem.Fonts.display(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "#94A3B8"))
                    .tracking(1.5)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(service.similarPerfumes) { perfume in
                        NavigationLink(destination: PerfumeDetailView(perfume: perfume)) {
                            SimilarPerfumeCard(perfume: perfume)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(perfume.name), \(perfume.brand?.name ?? "")")
                        .accessibilityHint("Öffnet die Detailseite")
                    }
                }
            }
        }
    }

    // MARK: - Loading

    private var loadingState: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundStyle(DesignSystem.Colors.champagne)

                Text("ÄHNLICHE DÜFTE")
                    .font(DesignSystem.Fonts.display(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "#94A3B8"))
                    .tracking(1.5)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { _ in
                        placeholderCard
                    }
                }
            }
        }
    }

    private var placeholderCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 8)
                .fill(DesignSystem.Colors.appSurface.opacity(0.6))
                .frame(width: 140, height: 180)
                .shimmer()

            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 100, height: 12)

                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 70, height: 10)
            }
            .padding(8)
        }
        .frame(width: 140)
        .background(DesignSystem.Colors.appSurface.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .accessibilityHidden(true)
    }
}

// MARK: - Similar Perfume Card

private struct SimilarPerfumeCard: View {
    let perfume: Perfume

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Bild
            Color.clear
                .frame(width: 140, height: 180)
                .overlay {
                    if let url = perfume.imageUrl {
                        let request = ImageRequest(
                            url: url,
                            processors: [.resize(size: CGSize(width: 300, height: 400), contentMode: .aspectFill)],
                            priority: .normal
                        )
                        LazyImage(request: request) { state in
                            if let image = state.image {
                                image
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                DesignSystem.Colors.appSurface
                            }
                        }
                        .transition(.opacity)
                    } else {
                        ZStack {
                            DesignSystem.Colors.appSurface
                            Image(systemName: "flame.circle.fill")
                                .resizable()
                                .frame(width: 32, height: 32)
                                .foregroundColor(DesignSystem.Colors.primary.opacity(0.3))
                        }
                    }
                }
                .clipped()

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(perfume.name)
                    .font(DesignSystem.Fonts.serif(size: 13, weight: .bold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                Text(perfume.brand?.name ?? "")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.primary.opacity(0.8))
                    .lineLimit(1)

                if let concentration = perfume.concentration, !concentration.isEmpty {
                    Text(concentration.uppercased())
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DesignSystem.Colors.primary.opacity(0.1))
                        .cornerRadius(3)
                }
            }
            .padding(8)
        }
        .frame(width: 140)
        .background(DesignSystem.Colors.appSurface.opacity(0.6))
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DesignSystem.Colors.primary.opacity(0.1), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
