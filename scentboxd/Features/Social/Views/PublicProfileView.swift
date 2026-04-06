//
//  PublicProfileView.swift
//  scentboxd
//

import SwiftUI
import NukeUI
import os

struct PublicProfileView: View {
    let userId: UUID

    @Environment(\.dependencies) private var dependencies
    @State private var viewModel: PublicProfileViewModel?
    @State private var selectedTab: ProfileTab = .collection

    enum ProfileTab: String, CaseIterable {
        case collection = "Sammlung"
        case reviews = "Bewertungen"
        case lists = "Listen"
    }

    var body: some View {
        ZStack {
            DesignSystem.Colors.appBackground.ignoresSafeArea()

            if let vm = viewModel {
                if vm.isLoading && vm.profile == nil {
                    ProgressView("Profil laden...")
                        .tint(DesignSystem.Colors.primary)
                        .foregroundColor(DesignSystem.Colors.primary)
                } else if let error = vm.errorMessage, vm.profile == nil {
                    errorView(message: error)
                } else if let profile = vm.profile {
                    if !profile.isPublic {
                        privateProfileView(username: profile.username)
                    } else {
                        profileContentView(profile: profile, vm: vm)
                    }
                }
            }
        }
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let vm = PublicProfileViewModel(dataSource: dependencies.publicProfileDataSource)
            viewModel = vm
            await vm.loadProfile(userId: userId)
            if vm.profile?.isPublic == true {
                await vm.loadCollection(userId: userId)
            }
        }
    }

    // MARK: - Profile Content

    private func profileContentView(profile: PublicProfileDTO, vm: PublicProfileViewModel) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                profileHeader(profile: profile)
                statsGrid(profile: profile)
                tabPicker

                switch selectedTab {
                case .collection:
                    collectionGrid(vm: vm)
                case .reviews:
                    PublicUserReviewsSection(userId: userId)
                case .lists:
                    PublicListsSection(userId: userId)
                }
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: - Header

    private func profileHeader(profile: PublicProfileDTO) -> some View {
        VStack(spacing: 16) {
            // Avatar
            if let avatarUrlString = profile.avatarUrl,
               let avatarUrl = URL(string: avatarUrlString) {
                LazyImage(url: avatarUrl) { state in
                    if let image = state.image {
                        image.resizable().scaledToFill()
                    } else {
                        avatarPlaceholder
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                .overlay(Circle().stroke(DesignSystem.Colors.primary.opacity(0.3), lineWidth: 2))
            } else {
                avatarPlaceholder
            }

            // Username
            Text("@\(profile.username)")
                .font(DesignSystem.Fonts.serif(size: 22, weight: .bold))
                .foregroundStyle(Color.primary)

            // Bio
            if let bio = profile.bio, !bio.isEmpty {
                Text(bio)
                    .font(.subheadline)
                    .foregroundColor(Color.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Member Since
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption2)
                Text("Mitglied seit \(profile.memberSince.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
            }
            .foregroundColor(Color(hex: "#94A3B8"))
        }
        .padding(.top, 16)
    }

    private var avatarPlaceholder: some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .frame(width: 80, height: 80)
            .foregroundColor(DesignSystem.Colors.primary.opacity(0.4))
    }

    // MARK: - Stats

    private func statsGrid(profile: PublicProfileDTO) -> some View {
        HStack(spacing: 0) {
            statItem(value: "\(profile.ownedCount)", label: "Sammlung")
            Divider()
                .frame(height: 40)
                .background(Color.primary.opacity(0.1))
            statItem(value: "\(profile.reviewCount)", label: "Bewertungen")
            Divider()
                .frame(height: 40)
                .background(Color.primary.opacity(0.1))
            statItem(value: "\(profile.favoriteCount)", label: "Favoriten")
        }
        .padding(.vertical, 16)
        .glassPanel()
        .padding(.horizontal, 16)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(DesignSystem.Fonts.serif(size: 20, weight: .bold))
                .foregroundStyle(Color.primary)
            Text(label)
                .font(.caption)
                .foregroundColor(Color(hex: "#94A3B8"))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(ProfileTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.subheadline)
                        .fontWeight(selectedTab == tab ? .semibold : .regular)
                        .foregroundColor(selectedTab == tab ? .white : Color(hex: "#94A3B8"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            selectedTab == tab
                                ? DesignSystem.Colors.primary.opacity(0.2)
                                : Color.clear
                        )
                }
            }
        }
        .background(Color.primary.opacity(0.05))
        .cornerRadius(10)
        .padding(.horizontal, 16)
    }

    // MARK: - Collection Grid

    private func collectionGrid(vm: PublicProfileViewModel) -> some View {
        Group {
            if vm.collection.isEmpty && !vm.isLoadingCollection {
                VStack(spacing: 12) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 36))
                        .foregroundColor(DesignSystem.Colors.primary.opacity(0.4))
                    Text("Noch keine Parfums in der Sammlung")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "#94A3B8"))
                }
                .padding(.top, 40)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    ForEach(vm.collection) { item in
                        NavigationLink(destination: PerfumeDetailView(perfumeId: item.id)) {
                            PublicPerfumeCard(item: item)
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            if item.id == vm.collection.last?.id {
                                Task { await vm.loadCollection(userId: userId) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)

                if vm.isLoadingCollection {
                    ProgressView()
                        .tint(DesignSystem.Colors.primary)
                        .padding()
                }
            }
        }
    }

    // MARK: - Error

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.red.opacity(0.8))
            Text(message)
                .font(.subheadline)
                .foregroundColor(Color(hex: "#94A3B8"))
                .multilineTextAlignment(.center)
            Button("Erneut versuchen") {
                Task {
                    await viewModel?.loadProfile(userId: userId)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignSystem.Colors.primary)
        }
        .padding()
    }

    // MARK: - Private Profile

    private func privateProfileView(username: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundColor(DesignSystem.Colors.primary.opacity(0.5))
            Text("Privates Profil")
                .font(DesignSystem.Fonts.serif(size: 22, weight: .bold))
                .foregroundStyle(Color.primary)
            Text("@\(username) hat sein Profil auf privat gestellt.")
                .font(.subheadline)
                .foregroundColor(Color(hex: "#94A3B8"))
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Public Perfume Card (simplified, no compare/favorite actions)

private struct PublicPerfumeCard: View {
    let item: PublicCollectionItemDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image
            ZStack {
                Color.clear
                    .aspectRatio(3/4, contentMode: .fit)
                    .overlay {
                        if let urlString = item.imageUrl, let url = URL(string: urlString) {
                            LazyImage(url: url) { state in
                                if let image = state.image {
                                    image.resizable().scaledToFill()
                                } else {
                                    DesignSystem.Colors.appSurface
                                }
                            }
                            .transition(.opacity)
                        } else {
                            ZStack {
                                DesignSystem.Colors.appSurface
                                Image(systemName: "flame.circle.fill")
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(DesignSystem.Colors.primary.opacity(0.3))
                            }
                        }
                    }
                    .clipped()
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(DesignSystem.Fonts.serif(size: 15, weight: .bold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                if let concentration = item.concentration, !concentration.isEmpty {
                    Text(concentration.uppercased())
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(DesignSystem.Colors.primary.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .padding(10)
        }
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DesignSystem.Colors.primary.opacity(0.1), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Public Lists Section

struct PublicListsSection: View {
    let userId: UUID

    @Environment(\.dependencies) private var dependencies
    @State private var lists: [CuratedListDTO] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .tint(DesignSystem.Colors.primary)
                    .padding(.top, 40)
            } else if let error = errorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "#94A3B8"))
                    .padding()
            } else if lists.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bookmark.slash")
                        .font(.system(size: 36))
                        .foregroundColor(DesignSystem.Colors.primary.opacity(0.4))
                    Text("Keine öffentlichen Listen")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "#94A3B8"))
                }
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(lists) { list in
                        NavigationLink(destination: PublicListDetailView(list: list)) {
                            publicListRow(list: list)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .task {
            await loadLists()
        }
    }

    private func publicListRow(list: CuratedListDTO) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 16))
                .foregroundStyle(DesignSystem.Colors.champagne)
                .frame(width: 36, height: 36)
                .background(DesignSystem.Colors.champagne.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(list.name)
                    .font(DesignSystem.Fonts.display(size: 15, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                Text("\(list.itemCount ?? 0) Parfums")
                    .font(.caption)
                    .foregroundColor(Color(hex: "#94A3B8"))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "#94A3B8"))
        }
        .padding(16)
        .glassPanel()
    }

    private func loadLists() async {
        isLoading = true
        do {
            lists = try await dependencies.curatedListDataSource.fetchPublicLists(userId: userId)
        } catch {
            errorMessage = NetworkError.handle(error, logger: AppLogger.lists, context: "fetchPublicLists")
        }
        isLoading = false
    }
}

// MARK: - Public List Detail (read-only)

struct PublicListDetailView: View {
    let list: CuratedListDTO

    @Environment(\.dependencies) private var dependencies
    @State private var perfumes: [Perfume] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            DesignSystem.Colors.appBackground.ignoresSafeArea()
            if isLoading {
                ProgressView().tint(DesignSystem.Colors.primary)
            } else if let error = errorMessage {
                Text(error).font(.subheadline).foregroundColor(Color(hex: "#94A3B8")).padding()
            } else if perfumes.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 48))
                        .foregroundColor(DesignSystem.Colors.primary.opacity(0.4))
                    Text("Keine Parfums in dieser Liste")
                        .font(.subheadline).foregroundColor(Color(hex: "#94A3B8"))
                }
            } else {
                ScrollView(showsIndicators: false) {
                    if let desc = list.description, !desc.isEmpty {
                        Text(desc)
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "#94A3B8"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    }
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        ForEach(perfumes) { perfume in
                            NavigationLink(destination: PerfumeDetailView(perfume: perfume)) {
                                PerfumeCardView(perfume: perfume)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle(list.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadPerfumes() }
    }

    private func loadPerfumes() async {
        isLoading = true
        do {
            let ids = try await dependencies.curatedListDataSource.fetchListItems(listId: list.id)
            perfumes = ids.isEmpty ? [] : try await dependencies.perfumeRepository.fetchPerfumesByIds(ids)
        } catch {
            errorMessage = NetworkError.handle(error, logger: AppLogger.lists, context: "PublicListDetailView")
        }
        isLoading = false
    }
}

// MARK: - Public User Reviews Section

struct PublicUserReviewsSection: View {
    let userId: UUID

    @Environment(\.dependencies) private var dependencies
    @State private var reviews: [ReviewDTO] = []
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var currentPage = 0
    @State private var hasMorePages = true

    private let pageSize = AppConfig.Pagination.reviewPageSize

    var body: some View {
        Group {
            if isLoading && reviews.isEmpty {
                ProgressView()
                    .tint(DesignSystem.Colors.primary)
                    .padding(.top, 40)
            } else if let error = errorMessage, reviews.isEmpty {
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "#94A3B8"))
                    .padding()
            } else if reviews.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "text.quote")
                        .font(.system(size: 36))
                        .foregroundColor(DesignSystem.Colors.primary.opacity(0.4))
                    Text("Noch keine Bewertungen")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "#94A3B8"))
                }
                .padding(.top, 40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(reviews, id: \.id) { reviewDTO in
                        publicReviewCard(reviewDTO: reviewDTO)
                            .onAppear {
                                if reviewDTO.id == reviews.last?.id {
                                    Task { await loadMoreReviews() }
                                }
                            }
                    }

                    if isLoadingMore {
                        ProgressView()
                            .tint(DesignSystem.Colors.primary)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .task {
            await loadReviews()
        }
    }

    private func loadReviews() async {
        isLoading = true
        currentPage = 0
        hasMorePages = true
        do {
            let page = try await dependencies.reviewDataSource.fetchReviewsByUser(
                userId: userId, page: 0, pageSize: pageSize
            )
            reviews = page
            hasMorePages = page.count >= pageSize
            currentPage = 1
        } catch {
            errorMessage = String(localized: "Bewertungen konnten nicht geladen werden.")
            AppLogger.reviews.error("Failed to load public reviews: \(error.localizedDescription)")
        }
        isLoading = false
    }

    private func loadMoreReviews() async {
        guard !isLoadingMore, hasMorePages else { return }
        isLoadingMore = true
        do {
            let page = try await dependencies.reviewDataSource.fetchReviewsByUser(
                userId: userId, page: currentPage, pageSize: pageSize
            )
            reviews.append(contentsOf: page)
            hasMorePages = page.count >= pageSize
            currentPage += 1
        } catch {
            AppLogger.reviews.error("Failed to load more public reviews: \(error.localizedDescription)")
        }
        isLoadingMore = false
    }

    private func publicReviewCard(reviewDTO: ReviewDTO) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Date
            HStack {
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= (reviewDTO.rating ?? 0) ? "star.fill" : "star")
                            .font(.caption)
                            .foregroundColor(star <= (reviewDTO.rating ?? 0) ? DesignSystem.Colors.champagne : Color.primary.opacity(0.2))
                    }
                }
                Spacer()
                Text(reviewDTO.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundColor(Color(hex: "#94A3B8"))
            }

            if !reviewDTO.title.isEmpty {
                Text(reviewDTO.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.primary)
            }

            if !reviewDTO.text.isEmpty {
                Text(reviewDTO.text)
                    .font(.subheadline)
                    .foregroundColor(Color.secondary)
                    .lineLimit(4)
            }
        }
        .padding(16)
        .glassPanel()
    }
}
