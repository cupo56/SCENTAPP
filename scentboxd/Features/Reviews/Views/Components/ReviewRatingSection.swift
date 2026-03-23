import SwiftUI

struct ReviewRatingSection: View {
    @Binding var rating: Int

    var body: some View {
        HStack(spacing: 12) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: 36))
                    .foregroundColor(star <= rating ? DesignSystem.Colors.champagne : Color.white.opacity(0.2))
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            rating = star
                        }
                    }
                    .scaleEffect(star <= rating ? 1.1 : 1.0)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Bewertung"))
        .accessibilityValue("\(rating) von 5 Sternen")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                rating = min(5, rating + 1)
            case .decrement:
                rating = max(1, rating - 1)
            @unknown default:
                break
            }
        }
    }
}
