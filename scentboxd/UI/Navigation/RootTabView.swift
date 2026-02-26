//
//  RootTabView.swift
//  scentboxd
//
//  Created by Cupo on 09.01.26.
//

import SwiftUI

// Environment-Key für Tab-Navigation aus Child-Views heraus
private struct SelectedTabKey: EnvironmentKey {
    static let defaultValue: Binding<Int> = .constant(0)
}

extension EnvironmentValues {
    var selectedTab: Binding<Int> {
        get { self[SelectedTabKey.self] }
        set { self[SelectedTabKey.self] = newValue }
    }
}

struct RootTabView: View {
    @State private var selectedTab = 0

    init() {
        // Dark Tab Bar Appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color(hex: "#341826"))
        
        // Inactive tabs
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(Color(hex: "#cb90ad"))
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(Color(hex: "#cb90ad"))
        ]
        
        // Active tabs
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color(hex: "#C20A66"))
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(Color(hex: "#C20A66"))
        ]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            PerfumeListView()
                .tag(0)
                .tabItem {
                    Label("Katalog", systemImage: "book.fill")
                }

            FavoritesView()
                .tag(1)
                .tabItem {
                    Label("Favoriten", systemImage: "heart.fill")
                }

            OwnedPerfumesView()
                .tag(2)
                .tabItem {
                    Label("Meine", systemImage: "star.fill")
                }

            ProfileView()
                .tag(3)
                .tabItem {
                    Label("Profil", systemImage: "person.fill")
                }
        }
        .tint(Color(hex: "#C20A66"))
        .environment(\.selectedTab, $selectedTab)
    }
}
#Preview {
    RootTabView()
        .environmentObject(PerfumeListViewModel())
        .environment(AuthManager())
}
