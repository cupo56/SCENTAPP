//
//  scentboxdApp.swift
//  scentboxd
//
//  Created by Cupo on 09.01.26.
//

import SwiftUI
import SwiftData

@main
struct ScentBoxApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Hier wird die Datenbank initialisiert
        .modelContainer(for: [
            Perfume.self,
            Brand.self,
            Note.self,
            Review.self,
            UserPersonalData.self
        ])
    }
}

