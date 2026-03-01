//
//  ProfileView.swift
//  scentboxd
//
//  Created by Cupo on 25.01.26.
//

import SwiftUI
import SwiftData
import Auth
import Supabase
#if canImport(PostgREST)
import PostgREST
#endif

struct ProfileView: View {
    @Environment(AuthManager.self) private var authManager
    
    // MARK: - Data Queries
    @Query(filter: #Predicate<Perfume> { perfume in
        perfume.userMetadata?.statusRaw == "Sammlung"
    }, sort: \Perfume.name)
    var ownedPerfumes: [Perfume]
    
    @Query(filter: #Predicate<Perfume> { perfume in
        perfume.userMetadata?.statusRaw == "Wunschliste"
    }, sort: \Perfume.name)
    var favoritePerfumes: [Perfume]
    
    // MARK: - State
    @State private var isEditingUsername = false
    @State private var usernameInput = ""
    @State private var showUsernameSaved = false
    @State private var reviewCount: Int = 0
    
    var body: some View {
        NavigationStack {
            Group {
                if authManager.isAuthenticated {
                    authenticatedView
                } else {
                    LoginView()
                }
            }
        }
    }
    
    // MARK: - Authenticated View
    
    private var authenticatedView: some View {
        ZStack {
            DesignSystem.Colors.bgDark.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    profileHeader
                    statsGrid
                    recentlyAddedSection
                    signOutButton
                    appInfoRow
                }
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Settings action placeholder
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.05))
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task {
            await loadReviewCount()
        }
        .sheet(isPresented: $isEditingUsername) {
            usernameEditSheet
        }
    }
    
    // MARK: - Profile Header
    
    private var profileHeader: some View {
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
                        isEditingUsername = true
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
                }
                
                // Name & subtitle
                VStack(spacing: 6) {
                    Text(authManager.username ?? "Scentboxd Benutzer")
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
                    
                    if showUsernameSaved {
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
    
    // MARK: - Stats Grid
    
    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            NavigationLink(destination: OwnedPerfumesView()) {
                statsCard(icon: "archivebox", value: "\(ownedPerfumes.count)", label: "Sammlung")
            }
            .buttonStyle(.plain)
            
            NavigationLink(destination: UserReviewsView()) {
                statsCard(icon: "text.quote", value: "\(reviewCount)", label: "Bewertungen")
            }
            .buttonStyle(.plain)
            
            NavigationLink(destination: FavoritesView()) {
                statsCard(icon: "heart", value: "\(favoritePerfumes.count)", label: "Wunschliste")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }
    
    private func statsCard(icon: String, value: String, label: String, showGradientOverlay: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(DesignSystem.Colors.primary.opacity(0.8))
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: "#475569"))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(DesignSystem.Fonts.serif(size: 28, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.champagne)
                    .shadow(color: DesignSystem.Colors.primary.opacity(0.3), radius: 10, x: 0, y: 0)
                
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.5)
                    .foregroundColor(Color(hex: "#94A3B8"))
            }
        }
        .padding(20)
        .background {
            if showGradientOverlay {
                LinearGradient(
                    colors: [DesignSystem.Colors.primary.opacity(0.08), .clear],
                    startPoint: .bottomLeading,
                    endPoint: .topTrailing
                )
            }
        }
        .glassPanel()
    }
    
    // MARK: - Recently Added
    
    private var recentlyAddedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Zuletzt hinzugefügt")
                    .font(DesignSystem.Fonts.serif(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                NavigationLink(destination: OwnedPerfumesView()) {
                    Text("ALLE ANSEHEN")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1)
                        .foregroundColor(DesignSystem.Colors.primary)
                }
            }
            .padding(.horizontal, 16)
            
            if ownedPerfumes.isEmpty {
                Text("Keine Parfums in deiner Sammlung.")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#94A3B8"))
                    .padding(.horizontal, 16)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(ownedPerfumes.prefix(10)) { perfume in
                            NavigationLink(destination: PerfumeDetailView(perfume: perfume)) {
                                recentPerfumeCard(perfume: perfume)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
    
    private func recentPerfumeCard(perfume: Perfume) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Image Area
            Color.clear
                .aspectRatio(3/4, contentMode: .fit)
                .overlay {
                    if let url = perfume.imageUrl {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            DesignSystem.Colors.surfaceDark
                        }
                    } else {
                        ZStack {
                            DesignSystem.Colors.surfaceDark
                            Image(systemName: "flame.circle.fill")
                                .resizable()
                                .frame(width: 28, height: 28)
                                .foregroundColor(DesignSystem.Colors.primary.opacity(0.3))
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(perfume.name)
                    .font(DesignSystem.Fonts.serif(size: 13))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(perfume.brand?.name ?? "Unbekannte Marke")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#64748B"))
                    .lineLimit(1)
            }
        }
        .frame(width: 140)
        .padding(10)
        .glassPanel()
    }
    
    // MARK: - Sign Out
    
    private var signOutButton: some View {
        Button(role: .destructive) {
            Task {
                await authManager.signOut()
            }
        } label: {
            HStack(spacing: 8) {
                if authManager.isLoading {
                    ProgressView()
                        .tint(.red.opacity(0.6))
                } else {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14))
                    Text("Abmelden")
                        .font(DesignSystem.Fonts.display(size: 14, weight: .medium))
                }
            }
            .foregroundColor(.red.opacity(0.7))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.red.opacity(0.15), lineWidth: 1)
            )
            .background(Color.red.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(authManager.isLoading)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // MARK: - App Info
    
    private var appInfoRow: some View {
        HStack {
            Text("Version")
                .foregroundColor(Color(hex: "#94A3B8"))
            Spacer()
            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–")
                .foregroundColor(Color(hex: "#64748B"))
        }
        .font(.caption)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
    
    // MARK: - Username Edit Sheet
    
    private var usernameEditSheet: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.bgDark.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("BENUTZERNAME")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2)
                            .foregroundColor(DesignSystem.Colors.primary)
                        
                        HStack {
                            Image(systemName: "at")
                                .foregroundColor(Color(hex: "#94A3B8"))
                                .frame(width: 24)
                            TextField("Benutzername", text: $usernameInput)
                                .textContentType(.username)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .submitLabel(.done)
                                .onSubmit { saveUsername() }
                                .foregroundColor(.white)
                        }
                        .padding(16)
                        .glassPanel()
                    }
                    
                    Button {
                        saveUsername()
                    } label: {
                        Text("Speichern")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(usernameInput.trimmingCharacters(in: .whitespaces).isEmpty || authManager.isLoading)
                    
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Profil bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        isEditingUsername = false
                    }
                    .foregroundColor(Color(hex: "#94A3B8"))
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Helpers
    
    private var memberSinceText: String {
        if let createdAt = authManager.currentUser?.createdAt {
            return createdAt.formatted(date: .abbreviated, time: .omitted)
        }
        return "–"
    }
    
    // MARK: - Actions
    
    private func loadReviewCount() async {
        guard let currentUserIdString = authManager.currentUser?.id.uuidString else { return }
        
        // Use SwiftData approach or raw count from Supabase
        // Easiest is to query via ReviewRemoteDataSource if possible, or load via Supabase directly
        do {
            let configClient = AppConfig.client
            let response = try await configClient
                .from("reviews")
                .select("id", head: true, count: .exact)
                .eq("user_id", value: currentUserIdString)
                .execute()
            
            if let count = response.count {
                reviewCount = count
            }
        } catch {
            print("Failed to load review count: \(error.localizedDescription)")
        }
    }
    
    private func saveUsername() {
        let trimmed = usernameInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        Task {
            let success = await authManager.saveUsername(trimmed)
            if success {
                isEditingUsername = false
                showUsernameSaved = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    showUsernameSaved = false
                }
            }
        }
    }
}

#Preview("Logged In") {
    ProfileView()
        .environment(AuthManager())
}
