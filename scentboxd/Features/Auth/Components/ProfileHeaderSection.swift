import SwiftUI
import Auth

struct ProfileHeaderSection: View {
    @Environment(AuthManager.self) private var authManager
    @Binding var editState: ProfileEditState
    @Binding var usernameInput: String

    var body: some View {
        ZStack {
            // Background Glow
            Circle()
                .fill(DesignSystem.Colors.primary.opacity(0.2))
                .blur(radius: 80)
                .frame(width: 260, height: 260)
                .offset(y: -20)
            
            VStack(spacing: 16) {
                // Avatar with edit button
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .stroke(DesignSystem.Colors.primary.opacity(0.3), lineWidth: 2)
                        .shadow(color: DesignSystem.Colors.primary.opacity(0.2), radius: 15)
                        .frame(width: 128, height: 128)
                        .overlay(
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                DesignSystem.Colors.primary.opacity(0.3),
                                                Color.purple.opacity(0.2)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                
                                Image(systemName: "person.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .clipShape(Circle())
                        )
                    
                    // Edit button
                    Button {
                        usernameInput = authManager.username ?? ""
                        editState = .editing
                    } label: {
                        ZStack {
                            Circle()
                                .fill(DesignSystem.Colors.primary)
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "pencil")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .overlay(
                            Circle()
                                .stroke(DesignSystem.Colors.bgDark, lineWidth: 4)
                        )
                    }
                    .offset(x: 2, y: -2)
                    .accessibilityLabel("Profil bearbeiten")
                    .accessibilityHint("Öffnet die Bearbeitung des Benutzernamens")
                }
                
                // Name & subtitle
                VStack(spacing: 6) {
                    Text(authManager.username ?? String(localized: "Scentboxd Benutzer"))
                        .font(DesignSystem.Fonts.serif(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .tracking(-0.3)
                    
                    Text("SCENT CONNOISSEUR")
                        .font(DesignSystem.Fonts.display(size: 11, weight: .semibold))
                        .tracking(3)
                        .foregroundColor(DesignSystem.Colors.primary)
                    
                    Text(authManager.currentUser?.email ?? "")
                        .font(DesignSystem.Fonts.display(size: 13))
                        .foregroundColor(Color(hex: "#94A3B8"))
                        .padding(.top, 2)
                    
                    if editState == .success {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                            Text("Benutzername gespeichert")
                                .font(.caption2)
                        }
                        .foregroundStyle(.green)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    if let error = authManager.errorMessage {
                        Text(error)
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}
