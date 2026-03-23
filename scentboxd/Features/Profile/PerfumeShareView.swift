//
//  PerfumeShareView.swift
//  scentboxd
//

import SwiftUI

/// Share-Karte für ein einzelnes Parfum — wird via ImageRenderer als Bild gerendert.
struct PerfumeShareView: View {
    let perfume: Perfume
    let perfumeImage: UIImage?

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Bild
            ZStack {
                Color(hex: "#2E1A24")

                if let perfumeImage {
                    Image(uiImage: perfumeImage)
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(width: 400, height: 400)
            .clipped()

            // MARK: - Info
            VStack(spacing: 10) {
                // Brand
                Text((perfume.brand?.name ?? "").uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Color(hex: "#C20A66"))

                // Name
                Text(perfume.name)
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                // Badges
                HStack(spacing: 10) {
                    if let concentration = perfume.concentration, !concentration.isEmpty {
                        badgeText(concentration.uppercased())
                    }
                    if !perfume.longevity.isEmpty {
                        badgeText(perfume.longevity)
                    }
                    if !perfume.sillage.isEmpty {
                        badgeText(perfume.sillage)
                    }
                }

                // Duftpyramide — 3 Spalten nebeneinander
                if !perfume.topNotes.isEmpty || !perfume.midNotes.isEmpty || !perfume.baseNotes.isEmpty {
                    HStack(alignment: .top, spacing: 16) {
                        if !perfume.topNotes.isEmpty {
                            noteColumn(label: "KOPF", notes: perfume.topNotes)
                        }
                        if !perfume.midNotes.isEmpty {
                            noteColumn(label: "HERZ", notes: perfume.midNotes)
                        }
                        if !perfume.baseNotes.isEmpty {
                            noteColumn(label: "BASIS", notes: perfume.baseNotes)
                        }
                    }
                    .padding(.top, 6)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)

            // MARK: - Footer
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 24)

            HStack {
                Image(systemName: "drop.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#C20A66"))
                Text("scentboxd.app")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "#94A3B8"))
                    .tracking(1)
            }
            .padding(.vertical, 14)
        }
        .background(Color(hex: "#221019"))
    }

    private func badgeText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(Color(hex: "#C20A66"))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(hex: "#C20A66").opacity(0.15))
            .clipShape(Capsule())
    }

    private func noteColumn(label: String, notes: [Note]) -> some View {
        VStack(spacing: 5) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1.5)
                .foregroundColor(Color(hex: "#94A3B8"))

            ForEach(notes.prefix(4), id: \.id) { note in
                Text(note.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "#F7E7CE"))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
