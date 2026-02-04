//
//  AppConfig.swift
//  scentboxd
//
//  Created by Cupo on 13.01.26.
//

import Foundation
import Supabase

enum AppConfig {
    static let supabaseURL = "https://frvhlflwrqlpjftraawp.supabase.co"
    static let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZydmhsZmx3cnFscGpmdHJhYXdwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgzMzMwNTYsImV4cCI6MjA4MzkwOTA1Nn0.njD434Ibnr1mI_gVXojq4kyF6xzKGRf9Yk-XNS2W1D4" // Stelle sicher, dass dies dein Anon-Key ist
    
    // Zentraler Client für die gesamte App
    static let client = SupabaseClient(
        supabaseURL: URL(string: supabaseURL)!,
        supabaseKey: supabaseKey
    )
}
