import SwiftUI

struct PerfumePerformanceSection: View {
    let perfume: Perfume

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Performance")
                .font(DesignSystem.Fonts.serif(size: 20, weight: .semibold))
                .foregroundStyle(Color.primary)
            
            VStack(spacing: 16) {
                // Longevity
                performanceBar(
                    label: "Haltbarkeit",
                    value: perfume.longevity,
                    percentage: longevityPercentage(perfume.longevity)
                )
                
                // Sillage
                performanceBar(
                    label: "Sillage",
                    value: perfume.sillage,
                    percentage: sillagePercentage(perfume.sillage)
                )
            }
        }
        .padding(20)
        .glassPanel()
    }

    private func performanceBar(label: LocalizedStringKey, value: String, percentage: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.7))
                Spacer()
                Text(value.isEmpty ? "–" : value)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.primary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.1))
                        .frame(height: 6)
                    Capsule()
                        .fill(DesignSystem.Colors.primary)
                        .frame(width: geo.size.width * percentage, height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private func longevityPercentage(_ value: String) -> Double {
        switch value.lowercased() {
        case "sehr lang", "very long": return 0.95
        case "lang", "long": return 0.80
        case "mittel", "moderate": return 0.55
        case "kurz", "short": return 0.30
        case "sehr kurz", "very short": return 0.15
        default: return 0.5
        }
    }
    
    private func sillagePercentage(_ value: String) -> Double {
        switch value.lowercased() {
        case "enorm", "enormous": return 0.95
        case "stark", "strong": return 0.80
        case "mittel", "moderate": return 0.55
        case "leicht", "light": return 0.30
        case "intim", "intimate": return 0.15
        default: return 0.5
        }
    }
}
