import SwiftUI

struct ProfileStatsCard: View {
    let icon: String
    let value: String
    let label: String
    var showGradientOverlay: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(DesignSystem.Colors.primary.opacity(0.8))
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: "#475569"))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(DesignSystem.Fonts.serif(size: 28, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.champagne)
                    .shadow(color: DesignSystem.Colors.primary.opacity(0.3), radius: 10, x: 0, y: 0)
                
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.5)
                    .foregroundColor(Color(hex: "#94A3B8"))
            }
        }
        .padding(20)
        .background {
            if showGradientOverlay {
                LinearGradient(
                    colors: [DesignSystem.Colors.primary.opacity(0.08), .clear],
                    startPoint: .bottomLeading,
                    endPoint: .topTrailing
                )
            }
        }
        .glassPanel()
    }
}
