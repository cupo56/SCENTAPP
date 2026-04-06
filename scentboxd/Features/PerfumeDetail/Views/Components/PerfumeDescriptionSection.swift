import SwiftUI

struct PerfumeDescriptionSection: View {
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Über den Duft")
                .font(DesignSystem.Fonts.serif(size: 20, weight: .semibold))
                .foregroundStyle(Color.primary)
            Text(description)
                .font(.subheadline)
                .foregroundColor(Color(hex: "#94A3B8"))
                .lineSpacing(6)
        }
    }
}
