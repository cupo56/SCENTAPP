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
    let modelContainer: ModelContainer

    init() {
        ImagePipelineConfig.configure()

        let schema = Schema([
            Perfume.self,
            Brand.self,
            Note.self,
            Review.self,
            UserPersonalData.self
        ])

        // Bei Schema-Änderungen lokalen Cache löschen und neu aufbauen.
        // Daten werden von Supabase beim nächsten Sync wiederhergestellt.
        do {
            modelContainer = try ModelContainer(for: schema)
        } catch {
            let config = ModelConfiguration()
            let url = config.url
            let storeFiles = [url, url.appendingPathExtension("wal"), url.appendingPathExtension("shm")]
            for file in storeFiles {
                try? FileManager.default.removeItem(at: file)
            }
            do {
                modelContainer = try ModelContainer(for: schema)
            } catch {
                fatalError("ModelContainer konnte nicht erstellt werden: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}

