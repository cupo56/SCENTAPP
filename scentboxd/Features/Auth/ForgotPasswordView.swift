//
//  ForgotPasswordView.swift
//  scentboxd
//

import SwiftUI

struct ForgotPasswordView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var emailSent = false
    @FocusState private var isEmailFocused: Bool

    private var isFormValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("@") && trimmed.contains(".")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                DesignSystem.Colors.bgDark.ignoresSafeArea()

                // Subtle glow
                Circle()
                    .fill(DesignSystem.Colors.primary.opacity(0.15))
                    .blur(radius: 120)
                    .frame(width: 300, height: 300)
                    .offset(y: -200)

                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "lock.rotation")
                                .font(.system(size: 48))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [DesignSystem.Colors.primary, Color(hex: "#fb7185")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )

                            Text("Passwort zurücksetzen")
                                .font(DesignSystem.Fonts.serif(size: 28, weight: .bold))
                                .foregroundStyle(.white)

                            Text("Gib deine E-Mail-Adresse ein und wir senden dir einen Link zum Zurücksetzen deines Passworts.")
                                .font(DesignSystem.Fonts.display(size: 14))
                                .foregroundStyle(Color(hex: "#94A3B8"))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 40)

                        if emailSent {
                            // Success State
                            successView
                        } else {
                            // Form
                            formView
                        }

                        Spacer()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        authManager.errorMessage = nil
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.champagne)
                }
            }
        }
    }

    // MARK: - Form

    private var formView: some View {
        VStack(spacing: 16) {
            // Email Field
            HStack {
                Image(systemName: "envelope")
                    .foregroundColor(Color(hex: "#94A3B8"))
                    .frame(width: 24)
                TextField("E-Mail", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .focused($isEmailFocused)
                    .submitLabel(.go)
                    .onSubmit {
                        if isFormValid {
                            sendResetEmail()
                        }
                    }
                    .foregroundColor(.white)
            }
            .padding(16)
            .glassPanel()
            .padding(.horizontal)

            // Error Message
            if let error = authManager.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Submit Button
            Button {
                sendResetEmail()
            } label: {
                HStack {
                    if authManager.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Link senden")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!isFormValid || authManager.isLoading)
            .padding(.horizontal)
        }
        .onAppear {
            isEmailFocused = true
        }
    }

    // MARK: - Success

    private var successView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)

            Text("E-Mail gesendet!")
                .font(DesignSystem.Fonts.display(size: 16, weight: .semibold))
                .foregroundStyle(.white)

            Text("Falls ein Konto mit dieser E-Mail existiert, erhältst du in Kürze einen Link zum Zurücksetzen deines Passworts.")
                .font(DesignSystem.Fonts.display(size: 14))
                .foregroundStyle(Color(hex: "#94A3B8"))
                .multilineTextAlignment(.center)

            Button {
                dismiss()
            } label: {
                Text("Zurück zur Anmeldung")
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.champagne)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .glassPanel()
        .padding(.horizontal)
    }

    // MARK: - Actions

    private func sendResetEmail() {
        Task {
            let success = await authManager.resetPassword(email: email)
            if success {
                withAnimation(.easeInOut) {
                    emailSent = true
                }
            }
        }
    }
}

#Preview {
    ForgotPasswordView()
        .environment(AuthManager())
}
