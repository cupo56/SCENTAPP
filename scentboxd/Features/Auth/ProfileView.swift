//
//  ProfileView.swift
//  scentboxd
//
//  Created by Cupo on 25.01.26.
//

import SwiftUI
import SwiftData
import Auth
import os
import Supabase
#if canImport(PostgREST)
import PostgREST
#endif

enum ProfileEditState {
    case idle
    case editing
    case saving
    case success
}

struct ProfileView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dependencies) private var dependencies
    
    // MARK: - Data Queries (single query, split via computed properties)
    @Query(filter: #Predicate<Perfume> { perfume in
        perfume.userMetadata?.isOwned == true || perfume.userMetadata?.isFavorite == true
    }, sort: \Perfume.name)
    private var userPerfumes: [Perfume]

    var ownedPerfumes: [Perfume] {
        userPerfumes.filter { $0.userMetadata?.isOwned == true }
    }

    var favoritePerfumes: [Perfume] {
        userPerfumes.filter { $0.userMetadata?.isFavorite == true }
    }
    
    // MARK: - State
    @State private var editState: ProfileEditState = .idle
    @State private var usernameInput = ""
    @State private var reviewCount: Int = 0
    @State private var reviewCountError: String?
    @State private var isRenderingShareImage = false // Kept boolean for share flow since it belongs to a different action
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var reviewCountTask: Task<Void, Never>?
    @State private var usernameSaveTask: Task<Void, Never>?
    @State private var isProfilePublic = true
    @State private var bioText = ""
    @State private var isSavingBio = false
    @State private var showBioSheet = false
    
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
                    ProfileHeaderSection(
                        editState: $editState,
                        usernameInput: $usernameInput
                    )
                    statsGrid

                    PendingSyncBanner()
                        .padding(.horizontal, 16)

                    // Duftprofil Link
                    NavigationLink(destination: FragranceProfileView(
                        service: dependencies.makeFragranceProfileService(),
                        scentWheelService: dependencies.makeScentWheelService()
                    )) {
                        HStack(spacing: 12) {
                            Image(systemName: "chart.bar.xaxis")
                                .font(.system(size: 18))
                                .foregroundStyle(DesignSystem.Colors.champagne)
                                .frame(width: 36, height: 36)
                                .background(DesignSystem.Colors.champagne.opacity(0.12))
                                .clipShape(Circle())

                            Text("Mein Duftprofil")
                                .font(DesignSystem.Fonts.display(size: 16, weight: .medium))
                                .foregroundStyle(.white)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(hex: "#94A3B8"))
                        }
                        .padding(16)
                        .glassPanel()
                    }
                    .padding(.horizontal)
                    .accessibilityLabel("Mein Duftprofil")
                    .accessibilityHint("Öffnet dein persönliches Duftprofil")

                    // Profil-Sichtbarkeit & Bio
                    VStack(spacing: 12) {
                        // Public Toggle
                        HStack(spacing: 12) {
                            Image(systemName: isProfilePublic ? "eye" : "eye.slash")
                                .font(.system(size: 18))
                                .foregroundStyle(DesignSystem.Colors.champagne)
                                .frame(width: 36, height: 36)
                                .background(DesignSystem.Colors.champagne.opacity(0.12))
                                .clipShape(Circle())

                            Text("Profil öffentlich")
                                .font(DesignSystem.Fonts.display(size: 16, weight: .medium))
                                .foregroundStyle(.white)

                            Spacer()

                            Toggle("", isOn: $isProfilePublic)
                                .tint(DesignSystem.Colors.primary)
                                .labelsHidden()
                        }
                        .padding(16)
                        .glassPanel()
                        .onChange(of: isProfilePublic) { _, newValue in
                            Task { await updateProfileVisibility(isPublic: newValue) }
                        }
                        .accessibilityLabel("Profil öffentlich sichtbar")
                        .accessibilityHint("Andere Benutzer können dein Profil und deine Sammlung sehen")

                        // Bio bearbeiten
                        Button {
                            showBioSheet = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "text.quote")
                                    .font(.system(size: 18))
                                    .foregroundStyle(DesignSystem.Colors.champagne)
                                    .frame(width: 36, height: 36)
                                    .background(DesignSystem.Colors.champagne.opacity(0.12))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Bio bearbeiten")
                                        .font(DesignSystem.Fonts.display(size: 16, weight: .medium))
                                        .foregroundStyle(.white)
                                    if !bioText.isEmpty {
                                        Text(bioText)
                                            .font(.caption)
                                            .foregroundStyle(Color(hex: "#94A3B8"))
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color(hex: "#94A3B8"))
                            }
                            .padding(16)
                            .glassPanel()
                        }
                        .accessibilityLabel("Bio bearbeiten")
                    }
                    .padding(.horizontal)

                    // Sammlung teilen
                    if !ownedPerfumes.isEmpty {
                        shareCollectionButton
                            .padding(.horizontal)
                    }

                    RecentPerfumesSection(ownedPerfumes: ownedPerfumes)
                    signOutButton
                    appInfoRow
                }
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
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
                    .accessibilityLabel("Einstellungen")
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear {
            reviewCountTask?.cancel()
            reviewCountTask = Task {
                await loadReviewCount()
                await loadProfileSettings()
            }
        }
        .onDisappear {
            reviewCountTask?.cancel()
            usernameSaveTask?.cancel()
        }
        .sheet(isPresented: Binding(
            get: { editState == .editing || editState == .saving },
            set: { isPresented in
                if !isPresented { editState = .idle }
            }
        )) {
            usernameEditSheet
        }
        .sheet(isPresented: $showShareSheet) {
            if let shareImage {
                ShareSheet(items: [shareImage])
            }
        }
        .sheet(isPresented: $showBioSheet) {
            bioEditSheet
        }
    }

    // MARK: - Stats Grid
    
    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            NavigationLink(destination: OwnedPerfumesView()) {
                ProfileStatsCard(icon: "archivebox", value: "\(ownedPerfumes.count)", label: "Sammlung")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Sammlung, \(ownedPerfumes.count) Parfums")
            .accessibilityHint("Öffnet deine Parfum-Sammlung")
            
            NavigationLink(destination: UserReviewsView()) {
                ProfileStatsCard(icon: "text.quote", value: reviewCountError != nil ? "–" : "\(reviewCount)", label: "Bewertungen")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Bewertungen, \(reviewCount)")
            .accessibilityHint("Öffnet deine Bewertungen")
            
            NavigationLink(destination: FavoritesView()) {
                ProfileStatsCard(icon: "heart", value: "\(favoritePerfumes.count)", label: "Wunschliste")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Wunschliste, \(favoritePerfumes.count) Parfums")
            .accessibilityHint("Öffnet deine Wunschliste")
        }
        .padding(.horizontal, 16)
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
        .accessibilityLabel("Abmelden")
        .accessibilityHint("Doppeltippen, um dich abzumelden")
    }
    
    // MARK: - App Info
    
    private var appInfoRow: some View {
        HStack {
            Text("Version")
                .foregroundColor(Color(hex: "#94A3B8"))
            Spacer()
            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–")
                .foregroundColor(Color(hex: "#94A3B8"))
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
                                .accessibilityLabel("Benutzername")
                        }
                        .padding(16)
                        .glassPanel()
                    }
                    
                    Button {
                        saveUsername()
                    } label: {
                        if editState == .saving {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Speichern")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(usernameInput.trimmingCharacters(in: .whitespaces).isEmpty || editState == .saving || authManager.isLoading)
                    
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
                        editState = .idle
                    }
                    .foregroundColor(Color(hex: "#94A3B8"))
                    .disabled(editState == .saving)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Share Collection

    private var shareCollectionButton: some View {
        Button {
            renderAndShare()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18))
                    .foregroundStyle(DesignSystem.Colors.champagne)
                    .frame(width: 36, height: 36)
                    .background(DesignSystem.Colors.champagne.opacity(0.12))
                    .clipShape(Circle())

                Text("Sammlung teilen")
                    .font(DesignSystem.Fonts.display(size: 16, weight: .medium))
                    .foregroundStyle(.white)

                Spacer()

                if isRenderingShareImage {
                    ProgressView()
                        .tint(Color(hex: "#94A3B8"))
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: "#94A3B8"))
                }
            }
            .padding(16)
            .glassPanel()
        }
        .disabled(isRenderingShareImage)
        .accessibilityLabel("Sammlung teilen")
        .accessibilityHint("Erstellt ein Bild deiner Sammlung zum Teilen")
    }

    private func renderAndShare() {
        isRenderingShareImage = true
        let perfumes = ownedPerfumes
        let username = authManager.username ?? "scentboxd"
        let favCount = favoritePerfumes.count

        Task {
            let image = await CollectionExportService.renderCollectionImage(
                perfumes: perfumes,
                username: username,
                favoriteCount: favCount
            )
            shareImage = image
            isRenderingShareImage = false
            if image != nil {
                showShareSheet = true
            }
        }
    }

    // MARK: - Bio Edit Sheet

    private var bioEditSheet: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.bgDark.ignoresSafeArea()

                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("BIO")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2)
                            .foregroundColor(DesignSystem.Colors.primary)

                        TextEditor(text: $bioText)
                            .scrollContentBackground(.hidden)
                            .foregroundColor(.white)
                            .frame(minHeight: 100, maxHeight: 200)
                            .padding(12)
                            .glassPanel()

                        Text("\(bioText.count)/200")
                            .font(.caption2)
                            .foregroundColor(Color(hex: "#94A3B8"))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    Button {
                        Task { await saveBio() }
                    } label: {
                        if isSavingBio {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Speichern")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isSavingBio || bioText.count > 200)

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Bio bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        showBioSheet = false
                    }
                    .foregroundColor(Color(hex: "#94A3B8"))
                    .disabled(isSavingBio)
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
        reviewCountError = nil
        
        do {
            reviewCount = try await dependencies.reviewDataSource.fetchReviewCount(for: currentUserIdString)
        } catch {
            reviewCountError = "Bewertungen konnten nicht geladen werden."
            AppLogger.reviews.error("Failed to load review count: \(error.localizedDescription)")
        }
    }
    
    private func loadProfileSettings() async {
        guard let userId = authManager.currentUser?.id else { return }
        do {
            let profile = try await dependencies.publicProfileDataSource.fetchPublicProfile(userId: userId)
            isProfilePublic = profile.isPublic
            bioText = profile.bio ?? ""
        } catch {
            // Silently fail — use defaults
            AppLogger.auth.debug("Could not load profile settings: \(error.localizedDescription)")
        }
    }

    private func updateProfileVisibility(isPublic: Bool) async {
        guard let userId = authManager.currentUser?.id else { return }
        do {
            try await dependencies.publicProfileDataSource.updateProfileVisibility(userId: userId, isPublic: isPublic)
        } catch {
            AppLogger.auth.error("Failed to update profile visibility: \(error.localizedDescription)")
        }
    }

    private func saveBio() async {
        guard let userId = authManager.currentUser?.id else { return }
        isSavingBio = true
        do {
            try await dependencies.publicProfileDataSource.updateBio(userId: userId, bio: bioText)
            showBioSheet = false
        } catch {
            AppLogger.auth.error("Failed to save bio: \(error.localizedDescription)")
        }
        isSavingBio = false
    }

    private func saveUsername() {
        let trimmed = usernameInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        editState = .saving
        usernameSaveTask?.cancel()
        
        usernameSaveTask = Task {
            let success = await authManager.saveUsername(trimmed)
            if success {
                editState = .success
                
                // Keep the sleep in the same task
                try? await Task.sleep(for: .seconds(2))
                
                // Only reset if we are still in success state
                if !Task.isCancelled && editState == .success {
                    editState = .idle
                }
            } else {
                if !Task.isCancelled {
                    editState = .editing
                }
            }
        }
    }
}

// MARK: - UIActivityViewController Wrapper

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview("Logged In") {
    ProfileView()
        .environment(AuthManager(profileService: ProfileService()))
}
