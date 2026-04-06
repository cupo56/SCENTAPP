import SwiftUI

struct CompareFloatingBar: View {
    @Environment(CompareSelectionManager.self) private var compareManager
    @State private var isShowingCompare = false

    var body: some View {
        HStack {
            // Count Badge
            ZStack {
                Circle()
                    .fill(Color(hex: "#C20A66"))
                    .frame(width: 24, height: 24)
                
                Text("\(compareManager.selectedPerfumes.count)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text("ausgewählt — Vergleichen")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.primary)
            
            Spacer()
            
            // Clear Button
            Button {
                withAnimation(.snappy) {
                    compareManager.clear()
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(Color.primary.opacity(0.5))
            }
            .accessibilityLabel("Auswahl löschen")
            .accessibilityHint("Entfernt alle Parfums aus dem Vergleich")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(DesignSystem.Colors.appSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(DesignSystem.Colors.champagne.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.3), radius: 10, y: 5)
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(compareManager.selectedPerfumes.count) Parfums ausgewählt")
        .accessibilityHint(compareManager.canCompare ? "Doppeltippen, um den Vergleich zu öffnen" : "Wähle mindestens 2 Parfums zum Vergleichen")
        .accessibilityAddTraits(.isButton)
        .onTapGesture {
            if compareManager.canCompare {
                isShowingCompare = true
            }
        }
        .fullScreenCover(isPresented: $isShowingCompare) {
            NavigationStack {
                CompareView(perfumes: compareManager.selectedPerfumes)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Schließen") {
                                isShowingCompare = false
                            }
                            .foregroundColor(DesignSystem.Colors.champagne)
                            .accessibilityLabel("Vergleich schließen")
                        }
                    }
            }
        }
    }
}
