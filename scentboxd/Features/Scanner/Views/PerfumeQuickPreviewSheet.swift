//
//  PerfumeQuickPreviewSheet.swift
//  scentboxd
//

import SwiftUI
import NukeUI
import Nuke

struct PerfumeQuickPreviewSheet: View {
    let perfume: Perfume
    let onViewDetails: () -> Void
    let onRescan: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Drag Indicator
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 40, height: 4)
                .padding(.top, 10)

            // Parfum-Info
            HStack(spacing: 16) {
                if let url = perfume.imageUrl {
                    let request = ImageRequest(
                        url: url,
                        processors: [.resize(size: CGSize(width: 80, height: 80), contentMode: .aspectFill)]
                    )
                    LazyImage(request: request) { state in
                        if let image = state.image {
                            image.resizable().scaledToFill()
                        } else {
                            DesignSystem.Colors.appSurface
                        }
                    }
                    .frame(width: 80, height: 80)
                    .cornerRadius(12)
                    .clipped()
                } else {
                    Image(systemName: "flame.circle.fill")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundColor(DesignSystem.Colors.primary.opacity(0.3))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(perfume.name)
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                    Text(perfume.brand?.name ?? String(localized: "Unbekannte Marke"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if let concentration = perfume.concentration, !concentration.isEmpty {
                        Text(concentration.uppercased())
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(DesignSystem.Colors.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(DesignSystem.Colors.primary.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 20)

            // Aktions-Buttons
            VStack(spacing: 10) {
                Button(action: onViewDetails) {
                    Label("Details ansehen", systemImage: "arrow.right.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())

                Button(action: onRescan) {
                    Label("Erneut scannen", systemImage: "barcode.viewfinder")
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(DesignSystem.Colors.appSurface)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(DesignSystem.Colors.appBackground)
    }
}
