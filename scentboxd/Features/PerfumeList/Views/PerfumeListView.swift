import SwiftUI
import SwiftData
import Nuke
import NukeUI

struct PerfumeListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismissSearch) private var dismissSearch
    
    @Environment(PerfumeListViewModel.self) var viewModel
    @Environment(PerfumeFilterViewModel.self) var filterVM
    
    @State private var filterTask: Task<Void, Never>?
    @State private var retryTask: Task<Void, Never>?
    @State private var selectedSuggestionPerfumeId: UUID?
    @State private var showScanner = false
    @State private var scannedPerfume: Perfume?

    @Environment(\.dependencies) private var dependencies

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        @Bindable var viewModel = viewModel
        @Bindable var filterVM = filterVM
        NavigationStack {
            ZStack {
                DesignSystem.Colors.appBackground.ignoresSafeArea()
                
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
                                        ratingStats: viewModel.dataLoader.ratingStatsMap[perfume.id],
                                        showTopNotes: true
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
            .searchable(
                text: $viewModel.searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Suche Parfum..."
            )
            .searchSuggestions {
                if viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 {
                    SearchSuggestionsOverlay(
                        suggestions: viewModel.searchSuggestionService.suggestions,
                        isLoading: viewModel.searchSuggestionService.isLoading,
                        onBrandTap: applyBrandSuggestion,
                        onNoteTap: applyNoteSuggestion,
                        onPerfumeTap: openPerfumeSuggestion
                    )
                }
            }
            .navigationTitle("ScentBox")
            .toolbar {
                // MARK: - Scanner Button
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showScanner = true
                    } label: {
                        Image(systemName: "barcode.viewfinder")
                            .foregroundColor(DesignSystem.Colors.primary)
                    }
                    .accessibilityLabel("Barcode scannen")
                }

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
                    .accessibilityLabel(String(localized: "Sortierung: \(filterVM.sortOption.localizedName)"))
                }
            }
            .sheet(isPresented: $filterVM.isFilterSheetPresented) {
                FilterSheetView(filter: filterVM.activeFilter, sort: filterVM.sortOption)
                    .environment(filterVM)
            }
            .navigationDestination(isPresented: suggestedPerfumeNavigationBinding) {
                if let selectedSuggestionPerfumeId {
                    PerfumeDetailView(perfumeId: selectedSuggestionPerfumeId)
                }
            }
            .navigationDestination(item: $scannedPerfume) { perfume in
                PerfumeDetailView(perfume: perfume)
            }
            .sheet(isPresented: $showScanner) {
                BarcodeScannerView(
                    viewModel: dependencies.makeBarcodeScannerViewModel()
                ) { perfume in
                    scannedPerfume = perfume
                }
                .ignoresSafeArea()
            }
            .onAppear {
                filterTask?.cancel()
                filterTask = Task {
                    await filterVM.loadAvailableFilterOptions()
                }
            }
            .onDisappear {
                filterTask?.cancel()
                retryTask?.cancel()
                viewModel.clearSuggestions()
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
                .accessibilityLabel("Filter")
                .accessibilityHint("Öffnet die Filteroptionen")

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
                    .accessibilityLabel("Alle Filter löschen")
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
            .foregroundColor(Color.primary.opacity(0.85))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(DesignSystem.Colors.appSurface)
            .overlay(Capsule().stroke(DesignSystem.Colors.primary.opacity(0.2), lineWidth: 1))
            .clipShape(Capsule())
        }
        .accessibilityLabel("Filter entfernen: \(text)")
        .accessibilityHint("Doppeltippen, um diesen Filter zu entfernen")
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
                    .foregroundStyle(Color.primary)
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
                retryTask?.cancel()
                retryTask = Task { await viewModel.loadData() }
            } label: {
                Label("Erneut versuchen", systemImage: "arrow.clockwise")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityLabel("Erneut versuchen")
            .accessibilityHint("Doppeltippen, um die Daten erneut zu laden")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
    
    // MARK: - Skeleton Card
    
    private var skeletonCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 0)
                .fill(DesignSystem.Colors.appSurface)
                .aspectRatio(3/4, contentMode: .fit)
                .shimmer()
            
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.1))
                    .frame(height: 12)
                    .frame(maxWidth: 80)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: 10)
                    .frame(maxWidth: 60)
            }
            .padding(10)
        }
        .glassPanel()
    }

    private var suggestedPerfumeNavigationBinding: Binding<Bool> {
        Binding(
            get: { selectedSuggestionPerfumeId != nil },
            set: { isPresented in
                if !isPresented {
                    selectedSuggestionPerfumeId = nil
                }
            }
        )
    }

    private func applyBrandSuggestion(_ brand: String) {
        filterVM.activeFilter.brandName = brand
        viewModel.searchText = ""
        viewModel.clearSuggestions()
        dismissSearch()
    }

    private func applyNoteSuggestion(_ note: String) {
        if !filterVM.activeFilter.noteNames.contains(note) {
            filterVM.activeFilter.noteNames.append(note)
        }
        viewModel.searchText = ""
        viewModel.clearSuggestions()
        dismissSearch()
    }

    private func openPerfumeSuggestion(_ perfumeId: UUID) {
        selectedSuggestionPerfumeId = perfumeId
        viewModel.clearSuggestions()
        dismissSearch()
    }
}

// MARK: - Perfume Row View (for list-based views like Favorites & Owned)

struct PerfumeRowView: View {
    let perfume: Perfume
    var ratingStats: RatingStats?
    
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
                        DesignSystem.Colors.appSurface
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
                    .foregroundStyle(Color.primary)
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
