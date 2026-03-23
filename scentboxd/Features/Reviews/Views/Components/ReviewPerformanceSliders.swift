import SwiftUI

struct ReviewPerformanceSliders: View {
    @Binding var longevity: Double
    @Binding var sillage: Double

    var body: some View {
        VStack(spacing: 24) {
            // Longevity
            VStack(spacing: 16) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .foregroundColor(DesignSystem.Colors.champagne)
                        Text("Haltbarkeit")
                            .foregroundColor(.white)
                            .fontWeight(.medium)
                    }
                    Spacer()
                    Text(longevityText)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(DesignSystem.Colors.primary.opacity(0.1))
                        .cornerRadius(4)
                }
                
                Slider(value: $longevity, in: 0...100)
                    .tint(DesignSystem.Colors.champagne)
                    .accessibilityLabel("Haltbarkeit")
                    .accessibilityValue(longevityText)
                
                HStack {
                    Text("Flüchtig")
                    Spacer()
                    Text("Ewig")
                }
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#94A3B8"))
            }
            .padding(20)
            .glassPanel()
            
            // Sillage
            VStack(spacing: 16) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "wind")
                            .foregroundColor(DesignSystem.Colors.champagne)
                        Text("Sillage")
                            .foregroundColor(.white)
                            .fontWeight(.medium)
                    }
                    Spacer()
                    Text(sillageText)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(DesignSystem.Colors.primary.opacity(0.1))
                        .cornerRadius(4)
                }
                
                Slider(value: $sillage, in: 0...100)
                    .tint(DesignSystem.Colors.champagne)
                    .accessibilityLabel("Sillage")
                    .accessibilityValue(sillageText)
                
                HStack {
                    Text("Hautnah")
                    Spacer()
                    Text("Raumfüllend")
                }
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#94A3B8"))
            }
            .padding(20)
            .glassPanel()
        }
    }

    private var longevityText: String {
        if longevity < 33 { return String(localized: "Flüchtig") }
        if longevity < 66 { return String(localized: "Moderat") }
        return String(localized: "Ewig")
    }

    private var sillageText: String {
        if sillage < 33 { return String(localized: "Hautnah") }
        if sillage < 66 { return String(localized: "Moderat") }
        return String(localized: "Raumfüllend")
    }
}
