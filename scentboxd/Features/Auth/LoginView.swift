//
//  LoginView.swift
//  scentboxd
//
//  Created by Cupo on 25.01.26.
//

import SwiftUI

struct LoginView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var email = ""
    @State private var password = ""
    @State private var showSignUp = false
    @FocusState private var focusedField: Field?
    
    private enum Field: Hashable {
        case email, password
    }
    
    private var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.isEmpty
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
                        // Logo & Header
                        VStack(spacing: 16) {
                            Image("scentboxdicon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 22))
                                .shadow(color: DesignSystem.Colors.primary.opacity(0.4), radius: 20, x: 0, y: 10)
                            
                            Text("ScentBox")
                                .font(DesignSystem.Fonts.serif(size: 32, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [DesignSystem.Colors.primary, Color(hex: "#fb7185")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            Text("Melde dich an, um deine Sammlung zu verwalten")
                                .font(DesignSystem.Fonts.display(size: 14))
                                .foregroundStyle(Color(hex: "#94A3B8"))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 40)
                        
                        // Form Fields
                        VStack(spacing: 16) {
                            // Email
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
                                    .onSubmit { focusedField = .password }
                                    .foregroundColor(.white)
                            }
                            .padding(16)
                            .glassPanel()
                            
                            // Password
                            HStack {
                                Image(systemName: "lock")
                                    .foregroundColor(Color(hex: "#94A3B8"))
                                    .frame(width: 24)
                                SecureField("Passwort", text: $password)
                                    .textContentType(.password)
                                    .focused($focusedField, equals: .password)
                                    .submitLabel(.go)
                                    .onSubmit {
                                        if isFormValid {
                                            Task { await authManager.signIn(email: email, password: password) }
                                        }
                                    }
                                    .foregroundColor(.white)
                            }
                            .padding(16)
                            .glassPanel()
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
                        
                        // Login Button
                        Button {
                            Task {
                                await authManager.signIn(email: email, password: password)
                            }
                        } label: {
                            HStack {
                                if authManager.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Anmelden")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!isFormValid || authManager.isLoading)
                        .padding(.horizontal)
                        
                        // Divider
                        HStack {
                            Rectangle()
                                .frame(height: 1)
                                .foregroundStyle(Color.white.opacity(0.1))
                            Text("oder")
                                .font(.footnote)
                                .foregroundStyle(Color(hex: "#94A3B8"))
                            Rectangle()
                                .frame(height: 1)
                                .foregroundStyle(Color.white.opacity(0.1))
                        }
                        .padding(.horizontal)
                        
                        // Sign Up Link
                        Button {
                            showSignUp = true
                        } label: {
                            Text("Neues Konto erstellen")
                                .fontWeight(.medium)
                                .foregroundColor(DesignSystem.Colors.champagne)
                        }
                        
                        Spacer()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showSignUp) {
                SignUpView()
            }
        }
    }
}

#Preview {
    LoginView()
        .environment(AuthManager())
}
