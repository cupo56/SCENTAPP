import SwiftUI

enum DesignSystem {
    // MARK: - Colors
    enum Colors {
        static let primary = Color(hex: "#C20A66")        // Magenta
        static let champagne = Color(hex: "#F7E7CE")      // Champagne Gold
        static let charcoal = Color(hex: "#36454F")       // Charcoal
        
        static let bgLight = Color(hex: "#F8F5F7")        // Light Background
        static let bgDark = Color(hex: "#221019")         // Dark Background
        static let surfaceDark = Color(hex: "#2E1A24")    // Dark Surface Menu/Cards
        
        // Gradient
        static let textGradientGold = LinearGradient(
            colors: [Color(hex: "#F7E7CE"), Color(hex: "#CBBCA5")],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // MARK: - Typography (Note: Info.plist needs the font files to actually render)
    enum Fonts {
        static func display(size: CGFloat, weight: Font.Weight = .regular) -> Font {
            // Placeholder for "Manrope"
            .system(size: size, weight: weight, design: .default)
        }
        
        static func serif(size: CGFloat, weight: Font.Weight = .regular) -> Font {
            // Placeholder for "Playfair Display"
            .system(size: size, weight: weight, design: .serif)
        }
    }
}

// MARK: - Modifiers

struct GlassPanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(DesignSystem.Colors.surfaceDark.opacity(0.6))
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

extension View {
    /// Wendet den Glassmorphism-Look an (wie .glass-panel im HTML)
    func glassPanel() -> some View {
        self.modifier(GlassPanelModifier())
    }
}

// MARK: - Primary Button Style

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Fonts.display(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 32)
            .frame(height: 48)
            .background(DesignSystem.Colors.primary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: DesignSystem.Colors.primary.opacity(0.3), radius: 10, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Color Hex Helper

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
