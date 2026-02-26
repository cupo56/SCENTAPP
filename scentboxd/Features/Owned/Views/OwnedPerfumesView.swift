//
//  OwnedPerfumesView.swift
//  scentboxd
//
//  Created by Cupo on 16.01.26.
//

import SwiftUI
import SwiftData

struct OwnedPerfumesView: View {
    
    // SwiftData #Predicate erfordert String-Literal — Wert muss UserPerfumeStatus.owned.rawValue entsprechen
    // Compile-Time-Check:
    private static let _assertOwnedRaw: Void = {
        assert(UserPerfumeStatus.owned.rawValue == "Sammlung", "OwnedPerfumesView Predicate muss aktualisiert werden!")
    }()
    
    @Query(filter: #Predicate<Perfume> { perfume in
        perfume.userMetadata?.statusRaw == "Sammlung"
    }, sort: \Perfume.name)
    var ownedPerfumes: [Perfume]
    
    var body: some View {
        NavigationStack {
            Group {
                if ownedPerfumes.isEmpty {
                    ContentUnavailableView(
                        "Sammlung leer",
                        systemImage: "cabinet",
                        description: Text("Füge Parfums hinzu, die du bereits besitzt.")
                    )
                } else {
                    List {
                        ForEach(ownedPerfumes) { perfume in
                            NavigationLink(destination: PerfumeDetailView(perfume: perfume)) {
                                PerfumeRowView(perfume: perfume)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Meine Sammlung")
        }
    }
}

#Preview {
    OwnedPerfumesView()
        .modelContainer(for: [Perfume.self, UserPersonalData.self], inMemory: true)
}
