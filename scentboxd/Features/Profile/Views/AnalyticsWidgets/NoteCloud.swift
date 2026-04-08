//
//  NoteCloud.swift
//  scentboxd
//
//  "Word Cloud" der haeufigsten Noten in der Sammlung. Schriftgroesse skaliert
//  proportional zur Haeufigkeit. Verwendet ein Flow-Layout, damit Tags umbrechen.
//

import SwiftUI

struct NoteCloud: View {
    let notes: [CollectionAnalytics.NoteCount]

    private var maxCount: Int {
        notes.map(\.count).max() ?? 1
    }

    private var minCount: Int {
        notes.map(\.count).min() ?? 1
    }

    var body: some View {
        NoteFlowLayout(spacing: 8) {
            ForEach(notes) { item in
                Text(item.note)
                    .font(.system(size: fontSize(for: item.count), weight: .semibold))
                    .foregroundStyle(textColor(for: item.count))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.primary.opacity(opacity(for: item.count)))
                    )
            }
        }
    }

    private func fontSize(for count: Int) -> CGFloat {
        guard maxCount > minCount else { return 14 }
        let ratio = Double(count - minCount) / Double(maxCount - minCount)
        return 12 + CGFloat(ratio) * 10 // 12pt - 22pt
    }

    private func opacity(for count: Int) -> Double {
        guard maxCount > minCount else { return 0.18 }
        let ratio = Double(count - minCount) / Double(maxCount - minCount)
        return 0.10 + ratio * 0.30
    }

    private func textColor(for count: Int) -> Color {
        guard maxCount > minCount else { return DesignSystem.Colors.primary }
        let ratio = Double(count - minCount) / Double(maxCount - minCount)
        return ratio > 0.5 ? DesignSystem.Colors.primary : Color.primary.opacity(0.85)
    }
}

// MARK: - Flow Layout

/// Einfaches Flow-Layout, das Subviews wie Word-Wrapping in mehrere Zeilen umbricht.
private struct NoteFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[CGSize]] = [[]]
        var currentRowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let widthIfAdded = currentRowWidth + size.width + (rows[rows.count - 1].isEmpty ? 0 : spacing)
            if widthIfAdded > maxWidth, !rows[rows.count - 1].isEmpty {
                totalHeight += currentRowHeight + spacing
                rows.append([])
                currentRowWidth = 0
                currentRowHeight = 0
            }
            rows[rows.count - 1].append(size)
            currentRowWidth += size.width + (rows[rows.count - 1].count > 1 ? spacing : 0)
            currentRowHeight = max(currentRowHeight, size.height)
        }
        totalHeight += currentRowHeight
        return CGSize(width: maxWidth.isFinite ? maxWidth : currentRowWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth, x > bounds.minX {
                x = bounds.minX
                y += currentRowHeight + spacing
                currentRowHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
            x += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
    }
}
