//
//  ErrorAlertModifier.swift
//  scentboxd
//

import SwiftUI

struct ErrorAlertModifier: ViewModifier {
    let title: String
    @Binding var isPresented: Bool
    let message: String?
    var retryAction: (() async -> Void)?

    func body(content: Content) -> some View {
        content
            .alert(title, isPresented: $isPresented) {
                Button("OK", role: .cancel) { }
                if let retryAction {
                    Button("Erneut versuchen") {
                        Task { await retryAction() }
                    }
                }
            } message: {
                Text(message ?? String(localized: "Ein Fehler ist aufgetreten."))
            }
    }
}

extension View {
    func errorAlert(
        _ title: String,
        isPresented: Binding<Bool>,
        message: String?,
        retryAction: (() async -> Void)? = nil
    ) -> some View {
        modifier(ErrorAlertModifier(
            title: title,
            isPresented: isPresented,
            message: message,
            retryAction: retryAction
        ))
    }
}
