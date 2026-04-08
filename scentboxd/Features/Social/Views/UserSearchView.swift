//
//  UserSearchView.swift
//  scentboxd
//

import SwiftUI
import Combine
import os

struct UserSearchView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var searchText = ""
    @State private var results: [PublicProfileDTO] = []
    @State private var isSearching = false
    @State private var hasSearched = false

    private let searchSubject = PassthroughSubject<String, Never>()
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        ZStack {
            DesignSystem.Colors.appBackground.ignoresSafeArea()

            Group {
                if !hasSearched && results.isEmpty && !isSearching {
                    searchPrompt
                } else if isSearching && results.isEmpty {
                    ProgressView("Suche...")
                        .tint(DesignSystem.Colors.primary)
                        .foregroundColor(DesignSystem.Colors.primary)
                } else if hasSearched && results.isEmpty {
                    noResultsView
                } else {
                    resultsList
                }
            }
        }
        .navigationTitle("Community")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                ProfileToolbarButton()
            }
        }
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Benutzername suchen..."
        )
        .onChange(of: searchText) { _, newValue in
            searchSubject.send(newValue)
        }
        .onAppear {
            setupSearchBinding()
        }
    }

    // MARK: - Subviews

    private var searchPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 48))
                .foregroundColor(DesignSystem.Colors.primary.opacity(0.4))
            Text("Entdecke andere Duftliebhaber")
                .font(DesignSystem.Fonts.serif(size: 20, weight: .semibold))
                .foregroundStyle(Color.primary)
            Text("Suche nach Benutzernamen, um Profile und Sammlungen zu entdecken.")
                .font(.subheadline)
                .foregroundColor(Color(hex: "#94A3B8"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.slash")
                .font(.system(size: 36))
                .foregroundColor(DesignSystem.Colors.primary.opacity(0.4))
            Text("Keine Benutzer gefunden")
                .font(.subheadline)
                .foregroundColor(Color(hex: "#94A3B8"))
        }
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(results) { profile in
                    NavigationLink(destination: PublicProfileView(userId: profile.id)) {
                        userSearchRow(profile: profile)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
    }

    private func userSearchRow(profile: PublicProfileDTO) -> some View {
        HStack(spacing: 14) {
            // Avatar
            if let avatarUrlString = profile.avatarUrl,
               let avatarUrl = URL(string: avatarUrlString) {
                AsyncImage(url: avatarUrl) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    searchAvatarPlaceholder
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
            } else {
                searchAvatarPlaceholder
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text("@\(profile.username)")
                    .font(DesignSystem.Fonts.display(size: 15, weight: .semibold))
                    .foregroundStyle(Color.primary)

                if let bio = profile.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(Color(hex: "#94A3B8"))
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "#94A3B8"))
        }
        .padding(14)
        .glassPanel()
        .accessibilityLabel("Profil von \(profile.username)")
        .accessibilityHint("Öffnet das öffentliche Profil")
    }

    private var searchAvatarPlaceholder: some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .frame(width: 48, height: 48)
            .foregroundColor(DesignSystem.Colors.primary.opacity(0.4))
    }

    // MARK: - Search Binding

    private func setupSearchBinding() {
        searchSubject
            .debounce(for: .milliseconds(AppConfig.Timing.searchDebounceMs), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { query in
                Task { await performSearch(query: query) }
            }
            .store(in: &cancellables)
    }

    private func performSearch(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            results = []
            hasSearched = false
            return
        }

        isSearching = true
        do {
            results = try await dependencies.publicProfileDataSource.searchUsers(query: trimmed)
        } catch {
            AppLogger.auth.error("User search failed: \(error.localizedDescription)")
            results = []
        }
        hasSearched = true
        isSearching = false
    }
}

#Preview {
    NavigationStack {
        UserSearchView()
    }
}
