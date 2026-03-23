import SwiftUI

@Observable
final class ThemeManager {

    /// `true` = dunkles Farbschema, `false` = helles Farbschema.
    var prefersDarkAppearance: Bool {
        didSet {
            UserDefaults.standard.set(prefersDarkAppearance, forKey: Self.storageKey)
        }
    }

    var colorScheme: ColorScheme? {
        prefersDarkAppearance ? .dark : .light
    }

    private static let storageKey = "appPrefersDarkAppearance"
    private static let legacySchemeKey = "appColorScheme"

    init() {
        Self.migrateLegacyIfNeeded()
        if let stored = UserDefaults.standard.object(forKey: Self.storageKey) as? Bool {
            self.prefersDarkAppearance = stored
        } else {
            self.prefersDarkAppearance = true
            // didSet läuft bei Erst-Init nicht — Default explizit speichern
            UserDefaults.standard.set(true, forKey: Self.storageKey)
        }
    }

    /// Frühere Versionen nutzten `appColorScheme` (dark/light/system).
    private static func migrateLegacyIfNeeded() {
        guard UserDefaults.standard.object(forKey: storageKey) == nil,
              let legacy = UserDefaults.standard.string(forKey: legacySchemeKey) else { return }
        let dark = (legacy == "dark")
        UserDefaults.standard.set(dark, forKey: storageKey)
        UserDefaults.standard.removeObject(forKey: legacySchemeKey)
    }
}
