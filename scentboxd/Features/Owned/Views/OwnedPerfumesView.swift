//
//  OwnedPerfumesView.swift
//  scentboxd
//
//  Created by Cupo on 16.01.26.
//

import SwiftUI
import SwiftData

struct OwnedPerfumesView: View {
    
    @Query(filter: #Predicate<Perfume> { perfume in
        perfume.userMetadata?.isOwned == true
    }, sort: \Perfume.name)
    var ownedPerfumes: [Perfume]
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.bgDark.ignoresSafeArea()
                
                if ownedPerfumes.isEmpty {
                    ContentUnavailableView(
                        "Sammlung leer",
                        systemImage: "cabinet",
                        description: Text("Füge Parfums hinzu, die du bereits besitzt.")
                    )
                } else {
                    ScrollView {
                        // Header Stats Component (from design)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Parfums gesamt: \(ownedPerfumes.count)")
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
                            ForEach(ownedPerfumes) { perfume in
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
            .navigationTitle("Meine Sammlung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

#Preview {
    OwnedPerfumesView()
        .modelContainer(for: [Perfume.self, UserPersonalData.self], inMemory: true)
}
