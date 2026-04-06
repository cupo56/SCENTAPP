//
//  AppConfig.swift
//  scentboxd
//
//  Created by Cupo on 13.01.26.
//

import Foundation
import Supabase

enum AppConfig {
    static let supabaseURL: String = {
        guard let value = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String, !value.isEmpty else {
            // Developer hint: SUPABASE_URL must be set in Info.plist via Config.xcconfig
            fatalError("App configuration incomplete – required service URL is missing.")
        }
        return value
    }()

    static let supabaseKey: String = {
        guard let value = Bundle.main.infoDictionary?["SUPABASE_KEY"] as? String, !value.isEmpty else {
            // Developer hint: SUPABASE_KEY must be set in Info.plist via Config.xcconfig
            fatalError("App configuration incomplete – required API key is missing.")
        }
        return value
    }()
    
    // Zentraler Client für die gesamte App (mit Certificate Pinning)
    static let client: SupabaseClient = {
        guard let url = URL(string: supabaseURL) else {
            // Developer hint: SUPABASE_URL value is not a valid URL
            fatalError("App configuration incomplete – service URL is malformed.")
        }
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: supabaseKey,
            options: SupabaseClientOptions(
                global: .init(session: PinnedURLSession.makeSession())
            )
        )
    }()

    // MARK: - Constants

    enum Pagination {
        static let perfumePageSize = 20
        static let reviewPageSize = 10
    }

    enum ReviewDefaults {
        static let longevity: Double = 65
        static let sillage: Double = 30
        static let minTextLength = 10
        static let maxTextLength = 500
        static let maxTitleLength = 100
    }

    enum Cache {
        /// Supabase-Katalog-Cache: Refresh nach 5 Minuten
        static let catalogTTL: TimeInterval = 300
        /// In-Memory-Suchcache: 2 Minuten
        static let searchTTL: TimeInterval = 120
        /// Auth-Session-Cache: 5 Minuten
        static let authSessionTTL: TimeInterval = 300
    }

    enum Timing {
        /// Debounce fuer Textsuche
        static let searchDebounceMs = 300
        /// Debounce fuer Suchvorschlaege
        static let searchSuggestionsDebounceMs = 200
        /// Debounce fuer Filter-Aenderungen
        static let filterDebounceMs = 200
        /// Rate-Limit zwischen Toggle-Aktionen (Sekunden)
        static let toggleThrottleInterval: TimeInterval = 0.5
        /// Minimale Splash-Screen-Dauer (Sekunden)
        static let splashMinDuration: Double = 1.5
    }
}
