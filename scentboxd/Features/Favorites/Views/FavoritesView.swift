//
//  FavoritesView.swift
//  scentboxd
//
//  Created by Cupo on 16.01.26.
//

import SwiftUI
import SwiftData

struct FavoritesView: View {
    // FIX: Wir filtern jetzt auf die String-Property 'statusRaw'.
    // "Wunschliste" ist der String-Wert aus deinem Enum.
    @Query(filter: #Predicate<Perfume> { perfume in
        perfume.userMetadata?.statusRaw == "Wunschliste"
    }, sort: \Perfume.name)
    var favoritePerfumes: [Perfume]
    
    var body: some View {
        NavigationStack {
            Group {
                if favoritePerfumes.isEmpty {
                    ContentUnavailableView(
                        "Keine Favoriten",
                        systemImage: "heart.slash",
                        description: Text("Markiere Parfums mit dem Herz-Symbol, um sie hier zu sehen.")
                    )
                } else {
                    List {
                        ForEach(favoritePerfumes) { perfume in
                            NavigationLink(destination: PerfumeDetailView(perfume: perfume)) {
                                PerfumeRowView(perfume: perfume)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Favoriten")
        }
    }
}

#Preview {
    FavoritesView()
        .modelContainer(for: [Perfume.self, UserPersonalData.self], inMemory: true)
}
