//
//  SignUpView.swift
//  scentboxd
//
//  Created by Cupo on 25.01.26.
//

import SwiftUI

struct SignUpView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var registrationSuccess = false
    
    /// Username: 3–20 Zeichen, nur Buchstaben, Zahlen und Unterstriche
    private static let usernameRegex = /^[a-zA-Z0-9_]{3,20}$/
    
    private var isUsernameValid: Bool {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        return trimmed.wholeMatch(of: Self.usernameRegex) != nil
    }
    
    private var usernameError: String? {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.count < 3 { return "Mindestens 3 Zeichen" }
        if trimmed.count > 20 { return "Maximal 20 Zeichen" }
        if trimmed.wholeMatch(of: Self.usernameRegex) == nil {
            return "Nur Buchstaben, Zahlen und _ erlaubt"
        }
        return nil
    }
    
    private var isEmailValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("@") && trimmed.contains(".")
    }

    private var isFormValid: Bool {
        isEmailValid &&
        isUsernameValid &&
        password.count >= 6 &&
        password == confirmPassword
    }
    
    private var passwordMismatch: Bool {
        !confirmPassword.isEmpty && password != confirmPassword
    }
    
    private var passwordTooShort: Bool {
        !password.isEmpty && password.count < 6
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 50))
                            .foregroundStyle(Color.accentColor)
                        
                        Text("Konto erstellen")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Registriere dich, um deine Düfte zu speichern")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Form Fields
                    VStack(spacing: 16) {
                        TextField("E-Mail", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Benutzername", text: $username)
                                .textContentType(.username)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .onChange(of: username) { _, newValue in
                                    // Limit auf 20 Zeichen
                                    if newValue.count > 20 {
                                        username = String(newValue.prefix(20))
                                    }
                                }
                            
                            if let error = usernameError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            SecureField("Passwort", text: $password)
                                .textContentType(.newPassword)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            
                            if passwordTooShort {
                                Text("Mindestens 6 Zeichen erforderlich")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            SecureField("Passwort bestätigen", text: $confirmPassword)
                                .textContentType(.newPassword)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            
                            if passwordMismatch {
                                Text("Passwörter stimmen nicht überein")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Error Message
                    if let error = authManager.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Success Message
                    if registrationSuccess {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title)
                                .foregroundStyle(.green)
                            Text("Registrierung erfolgreich!")
                                .fontWeight(.medium)
                            if authManager.pendingEmailConfirmation {
                                Text("Bitte bestätige deine E-Mail-Adresse. Nach der Bestätigung kannst du dich einloggen.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Register Button
                    Button {
                        Task {
                            let trimmedUsername = username.trimmingCharacters(in: .whitespaces)
                            let success = await authManager.signUp(
                                email: email,
                                password: password,
                                username: trimmedUsername.isEmpty ? nil : trimmedUsername
                            )
                            if success {
                                // E-Mail sofort bestätigt — kurz anzeigen und schließen
                                registrationSuccess = true
                                try? await Task.sleep(for: .seconds(2))
                                dismiss()
                            } else if authManager.pendingEmailConfirmation {
                                // Registrierung erfolgreich, E-Mail-Bestätigung ausstehend
                                registrationSuccess = true
                                // Nicht auto-schließen — User muss E-Mail bestätigen
                            }
                        }
                    } label: {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Registrieren")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isFormValid ? Color.accentColor : Color.gray)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!isFormValid || authManager.isLoading || registrationSuccess)
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SignUpView()
        .environment(AuthManager())
}
