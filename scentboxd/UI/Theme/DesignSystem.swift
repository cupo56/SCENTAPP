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
        
        // Scent Family Colors
        static let scentFamilyColors: [String: Color] = [
            "Floral":    Color(hex: "#FFB6C1"),
            "Woody":     Color(hex: "#8B7355"),
            "Oriental":  Color(hex: "#DAA520"),
            "Fresh":     Color(hex: "#98FB98"),
            "Citrus":    Color(hex: "#FFD700"),
            "Gourmand":  Color(hex: "#D2691E"),
            "Aquatic":   Color(hex: "#87CEEB"),
            "Green":     Color(hex: "#3CB371"),
            "Spicy":     Color(hex: "#CD5C5C"),
            "Musky":     Color(hex: "#C0C0C0")
        ]

        static func scentFamily(_ family: String) -> Color {
            scentFamilyColors[family] ?? Color(hex: "#94A3B8")
        }

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
        let alpha, red, green, blue: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (alpha, red, green, blue) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (alpha, red, green, blue) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (alpha, red, green, blue) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (alpha, red, green, blue) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: Double(alpha) / 255
        )
    }
}
