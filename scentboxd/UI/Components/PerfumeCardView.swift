//
//  PerfumeCardView.swift
//  scentboxd
//
//  Unified card component for perfume display (grid/list).
//

import SwiftUI
import Nuke
import NukeUI

struct PerfumeCardView: View {
    let perfume: Perfume
    var ratingStats: RatingStats?
    var isFavorite: Bool = false
    var showTopNotes: Bool = true
    
    @Environment(CompareSelectionManager.self) private var compareManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image Section
            ZStack(alignment: .topLeading) {
                Color.clear
                    .aspectRatio(3/4, contentMode: .fit)
                    .overlay {
                        if let url = perfume.imageUrl {
                            let request = ImageRequest(
                                url: url,
                                processors: [.resize(size: CGSize(width: 300, height: 400), contentMode: .aspectFill)],
                                priority: .high
                            )
                            LazyImage(request: request) { state in
                                if let image = state.image {
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    DesignSystem.Colors.surfaceDark
                                }
                            }
                            .transition(.opacity)
                        } else {
                            ZStack {
                                DesignSystem.Colors.surfaceDark
                                Image(systemName: "flame.circle.fill")
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(DesignSystem.Colors.primary.opacity(0.3))
                            }
                        }
                    }
                    .clipped()
                
                // Gradient overlay
                LinearGradient(
                    colors: [Color.black.opacity(0.5), .clear, .clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .allowsHitTesting(false)
                
                // Compare button (top leading)
                Button {
                    withAnimation(.snappy) {
                        compareManager.toggle(perfume)
                    }
                } label: {
                    Image(systemName: compareManager.isSelected(perfume) ? "checkmark.circle.fill" : "plus.circle")
                        .font(.system(size: 22))
                        .foregroundColor(compareManager.isSelected(perfume) ? DesignSystem.Colors.champagne : .white.opacity(0.7))
                        .background(Circle().fill(Color.black.opacity(0.3)).padding(2))
                        .padding(8)
                }
                .accessibilityLabel(compareManager.isSelected(perfume) ? "Aus Vergleich entfernen" : "Zum Vergleich hinzufügen")
                
                // Favorite heart (top trailing)
                if isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 20))
                        .foregroundColor(DesignSystem.Colors.primary)
                        .padding(8)
                        .background(Color.black.opacity(0.2))
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .accessibilityLabel("Als Favorit markiert")
                }
            }
            
            // Info Section
            VStack(alignment: .leading, spacing: 4) {
                if let stats = ratingStats, stats.reviewCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.primary)
                        Text(String(format: "%.1f", stats.avgRating))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.primary)
                    }
                }
                
                Text(perfume.name)
                    .font(DesignSystem.Fonts.serif(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(perfume.brand?.name ?? String(localized: "Unbekannte Marke"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.primary.opacity(0.8))
                    .lineLimit(1)
                
                if showTopNotes && !perfume.topNotes.isEmpty {
                    Text(perfume.topNotes.map(\.name).joined(separator: ", "))
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: "#94A3B8"))
                        .lineLimit(1)
                        .padding(.top, 1)
                }
                
                if let concentration = perfume.concentration, !concentration.isEmpty {
                    Text(concentration.uppercased())
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(DesignSystem.Colors.primary.opacity(0.1))
                        .cornerRadius(4)
                        .padding(.top, 4)
                }
            }
            .padding(10)
        }
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DesignSystem.Colors.primary.opacity(0.1), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(perfume.name) von \(perfume.brand?.name ?? String(localized: "Unbekannte Marke"))")
        .accessibilityHint(String(localized: "Doppeltippen für Details"))
    }
}
