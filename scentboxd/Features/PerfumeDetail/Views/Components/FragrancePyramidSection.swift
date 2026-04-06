import SwiftUI

struct FragrancePyramidSection: View {
    let perfume: Perfume

    var body: some View {
        if !perfume.topNotes.isEmpty || !perfume.midNotes.isEmpty || !perfume.baseNotes.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("Duftpyramide")
                    .font(DesignSystem.Fonts.serif(size: 20, weight: .semibold))
                    .foregroundStyle(Color.primary)

                VStack(spacing: 10) {
                    if !perfume.topNotes.isEmpty {
                        pyramidRow(
                            icon: "wind",
                            label: "Kopfnoten",
                            notes: perfume.topNotes.map(\.name).joined(separator: ", ")
                        )
                    }
                    if !perfume.midNotes.isEmpty {
                        pyramidRow(
                            icon: "leaf",
                            label: "Herznoten",
                            notes: perfume.midNotes.map(\.name).joined(separator: ", ")
                        )
                    }
                    if !perfume.baseNotes.isEmpty {
                        pyramidRow(
                            icon: "drop.fill",
                            label: "Basisnoten",
                            notes: perfume.baseNotes.map(\.name).joined(separator: ", ")
                        )
                    }
                }
            }
        }
    }

    private func pyramidRow(icon: String, label: String, notes: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.primary.opacity(0.7))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.5)
                    .foregroundStyle(Color.primary.opacity(0.4))
                Text(notes)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.primary)
            }

            Spacer()
        }
        .padding(14)
        .glassPanel()
    }
}
