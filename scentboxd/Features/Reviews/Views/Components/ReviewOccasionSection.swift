import SwiftUI

struct ReviewOccasionSection: View {
    @Binding var selectedOccasions: [String]

    private let occasions: [(label: String, icon: String)] = [
        ("Arbeit",   "briefcase.fill"),
        ("Date",     "heart.fill"),
        ("Casual",   "person.fill"),
        ("Sport",    "figure.run"),
        ("Abend",    "moon.fill"),
        ("Formal",   "building.columns.fill"),
        ("Outdoor",  "leaf.fill"),
        ("Zuhause",  "house.fill")
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ANLASS")
                .font(.system(size: 12, weight: .bold))
                .tracking(1)
                .foregroundColor(Color(hex: "#94A3B8"))
                .padding(.leading, 4)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(occasions, id: \.label) { occasion in
                    let isSelected = selectedOccasions.contains(occasion.label)
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if isSelected {
                                selectedOccasions.removeAll { $0 == occasion.label }
                            } else {
                                selectedOccasions.append(occasion.label)
                            }
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: occasion.icon)
                                .font(.system(size: 16))
                            Text(occasion.label)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                        }
                        .foregroundColor(isSelected ? .white : Color(hex: "#94A3B8"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.appSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    isSelected ? DesignSystem.Colors.primary : Color.primary.opacity(0.08),
                                    lineWidth: 1
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .accessibilityLabel("\(occasion.label), \(isSelected ? "ausgewählt" : "nicht ausgewählt")")
                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
        .padding(20)
        .glassPanel()
    }
}
