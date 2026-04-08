//
//  ProfileToolbarButton.swift
//  scentboxd
//
//  Toolbar-Button, der den Profil-Screen als Sheet öffnet.
//  Wird per Environment-Binding (`\.showProfileSheet`) gesteuert,
//  damit ein einziges, in `RootTabView` montiertes Sheet wiederverwendet wird.
//

import SwiftUI

// MARK: - Environment Key

private struct ShowProfileSheetKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(false)
}

extension EnvironmentValues {
    /// Binding zum globalen Profil-Sheet, das in `RootTabView` montiert ist.
    var showProfileSheet: Binding<Bool> {
        get { self[ShowProfileSheetKey.self] }
        set { self[ShowProfileSheetKey.self] = newValue }
    }
}

// MARK: - Button

/// Toolbar-Button, der den Profil-Screen öffnet.
/// Erwartet ein in der Umgebung gesetztes `\.showProfileSheet`-Binding.
struct ProfileToolbarButton: View {
    @Environment(\.showProfileSheet) private var showProfileSheet

    var body: some View {
        Button {
            showProfileSheet.wrappedValue = true
        } label: {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(DesignSystem.Colors.primary)
        }
        .accessibilityLabel("Profil öffnen")
    }
}
