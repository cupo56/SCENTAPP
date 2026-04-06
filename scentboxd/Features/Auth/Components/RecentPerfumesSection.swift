import SwiftUI

struct RecentPerfumesSection: View {
    let ownedPerfumes: [Perfume]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Zuletzt hinzugefügt")
                    .font(DesignSystem.Fonts.serif(size: 20, weight: .semibold))
                    .foregroundStyle(Color.primary)
                Spacer()
                NavigationLink(destination: OwnedPerfumesView()) {
                    Text("ALLE ANSEHEN")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1)
                        .foregroundColor(DesignSystem.Colors.primary)
                }
                .accessibilityLabel("Alle Parfums ansehen")
                .accessibilityHint("Öffnet die vollständige Sammlung")
            }
            .padding(.horizontal, 16)
            
            if ownedPerfumes.isEmpty {
                Text("Keine Parfums in deiner Sammlung.")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#94A3B8"))
                    .padding(.horizontal, 16)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(ownedPerfumes.prefix(10)) { perfume in
                            NavigationLink(destination: PerfumeDetailView(perfume: perfume)) {
                                recentPerfumeCard(perfume: perfume)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(perfume.name), \(perfume.brand?.name ?? "")")
                            .accessibilityHint("Öffnet die Detailseite")
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private func recentPerfumeCard(perfume: Perfume) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Image Area
            Color.clear
                .aspectRatio(3/4, contentMode: .fit)
                .overlay {
                    if let url = perfume.imageUrl {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            DesignSystem.Colors.appSurface
                        }
                    } else {
                        ZStack {
                            DesignSystem.Colors.appSurface
                            Image(systemName: "flame.circle.fill")
                                .resizable()
                                .frame(width: 28, height: 28)
                                .foregroundColor(DesignSystem.Colors.primary.opacity(0.3))
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(perfume.name)
                    .font(DesignSystem.Fonts.serif(size: 13))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                
                Text(perfume.brand?.name ?? String(localized: "Unbekannte Marke"))
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#94A3B8"))
                    .lineLimit(1)
            }
        }
        .frame(width: 140)
        .padding(10)
        .glassPanel()
    }
}
