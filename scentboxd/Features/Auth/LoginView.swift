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
    
    private var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Logo & Header
                    VStack(spacing: 16) {
                        Image("scentboxdicon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 22))
                        
                        Text("ScentBox")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Melde dich an, um deine Sammlung zu verwalten")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    
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
                        
                        SecureField("Passwort", text: $password)
                            .textContentType(.password)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
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
                        .padding()
                        .background(isFormValid ? Color.accentColor : Color.gray)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!isFormValid || authManager.isLoading)
                    .padding(.horizontal)
                    
                    // Divider
                    HStack {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundStyle(Color(.systemGray4))
                        Text("oder")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Rectangle()
                            .frame(height: 1)
                            .foregroundStyle(Color(.systemGray4))
                    }
                    .padding(.horizontal)
                    
                    // Sign Up Link
                    Button {
                        showSignUp = true
                    } label: {
                        Text("Neues Konto erstellen")
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
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
