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
    @FocusState private var focusedField: Field?
    
    private enum Field: Hashable {
        case email, username, password, confirmPassword
    }
    
    /// Username: 3–20 Zeichen, nur Buchstaben, Zahlen und Unterstriche
    private static let usernameRegex = /^[a-zA-Z0-9_]{3,20}$/

    /// E-Mail: RFC 5322–inspirierte Validierung
    private static let emailRegex = /^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,64}$/
    
    private var isUsernameValid: Bool {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        return trimmed.wholeMatch(of: Self.usernameRegex) != nil
    }
    
    private var usernameError: String? {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.count < 3 { return String(localized: "Mindestens 3 Zeichen") }
        if trimmed.count > 20 { return String(localized: "Maximal 20 Zeichen") }
        if trimmed.wholeMatch(of: Self.usernameRegex) == nil {
            return String(localized: "Nur Buchstaben, Zahlen und _ erlaubt")
        }
        return nil
    }
    
    private var isEmailValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        return trimmed.wholeMatch(of: Self.emailRegex) != nil
    }

    private var emailError: String? {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.wholeMatch(of: Self.emailRegex) == nil {
            return String(localized: "Ungültige E-Mail-Adresse")
        }
        return nil
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
            ZStack {
                // Background
                DesignSystem.Colors.bgDark.ignoresSafeArea()
                
                // Subtle glow
                Circle()
                    .fill(DesignSystem.Colors.primary.opacity(0.12))
                    .blur(radius: 100)
                    .frame(width: 250, height: 250)
                    .offset(x: 100, y: -150)
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 50))
                                .foregroundStyle(DesignSystem.Colors.primary)
                            
                            Text("Konto erstellen")
                                .font(DesignSystem.Fonts.serif(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Registriere dich, um deine Düfte zu speichern")
                                .font(DesignSystem.Fonts.display(size: 14))
                                .foregroundStyle(Color(hex: "#94A3B8"))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        
                        // Form Fields
                        VStack(spacing: 16) {
                            // Email
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "envelope")
                                        .foregroundColor(Color(hex: "#94A3B8"))
                                        .frame(width: 24)
                                    TextField("E-Mail", text: $email)
                                        .textContentType(.emailAddress)
                                        .keyboardType(.emailAddress)
                                        .autocapitalization(.none)
                                        .autocorrectionDisabled()
                                        .focused($focusedField, equals: .email)
                                        .submitLabel(.next)
                                        .onSubmit { focusedField = .username }
                                        .foregroundColor(.white)
                                        .accessibilityLabel("E-Mail-Adresse")
                                }
                                .padding(16)
                                .glassPanel()

                                if let error = emailError {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                        .padding(.leading, 8)
                                }
                            }
                            
                            // Username
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "at")
                                        .foregroundColor(Color(hex: "#94A3B8"))
                                        .frame(width: 24)
                                    TextField("Benutzername", text: $username)
                                        .textContentType(.username)
                                        .autocapitalization(.none)
                                        .autocorrectionDisabled()
                                        .focused($focusedField, equals: .username)
                                        .submitLabel(.next)
                                        .onSubmit { focusedField = .password }
                                        .foregroundColor(.white)
                                        .accessibilityLabel("Benutzername")
                                        .accessibilityHint("3 bis 20 Zeichen, nur Buchstaben, Zahlen und Unterstriche")
                                        .onChange(of: username) { _, newValue in
                                            if newValue.count > 20 {
                                                username = String(newValue.prefix(20))
                                            }
                                        }
                                }
                                .padding(16)
                                .glassPanel()
                                
                                if let error = usernameError {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                        .padding(.leading, 8)
                                }
                            }
                            
                            // Password
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "lock")
                                        .foregroundColor(Color(hex: "#94A3B8"))
                                        .frame(width: 24)
                                    SecureField("Passwort", text: $password)
                                        .textContentType(.newPassword)
                                        .focused($focusedField, equals: .password)
                                        .submitLabel(.next)
                                        .onSubmit { focusedField = .confirmPassword }
                                        .foregroundColor(.white)
                                        .accessibilityLabel("Passwort")
                                        .accessibilityHint("Mindestens 6 Zeichen")
                                }
                                .padding(16)
                                .glassPanel()
                                
                                if passwordTooShort {
                                    Text("Mindestens 6 Zeichen erforderlich")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                        .padding(.leading, 8)
                                }
                            }
                            
                            // Confirm Password
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "lock.rotation")
                                        .foregroundColor(Color(hex: "#94A3B8"))
                                        .frame(width: 24)
                                    SecureField("Passwort bestätigen", text: $confirmPassword)
                                        .textContentType(.newPassword)
                                        .focused($focusedField, equals: .confirmPassword)
                                        .submitLabel(.go)
                                        .onSubmit {
                                            if isFormValid {
                                                focusedField = nil
                                            }
                                        }
                                        .foregroundColor(.white)
                                        .accessibilityLabel("Passwort bestätigen")
                                }
                                .padding(16)
                                .glassPanel()
                                
                                if passwordMismatch {
                                    Text("Passwörter stimmen nicht überein")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                        .padding(.leading, 8)
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
                                    .foregroundColor(.white)
                                if authManager.pendingEmailConfirmation {
                                    Text("Bitte bestätige deine E-Mail-Adresse. Nach der Bestätigung kannst du dich einloggen.")
                                        .font(.footnote)
                                        .foregroundStyle(Color(hex: "#94A3B8"))
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
                                    registrationSuccess = true
                                    try? await Task.sleep(for: .seconds(2))
                                    dismiss()
                                } else if authManager.pendingEmailConfirmation {
                                    registrationSuccess = true
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
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!isFormValid || authManager.isLoading || registrationSuccess)
                        .padding(.horizontal)
                        .accessibilityLabel("Registrieren")
                        .accessibilityHint("Doppeltippen, um ein neues Konto zu erstellen")
                        
                        Spacer()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(authManager.isLoading || registrationSuccess)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.champagne)
                    .disabled(authManager.isLoading || registrationSuccess)
                }
            }
        }
    }
}

#Preview {
    SignUpView()
        .environment(AuthManager(profileService: ProfileService()))
}
