import SwiftUI
import NukeUI

struct CompareColumnView: View {
    let perfume: Perfume
    let commonNotes: Set<String>
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Image & Title
            VStack(spacing: 12) {
                if let url = perfume.imageUrl {
                    LazyImage(url: url) { state in
                        if let image = state.image {
                            image
                                .resizable()
                                .scaledToFill()
                        } else {
                            DesignSystem.Colors.appSurface
                        }
                    }
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    ZStack {
                        DesignSystem.Colors.appSurface
                        Image(systemName: "flame.circle.fill")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(DesignSystem.Colors.primary.opacity(0.3))
                    }
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                VStack(spacing: 4) {
                    Text(perfume.brand?.name ?? "Marke")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .textCase(.uppercase)
                        .foregroundColor(DesignSystem.Colors.primary)
                        .lineLimit(1)
                    
                    Text(perfume.name)
                        .font(DesignSystem.Fonts.serif(size: 14, weight: .bold))
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(height: 40, alignment: .top)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 4)
            }
            .padding(.bottom, 16)
            
            Divider().background(Color.primary.opacity(0.1))
            
            // Concentration
            compareRow(
                title: "Konzentration",
                value: perfume.concentration?.uppercased() ?? "–"
            )
            
            // Performance / Longevity
            compareRow(
                title: "Haltbarkeit",
                value: perfume.longevity.isEmpty ? "–" : perfume.longevity
            )
            
            // Sillage
            compareRow(
                title: "Sillage",
                value: perfume.sillage.isEmpty ? "–" : perfume.sillage
            )
            
            Divider().background(Color.primary.opacity(0.1))
                .padding(.vertical, 8)
            
            // Duftnoten
            VStack(alignment: .leading, spacing: 16) {
                notesSection(title: "Kopfnoten", notes: perfume.topNotes)
                notesSection(title: "Herznoten", notes: perfume.midNotes)
                notesSection(title: "Basisnoten", notes: perfume.baseNotes)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer(minLength: 0)
        }
        .frame(width: 130)
    }
    
    // MARK: - Helper Views
    
    private func compareRow(title: LocalizedStringKey, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(hex: "#94A3B8"))
                .textCase(.uppercase)
            
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 50)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
    
    private func notesSection(title: LocalizedStringKey, notes: [Note]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(hex: "#94A3B8"))
                .textCase(.uppercase)
            
            if notes.isEmpty {
                Text("–")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color.secondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(notes, id: \.id) { note in
                        let isCommon = commonNotes.contains(note.name)
                        Text(note.name)
                            .font(.system(size: 12, weight: isCommon ? .bold : .regular))
                            .foregroundColor(isCommon ? DesignSystem.Colors.champagne : Color.primary)
                            .padding(.horizontal, isCommon ? 6 : 0)
                            .padding(.vertical, isCommon ? 2 : 0)
                            .background(isCommon ? DesignSystem.Colors.champagne.opacity(0.15) : Color.clear)
                            .cornerRadius(4)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
        }
    }
}
