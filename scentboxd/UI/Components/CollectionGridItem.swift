//
//  CollectionGridItem.swift
//  scentboxd
//
//  Created by Cupo.
//

import SwiftUI
import Nuke
import NukeUI

struct CollectionGridItem: View {
    let perfume: Perfume
    var isFavorite: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Image Area
            ZStack(alignment: .topTrailing) {
                Color.clear
                    .aspectRatio(3/4, contentMode: .fill)
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
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Overlay Gradient
                LinearGradient(
                    colors: [Color.black.opacity(0.6), .clear, .clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Favorite Icon overlay
                if isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 20))
                        .foregroundColor(DesignSystem.Colors.primary)
                        .padding(8)
                        .background(Color.black.opacity(0.2))
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .padding(12)
                }
            }
            .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
            
            // Text Info
            VStack(alignment: .leading, spacing: 4) {
                Text(perfume.brand?.name ?? String(localized: "Unbekannte Marke"))
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundColor(DesignSystem.Colors.primary)
                    .lineLimit(1)
                
                Text(perfume.name)
                    .font(DesignSystem.Fonts.display(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                if let concentration = perfume.concentration, !concentration.isEmpty {
                    Text(concentration)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#94A3B8"))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 4)
        }
    }
}
