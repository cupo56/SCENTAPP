import SwiftUI
import SwiftData
import Nuke
import NukeUI

struct PerfumeListView: View {
    @Environment(\.modelContext) private var modelContext
    
    @EnvironmentObject var viewModel: PerfumeListViewModel
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.bgDark.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Offline-Banner
                        if viewModel.isOffline && !viewModel.perfumes.isEmpty {
                            offlineBanner
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                        }
                        
                        // Floating Filter Section
                        filterChipsSection
                            .padding(.top, 12)
                            .padding(.bottom, 8)
                        
                        // Result Count
                        if let total = viewModel.totalCount, !viewModel.isLoading {
                            resultCountRow(total: total)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                        }
                        
                        // Error
                        if let errorMessage = viewModel.errorMessage {
                            errorView(message: errorMessage)
                                .padding(.horizontal, 16)
                        }
                        
                        // Loading Skeletons
                        if viewModel.isLoading {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(0..<4, id: \.self) { _ in
                                    skeletonCard
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        
                        // Perfume Grid
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(viewModel.perfumes) { perfume in
                                NavigationLink(destination: PerfumeDetailView(perfume: perfume)) {
                                    PerfumeCardView(
                                        perfume: perfume,
                                        ratingStats: viewModel.ratingStatsMap[perfume.id]
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
                        if viewModel.isLoadingMore {
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
                                viewModel.sortOption = option
                            } label: {
                                Label {
                                    Text(option.rawValue)
                                } icon: {
                                    if viewModel.sortOption == option {
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
                
                // MARK: - Filter Button
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.isFilterSheetPresented = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.body)
                                .foregroundColor(DesignSystem.Colors.primary)
                            
                            if viewModel.activeFilter.activeFilterCount > 0 {
                                Text("\(viewModel.activeFilter.activeFilterCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 16, height: 16)
                                    .background(DesignSystem.Colors.primary)
                                    .clipShape(Circle())
                                    .offset(x: 6, y: -6)
                            }
                        }
                    }
                    .accessibilityLabel(viewModel.activeFilter.activeFilterCount > 0
                        ? "Filter, \(viewModel.activeFilter.activeFilterCount) aktiv"
                        : "Filter")
                }
            }
            .sheet(isPresented: $viewModel.isFilterSheetPresented) {
                FilterSheetView(filter: viewModel.activeFilter, sort: viewModel.sortOption)
                    .environmentObject(viewModel)
            }
            .task {
                await viewModel.loadAvailableFilterOptions()
            }
        }
    }
    
    // MARK: - Filter Chips
    
    private var filterChipsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // Primary Filter Button
                Button {
                    viewModel.isFilterSheetPresented = true
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
                if let brand = viewModel.activeFilter.brandName {
                    activeChip(text: "Marke: \(brand)") {
                        viewModel.activeFilter.brandName = nil
                    }
                }
                if let conc = viewModel.activeFilter.concentration {
                    activeChip(text: conc.uppercased()) {
                        viewModel.activeFilter.concentration = nil
                    }
                }
                if let longevity = viewModel.activeFilter.longevity {
                    activeChip(text: "Longevity: \(longevity)") {
                        viewModel.activeFilter.longevity = nil
                    }
                }
                if let sillage = viewModel.activeFilter.sillage {
                    activeChip(text: "Sillage: \(sillage)") {
                        viewModel.activeFilter.sillage = nil
                    }
                }
                ForEach(viewModel.activeFilter.noteNames, id: \.self) { note in
                    activeChip(text: "🌿 \(note)") {
                        viewModel.activeFilter.noteNames.removeAll { $0 == note }
                    }
                }
                ForEach(viewModel.activeFilter.occasions, id: \.self) { occasion in
                    activeChip(text: "📅 \(occasion)") {
                        viewModel.activeFilter.occasions.removeAll { $0 == occasion }
                    }
                }
                if viewModel.activeFilter.minRating != nil || viewModel.activeFilter.maxRating != nil {
                    let min = viewModel.activeFilter.minRating ?? 0
                    let max = viewModel.activeFilter.maxRating ?? 5
                    activeChip(text: "⭐ \(String(format: "%.1f", min))–\(String(format: "%.1f", max))") {
                        viewModel.activeFilter.minRating = nil
                        viewModel.activeFilter.maxRating = nil
                    }
                }
                
                // Clear all
                if !viewModel.activeFilter.isEmpty {
                    Button {
                        viewModel.activeFilter = PerfumeFilter()
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
                Text("Offline-Modus — Daten eventuell nicht aktuell")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                if let lastSync = viewModel.lastSyncedAt {
                    Text("Zuletzt synchronisiert: \(lastSync, style: .relative)")
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
            if viewModel.searchText.isEmpty && viewModel.activeFilter.isEmpty {
                Text("\(total) Parfums im Katalog")
            } else {
                Text("\(total) Ergebnis\(total == 1 ? "" : "se")")
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
    var ratingStats: ReviewRemoteDataSource.RatingStats? = nil
    
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
                // Rating
                if let stats = ratingStats, stats.reviewCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.primary)
                        Text(String(format: "%.1f", stats.avgRating))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.primary)
                    }
                }
                
                // Name
                Text(perfume.name)
                    .font(DesignSystem.Fonts.serif(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                // Brand
                Text(perfume.brand?.name ?? "Unbekannte Marke")
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
    var ratingStats: ReviewRemoteDataSource.RatingStats? = nil
    
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
                Text(perfume.brand?.name ?? "Unbekannte Marke")
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
    PerfumeListView()
        .environmentObject(PerfumeListViewModel())
}
