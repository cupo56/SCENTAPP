//
//  LanguageManager.swift
//  scentboxd
//

import SwiftUI

@Observable
final class LanguageManager {

    enum AppLanguage: String, CaseIterable {
        case german = "de"
        case english = "en"

        var displayName: String {
            switch self {
            case .german: "Deutsch"
            case .english: "English"
            }
        }

        var icon: String {
            switch self {
            case .german: "🇩🇪"
            case .english: "🇬🇧"
            }
        }
    }

    var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: Self.storageKey)
        }
    }

    var locale: Locale {
        Locale(identifier: currentLanguage.rawValue)
    }

    private static let storageKey = "appLanguage"

    init() {
        if let stored = UserDefaults.standard.string(forKey: Self.storageKey),
           let language = AppLanguage(rawValue: stored) {
            self.currentLanguage = language
        } else {
            self.currentLanguage = .german
        }
    }
}
