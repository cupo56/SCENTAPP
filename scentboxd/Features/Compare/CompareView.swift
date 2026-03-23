import SwiftUI

struct CompareView: View {
    let perfumes: [Perfume]

    @State private var commonNotes: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Intro Text
                Text("Duft-Vergleich")
                    .font(DesignSystem.Fonts.serif(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 16)
                
                Text("Vergleiche Noten, Performance und Konzentration Seite an Seite.")
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "#94A3B8"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Compare Grid
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(perfumes, id: \.id) { perfume in
                            CompareColumnView(perfume: perfume, commonNotes: commonNotes)
                        }
                    }
                    // Zentriere den Inhalt wenn möglich
                    .frame(minWidth: UIScreen.main.bounds.width - 32, alignment: .center)
                    .padding(.horizontal, 16)
                }
                
                Spacer(minLength: 40)
            }
        }
        .background(DesignSystem.Colors.bgDark)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { commonNotes = Self.computeCommonNotes(perfumes) }
        .onChange(of: perfumes.map(\.id)) { _, _ in commonNotes = Self.computeCommonNotes(perfumes) }
    }

    private static func computeCommonNotes(_ perfumes: [Perfume]) -> Set<String> {
        guard let first = perfumes.first else { return [] }

        var common = Set(
            first.topNotes.map(\.name) +
            first.midNotes.map(\.name) +
            first.baseNotes.map(\.name)
        )

        for perfume in perfumes.dropFirst() {
            let notes = Set(
                perfume.topNotes.map(\.name) +
                perfume.midNotes.map(\.name) +
                perfume.baseNotes.map(\.name)
            )
            common.formIntersection(notes)
        }

        return common
    }
}
