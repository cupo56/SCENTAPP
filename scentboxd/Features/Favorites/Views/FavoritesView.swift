//
//  FavoritesView.swift
//  scentboxd
//
//  Created by Cupo on 16.01.26.
//

import SwiftUI
import SwiftData

struct FavoritesView: View {
    @Query(filter: #Predicate<Perfume> { perfume in
        perfume.userMetadata?.isFavorite == true
    }, sort: \Perfume.name)
    var favoritePerfumes: [Perfume]
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.bgDark.ignoresSafeArea()
                
                if favoritePerfumes.isEmpty {
                    ContentUnavailableView(
                        "Keine Favoriten",
                        systemImage: "heart.slash",
                        description: Text("Markiere Parfums mit dem Herz-Symbol, um sie hier zu sehen.")
                    )
                } else {
                    ScrollView {
                        // Header Stats Component (from design)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Favoriten gesamt: \(favoritePerfumes.count)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color(hex: "#94A3B8"))
                                    .textCase(.uppercase)
                                    .tracking(1)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(favoritePerfumes) { perfume in
                                NavigationLink(destination: PerfumeDetailView(perfume: perfume)) {
                                    CollectionGridItem(perfume: perfume, isFavorite: false)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("Favoriten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

#Preview {
    FavoritesView()
        .modelContainer(for: [Perfume.self, UserPersonalData.self], inMemory: true)
}
