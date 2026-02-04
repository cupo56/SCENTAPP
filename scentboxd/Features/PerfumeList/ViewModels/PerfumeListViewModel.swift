//
//  PerfumeListViewModel.swift
//  scentboxd
//
//  Created by Cupo on 09.01.26.
//

import SwiftUI
import Combine

@MainActor
class PerfumeListViewModel: ObservableObject {
    @Published var perfumes: [Perfume] = []
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    
    // Hier nutzen wir jetzt die RemoteDataSource (Supabase) statt der lokalen
    private let repository: PerfumeRepository = PerfumeRemoteDataSource()
    
    var filteredPerfumes: [Perfume] {
        if searchText.isEmpty {
            return perfumes
        }
        return perfumes.filter { perfume in
            let nameMatch = perfume.name.localizedCaseInsensitiveContains(searchText)
            // Hinweis: Damit die Suche nach Marke funktioniert, muss 'brand' von Supabase geladen sein
            let brandMatch = perfume.brand?.name.localizedCaseInsensitiveContains(searchText) ?? false
            return nameMatch || brandMatch
        }
    }
    
    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Der Aufruf ist jetzt asynchron (await)
            self.perfumes = try await repository.fetchAllPerfumes()
        } catch {
            print("Fehler beim Laden von Supabase: \(error)")
        }
    }
}
