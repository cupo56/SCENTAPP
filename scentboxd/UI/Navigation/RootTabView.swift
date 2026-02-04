//
//  RootTabView.swift
//  scentboxd
//
//  Created by Cupo on 09.01.26.
//

import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            PerfumeListView()
                .tabItem {
                    Label("Katalog", systemImage: "book.fill")
                }
            
            FavoritesView()
                .tabItem {
                    Label("Favoriten", systemImage: "heart.fill")
                }
            
            OwnedPerfumesView()
                .tabItem {
                    Label("Meine", systemImage: "star.fill")
                }
            
            ProfileView()
                .tabItem {
                    Label("Profil", systemImage: "person.fill")
                }
        }
    }
}
#Preview {
    RootTabView()
        .environmentObject(PerfumeListViewModel())
        .environment(AuthManager())
}

