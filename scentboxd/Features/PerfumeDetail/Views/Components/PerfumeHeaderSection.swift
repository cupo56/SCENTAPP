import SwiftUI
import SwiftData

struct PerfumeHeaderSection: View {
    let perfume: Perfume
    let reviewService: ReviewManagementService

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(perfume.brand?.name ?? String(localized: "Unbekannte Marke"))
                .font(DesignSystem.Fonts.display(size: 13, weight: .bold))
                .tracking(2)
                .foregroundColor(DesignSystem.Colors.champagne)
                .textCase(.uppercase)
            
            Text(perfume.name)
                .font(DesignSystem.Fonts.serif(size: 34, weight: .bold))
                .foregroundStyle(Color.primary)
            
            HStack(spacing: 10) {
                // Concentration
                if let concentration = perfume.concentration, !concentration.isEmpty {
                    Text(concentration.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(DesignSystem.Colors.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(DesignSystem.Colors.primary.opacity(0.15))
                        .overlay(
                            Capsule().stroke(DesignSystem.Colors.primary.opacity(0.3), lineWidth: 1)
                        )
                        .clipShape(Capsule())
                }

                // Rating
                if let avg = reviewService.averageRating {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(DesignSystem.Colors.champagne)
                        Text(String(format: "%.1f", avg))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.primary)
                        if reviewService.reviewCount > 0 {
                            Text("(\(reviewService.reviewCount))")
                                .font(.system(size: 11))
                                .foregroundColor(Color.secondary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.08))
                    .cornerRadius(8)
                }
            }
            .padding(.top, 6)
        }
    }
}
