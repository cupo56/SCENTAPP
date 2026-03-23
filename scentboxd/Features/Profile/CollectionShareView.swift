//
//  CollectionShareView.swift
//  scentboxd
//

import SwiftUI

/// SwiftUI-View die als Bild gerendert und geteilt wird.
/// Zeigt eine Collage der Top-Düfte mit Branding.
struct CollectionShareView: View {
    let perfumes: [Perfume]
    let username: String
    let totalCount: Int
    let favoriteCount: Int
    /// Vorab geladene Bilder — Key ist die Perfume-ID.
    let loadedImages: [UUID: UIImage]

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            VStack(spacing: 6) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: "#C20A66"))
                    .padding(.top, 20)

                Text("Meine Sammlung")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundColor(.white)

                Text("@\(username) \u{2022} scentboxd")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "#94A3B8"))
            }
            .padding(.bottom, 16)

            // MARK: - Divider
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 20)

            // MARK: - Perfume Grid
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(perfumes, id: \.id) { perfume in
                    perfumeCell(perfume)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)

            // MARK: - Divider
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 20)

            // MARK: - Footer
            VStack(spacing: 6) {
                HStack(spacing: 16) {
                    footerStat(value: "\(totalCount)", label: "Düfte")
                    footerStat(value: "\(favoriteCount)", label: "Favoriten")
                }

                Text("scentboxd.app")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "#C20A66"))
                    .tracking(1)
            }
            .padding(.vertical, 16)
        }
        .background(Color(hex: "#221019"))
    }

    // MARK: - Perfume Cell

    private func perfumeCell(_ perfume: Perfume) -> some View {
        VStack(spacing: 6) {
            // Bild — synchron aus dem vorgeladenen Dictionary
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "#2E1A24"))

                if let uiImage = loadedImages[perfume.id] {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "flame.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundColor(Color(hex: "#C20A66").opacity(0.3))
                }
            }
            .frame(height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Name
            Text(perfume.name)
                .font(.system(size: 10, weight: .semibold, design: .serif))
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            // Brand
            Text(perfume.brand?.name ?? "")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(Color(hex: "#94A3B8"))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Footer Stat

    private func footerStat(value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .serif))
                .foregroundColor(Color(hex: "#F7E7CE"))
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(hex: "#94A3B8"))
        }
    }
}

#Preview {
    CollectionShareView(
        perfumes: [],
        username: "testuser",
        totalCount: 12,
        favoriteCount: 8,
        loadedImages: [:]
    )
}
