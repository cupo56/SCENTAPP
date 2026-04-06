//
//  OccasionChipBar.swift
//  scentboxd
//
//  Horizontale ScrollView mit Occasion-Chips.
//

import SwiftUI

struct OccasionChipBar: View {
    @Binding var selectedOccasion: Occasion
    var onSelect: ((Occasion) -> Void)?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Occasion.allCases) { occasion in
                    OccasionChip(
                        occasion: occasion,
                        isSelected: selectedOccasion == occasion
                    ) {
                        withAnimation(.snappy(duration: 0.25)) {
                            selectedOccasion = occasion
                        }
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        onSelect?(occasion)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Single Chip

private struct OccasionChip: View {
    let occasion: Occasion
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: occasion.systemImage)
                    .font(.system(size: 12, weight: .semibold))

                Text(occasion.displayName)
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(isSelected ? .white : DesignSystem.Colors.appTextSecondary)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(DesignSystem.Colors.primary)
                        .shadow(color: DesignSystem.Colors.primary.opacity(0.4), radius: 8, y: 2)
                } else {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(DesignSystem.Colors.appSurface.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                }
            }
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.easeOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(occasion.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
