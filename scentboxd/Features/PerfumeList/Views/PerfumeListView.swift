import SwiftUI
import SwiftData
import Nuke
import NukeUI

struct PerfumeListView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Environment(PerfumeListViewModel.self) var viewModel
    @Environment(PerfumeFilterViewModel.self) var filterVM

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        @Bindable var viewModel = viewModel
        @Bindable var filterVM = filterVM
        NavigationStack {
            ZStack {
                DesignSystem.Colors.bgDark.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Offline-Banner
                        if viewModel.dataLoader.isOffline && !viewModel.dataLoader.perfumes.isEmpty {
                            offlineBanner
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                        }
                        
                        // Floating Filter Section
                        filterChipsSection
                            .padding(.top, 12)
                            .padding(.bottom, 8)
                        
                        // Result Count
                        if let total = viewModel.dataLoader.totalCount, !viewModel.dataLoader.isLoading {
                            resultCountRow(total: total)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                        }
                        
                        // Error
                        if let errorMessage = viewModel.dataLoader.errorMessage {
                            errorView(message: errorMessage)
                                .padding(.horizontal, 16)
                        }
                        
                        // Loading Skeletons
                        if viewModel.dataLoader.isLoading {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(0..<4, id: \.self) { _ in
                                    skeletonCard
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        
                        // Perfume Grid
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(viewModel.dataLoader.perfumes) { perfume in
                                NavigationLink(destination: PerfumeDetailView(perfume: perfume)) {
                                    PerfumeCardView(
                                        perfume: perfume,
                                        ratingStats: viewModel.dataLoader.ratingStatsMap[perfume.id]
                                    )
                                }
                                .buttonStyle(.plain)
                                .onAppear {
                                    Task {
                                        await viewModel.loadMoreIfNeeded(currentItem: perfume)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        // Load More Indicator
                        if viewModel.dataLoader.isLoadingMore {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .tint(DesignSystem.Colors.primary)
                                Spacer()
                            }
                            .padding(.vertical, 16)
                        }
                        
                        Spacer(minLength: 20)
                    }
                }
                .refreshable {
                    await viewModel.refresh()
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Suche Parfum...")
            .navigationTitle("ScentBox")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                // MARK: - Sort Menu
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        ForEach(PerfumeSortOption.allCases) { option in
                            Button {
                                filterVM.sortOption = option
                            } label: {
                                Label {
                                    Text(option.localizedName)
                                } icon: {
                                    if filterVM.sortOption == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Label("Sortieren", systemImage: "arrow.up.arrow.down")
                            .foregroundColor(DesignSystem.Colors.primary)
                    }
                }
            }
            .sheet(isPresented: $filterVM.isFilterSheetPresented) {
                FilterSheetView(filter: filterVM.activeFilter, sort: filterVM.sortOption)
                    .environment(filterVM)
            }
            .task {
                await filterVM.loadAvailableFilterOptions()
            }
        }
    }
    
    // MARK: - Filter Chips
    
    private var filterChipsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // Primary Filter Button
                Button {
                    filterVM.isFilterSheetPresented = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 14))
                        Text("Filter")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(DesignSystem.Colors.primary)
                    .clipShape(Capsule())
                    .shadow(color: DesignSystem.Colors.primary.opacity(0.3), radius: 6, x: 0, y: 3)
                }

                // Active filter chips
                if let brand = filterVM.activeFilter.brandName {
                    activeChip(text: "Marke: \(brand)") {
                        filterVM.activeFilter.brandName = nil
                    }
                }
                if let conc = filterVM.activeFilter.concentration {
                    activeChip(text: conc.uppercased()) {
                        filterVM.activeFilter.concentration = nil
                    }
                }
                if let longevity = filterVM.activeFilter.longevity {
                    activeChip(text: "Longevity: \(longevity)") {
                        filterVM.activeFilter.longevity = nil
                    }
                }
                if let sillage = filterVM.activeFilter.sillage {
                    activeChip(text: "Sillage: \(sillage)") {
                        filterVM.activeFilter.sillage = nil
                    }
                }
                ForEach(filterVM.activeFilter.noteNames, id: \.self) { note in
                    activeChip(text: "🌿 \(note)") {
                        filterVM.activeFilter.noteNames.removeAll { $0 == note }
                    }
                }
                ForEach(filterVM.activeFilter.occasions, id: \.self) { occasion in
                    activeChip(text: "📅 \(occasion)") {
                        filterVM.activeFilter.occasions.removeAll { $0 == occasion }
                    }
                }
                if filterVM.activeFilter.minRating != nil || filterVM.activeFilter.maxRating != nil {
                    let min = filterVM.activeFilter.minRating ?? 0
                    let max = filterVM.activeFilter.maxRating ?? 5
                    activeChip(text: "⭐ \(String(format: "%.1f", min))–\(String(format: "%.1f", max))") {
                        filterVM.activeFilter.minRating = nil
                        filterVM.activeFilter.maxRating = nil
                    }
                }

                // Clear all
                if !filterVM.activeFilter.isEmpty {
                    Button {
                        filterVM.activeFilter = PerfumeFilter()
                    } label: {
                        Text("Alle löschen")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red.opacity(0.8))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    private func activeChip(text: String, onRemove: @escaping () -> Void) -> some View {
        Button(action: onRemove) {
            HStack(spacing: 4) {
                Text(text)
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundColor(.white.opacity(0.85))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(DesignSystem.Colors.surfaceDark)
            .overlay(Capsule().stroke(DesignSystem.Colors.primary.opacity(0.2), lineWidth: 1))
            .clipShape(Capsule())
        }
    }
    
    // MARK: - Subviews
    
    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Offline-Modus — Daten eventuell nicht aktuell"))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                if let lastSync = viewModel.dataLoader.lastSyncedAt {
                    Text("Zuletzt synchronisiert: ") + Text(lastSync, style: .relative)
                        .font(.caption2)
                        .foregroundColor(Color(hex: "#94A3B8"))
                }
            }
            Spacer()
        }
        .padding(10)
        .background(Color.orange.opacity(0.12))
        .cornerRadius(8)
    }
    
    private func resultCountRow(total: Int) -> some View {
        HStack {
            Image(systemName: "number")
                .foregroundColor(Color(hex: "#94A3B8"))
            if viewModel.searchText.isEmpty && filterVM.activeFilter.isEmpty {
                Text(String(localized: "\(total) Parfums im Katalog"))
            } else {
                Text(String(localized: "\(total) Ergebnis\(total == 1 ? "" : "se")"))
            }
            Spacer()
        }
        .font(.caption)
        .foregroundColor(Color(hex: "#94A3B8"))
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.largeTitle)
                .foregroundColor(.red.opacity(0.7))
            Text(message)
                .font(.subheadline)
                .foregroundColor(Color(hex: "#94A3B8"))
                .multilineTextAlignment(.center)
            Button {
                Task { await viewModel.loadData() }
            } label: {
                Label("Erneut versuchen", systemImage: "arrow.clockwise")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
    
    // MARK: - Skeleton Card
    
    private var skeletonCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 0)
                .fill(DesignSystem.Colors.surfaceDark)
                .aspectRatio(3/4, contentMode: .fit)
                .shimmer()
            
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 12)
                    .frame(maxWidth: 80)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 10)
                    .frame(maxWidth: 60)
            }
            .padding(10)
        }
        .glassPanel()
    }
}

// MARK: - Perfume Card View (Grid Item)

struct PerfumeCardView: View {
    let perfume: Perfume
    var ratingStats: RatingStats? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image Section
            Color.clear
                .aspectRatio(3/4, contentMode: .fit)
                .overlay {
                    if let url = perfume.imageUrl {
                        let request = ImageRequest(
                            url: url,
                            processors: [.resize(size: CGSize(width: 300, height: 400), contentMode: .aspectFill)],
                            priority: .high
                        )
                        LazyImage(request: request) { state in
                            if let image = state.image {
                                image
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                DesignSystem.Colors.surfaceDark
                            }
                        }
                        .transition(.opacity)
                    } else {
                        ZStack {
                            DesignSystem.Colors.surfaceDark
                            Image(systemName: "flame.circle.fill")
                                .resizable()
                                .frame(width: 40, height: 40)
                                .foregroundColor(DesignSystem.Colors.primary.opacity(0.3))
                        }
                    }
                }
                .clipped()
            
            // Info Section
            VStack(alignment: .leading, spacing: 4) {
                // Rating (always reserve space for consistent card height)
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.Colors.primary)
                    Text(String(format: "%.1f", ratingStats?.avgRating ?? 0))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.primary)
                }
                .opacity(ratingStats != nil && ratingStats!.reviewCount > 0 ? 1 : 0)
                
                // Name
                Text(perfume.name)
                    .font(DesignSystem.Fonts.serif(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                // Brand
                Text(perfume.brand?.name ?? String(localized: "Unbekannte Marke"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.primary.opacity(0.8))
                    .lineLimit(1)
                
                // Top Notes Preview
                if !perfume.topNotes.isEmpty {
                    Text(perfume.topNotes.map(\.name).joined(separator: ", "))
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: "#94A3B8"))
                        .lineLimit(1)
                        .padding(.top, 1)
                }
                
                // Concentration Badge
                if let concentration = perfume.concentration, !concentration.isEmpty {
                    Text(concentration.uppercased())
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(DesignSystem.Colors.primary.opacity(0.1))
                        .cornerRadius(4)
                        .padding(.top, 4)
                }
            }
            .padding(10)
        }
        .background(DesignSystem.Colors.surfaceDark.opacity(0.6))
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DesignSystem.Colors.primary.opacity(0.1), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Perfume Row View (for list-based views like Favorites & Owned)

struct PerfumeRowView: View {
    let perfume: Perfume
    var ratingStats: RatingStats? = nil
    
    var body: some View {
        HStack {
            // Bild
            if let url = perfume.imageUrl {
                let request = ImageRequest(
                    url: url,
                    processors: [.resize(size: CGSize(width: 120, height: 120), contentMode: .aspectFill)],
                    priority: .high
                )
                LazyImage(request: request) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        DesignSystem.Colors.surfaceDark
                    }
                }
                .transition(.opacity)
                .frame(width: 60, height: 60)
                .cornerRadius(8)
                .clipped()
            } else {
                Image(systemName: "flame.circle.fill")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .foregroundColor(DesignSystem.Colors.primary.opacity(0.3))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(perfume.name)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(perfume.brand?.name ?? String(localized: "Unbekannte Marke"))
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "#94A3B8"))
                HStack(spacing: 4) {
                    if let concentration = perfume.concentration, !concentration.isEmpty {
                        Text(concentration.uppercased())
                            .font(.caption)
                            .foregroundColor(Color(hex: "#94A3B8"))
                    }
                    Spacer()
                    if let stats = ratingStats, stats.reviewCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(DesignSystem.Colors.champagne)
                            Text(String(format: "%.1f", stats.avgRating))
                                .font(.caption)
                                .foregroundColor(Color(hex: "#94A3B8"))
                            Text("(\(stats.reviewCount))")
                                .font(.caption2)
                                .foregroundColor(Color(hex: "#94A3B8"))
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    let container = DependencyContainer()
    let filterVM = container.makePerfumeFilterViewModel()
    PerfumeListView()
        .environment(container.makePerfumeListViewModel(filterVM: filterVM))
        .environment(filterVM)
}
