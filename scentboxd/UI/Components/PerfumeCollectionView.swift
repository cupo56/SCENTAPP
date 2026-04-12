//
//  PerfumeCollectionView.swift
//  scentboxd
//
//  Generic collection view for filtered perfume lists (Favorites, Owned, etc.).
//

import SwiftUI

struct PerfumeCollectionView<FilterContent: View>: View {
    let perfumes: [Perfume]
    let emptyTitle: LocalizedStringKey
    let emptyIcon: String
    let emptyDescription: Text
    let navigationTitle: LocalizedStringKey
    let refreshAction: (() async -> Void)?
    let isRefreshing: Bool
    @ViewBuilder let headerContent: FilterContent
    
    init(
        perfumes: [Perfume],
        emptyTitle: LocalizedStringKey,
        emptyIcon: String,
        emptyDescription: Text,
        navigationTitle: LocalizedStringKey,
        refreshAction: (() async -> Void)? = nil,
        isRefreshing: Bool = false,
        @ViewBuilder headerContent: () -> FilterContent
    ) {
        self.perfumes = perfumes
        self.emptyTitle = emptyTitle
        self.emptyIcon = emptyIcon
        self.emptyDescription = emptyDescription
        self.navigationTitle = navigationTitle
        self.refreshAction = refreshAction
        self.isRefreshing = isRefreshing
        self.headerContent = headerContent()
    }
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                DesignSystem.Colors.appBackground.ignoresSafeArea()

                collectionScrollView

                if isRefreshing {
                    ProgressView("Synchronisiere...")
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.top, 12)
                        .allowsHitTesting(false)
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ProfileToolbarButton()
                }
            }
        }
    }

    @ViewBuilder
    private var collectionScrollView: some View {
        if let refreshAction {
            ScrollView(showsIndicators: false) {
                collectionContent
            }
            .refreshable {
                await refreshAction()
            }
        } else {
            ScrollView(showsIndicators: false) {
                collectionContent
            }
        }
    }

    @ViewBuilder
    private var collectionContent: some View {
        VStack(spacing: 0) {
            if perfumes.isEmpty {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: emptyIcon,
                    description: emptyDescription
                )
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 48)
            } else {
                headerContent
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)

                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(perfumes) { perfume in
                        NavigationLink(destination: PerfumeDetailView(perfume: perfume)) {
                            PerfumeCardView(
                                perfume: perfume,
                                isFavorite: perfume.userMetadata?.isFavorite == true,
                                showTopNotes: false
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(perfume.name), \(perfume.brand?.name ?? "")")
                        .accessibilityHint("Öffnet die Detailseite")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .frame(maxWidth: .infinity, minHeight: perfumes.isEmpty ? 320 : nil, alignment: .top)
    }
}
