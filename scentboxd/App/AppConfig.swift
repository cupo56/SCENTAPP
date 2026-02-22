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
            fatalError("SUPABASE_URL not found in Info.plist – check Config.xcconfig")
        }
        return value
    }()

    static let supabaseKey: String = {
        guard let value = Bundle.main.infoDictionary?["SUPABASE_KEY"] as? String, !value.isEmpty else {
            fatalError("SUPABASE_KEY not found in Info.plist – check Config.xcconfig")
        }
        return value
    }()
    
    // Zentraler Client für die gesamte App
    static let client: SupabaseClient = {
        guard let url = URL(string: supabaseURL) else {
            fatalError("SUPABASE_URL ist keine gültige URL: '\(supabaseURL)' – check Config.xcconfig")
        }
        return SupabaseClient(supabaseURL: url, supabaseKey: supabaseKey)
    }()
}
