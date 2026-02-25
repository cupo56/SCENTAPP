import SwiftUI
import SwiftData
import Nuke
import NukeUI

struct PerfumeListView: View {
    @Environment(\.modelContext) private var modelContext
    
    @EnvironmentObject var viewModel: PerfumeListViewModel
    
    var body: some View {
        NavigationStack {
            List {
                // Offline-Banner
                if viewModel.isOffline && !viewModel.perfumes.isEmpty {
                    offlineBanner
                }
                
                // Aktive Filter-Chips
                if !viewModel.activeFilter.isEmpty {
                    activeFilterChips
                }
                
                // Gesamtanzahl anzeigen
                if let total = viewModel.totalCount, !viewModel.isLoading {
                    resultCountRow(total: total)
                }
                
                if let errorMessage = viewModel.errorMessage {
                    errorView(message: errorMessage)
                }
                
                if viewModel.isLoading {
                    ProgressView("Lade Parfums...")
                }
                
                ForEach(viewModel.perfumes) { perfume in
                    NavigationLink(destination: PerfumeDetailView(perfume: perfume)) {
                        PerfumeRowView(perfume: perfume, ratingStats: viewModel.ratingStatsMap[perfume.id])
                    }
                    .onAppear {
                        Task {
                            await viewModel.loadMoreIfNeeded(currentItem: perfume)
                        }
                    }
                }
                
                if viewModel.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Suche Parfum...")
            .navigationTitle("Parfums")
            .refreshable {
                await viewModel.refresh()
            }
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
                            
                            if viewModel.activeFilter.activeFilterCount > 0 {
                                Text("\(viewModel.activeFilter.activeFilterCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 16, height: 16)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .offset(x: 6, y: -6)
                            }
                        }
                    }
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
    
    // MARK: - Subviews
    
    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Offline-Modus — Daten eventuell nicht aktuell")
                    .font(.caption)
                    .fontWeight(.medium)
                if let lastSync = viewModel.lastSyncedAt {
                    Text("Zuletzt synchronisiert: \(lastSync, style: .relative)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(10)
        .background(Color.orange.opacity(0.12))
        .cornerRadius(8)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
    }
    
    private var activeFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let brand = viewModel.activeFilter.brandName {
                    ChipView(text: "Marke: \(brand)") {
                        viewModel.activeFilter.brandName = nil
                    }
                }
                if let conc = viewModel.activeFilter.concentration {
                    ChipView(text: conc.uppercased()) {
                        viewModel.activeFilter.concentration = nil
                    }
                }
                if let longevity = viewModel.activeFilter.longevity {
                    ChipView(text: "Longevity: \(longevity)") {
                        viewModel.activeFilter.longevity = nil
                    }
                }
                if let sillage = viewModel.activeFilter.sillage {
                    ChipView(text: "Sillage: \(sillage)") {
                        viewModel.activeFilter.sillage = nil
                    }
                }
                ForEach(viewModel.activeFilter.noteNames, id: \.self) { note in
                    ChipView(text: "🌿 \(note)") {
                        viewModel.activeFilter.noteNames.removeAll { $0 == note }
                    }
                }
                ForEach(viewModel.activeFilter.occasions, id: \.self) { occasion in
                    ChipView(text: "📅 \(occasion)") {
                        viewModel.activeFilter.occasions.removeAll { $0 == occasion }
                    }
                }
                if viewModel.activeFilter.minRating != nil || viewModel.activeFilter.maxRating != nil {
                    let min = viewModel.activeFilter.minRating ?? 0
                    let max = viewModel.activeFilter.maxRating ?? 5
                    ChipView(text: "⭐ \(String(format: "%.1f", min))–\(String(format: "%.1f", max))") {
                        viewModel.activeFilter.minRating = nil
                        viewModel.activeFilter.maxRating = nil
                    }
                }
                
                // "Alle löschen" Button
                Button {
                    viewModel.activeFilter = PerfumeFilter()
                } label: {
                    Text("Alle löschen")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding(.vertical, 4)
        }
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
    }
    
    private func resultCountRow(total: Int) -> some View {
        HStack {
            Image(systemName: "number")
                .foregroundColor(.secondary)
            if viewModel.searchText.isEmpty && viewModel.activeFilter.isEmpty {
                Text("\(total) Parfums im Katalog")
            } else {
                Text("\(total) Ergebnis\(total == 1 ? "" : "se")")
            }
            Spacer()
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .listRowSeparator(.hidden)
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.largeTitle)
                .foregroundColor(.red.opacity(0.7))
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await viewModel.loadData() }
            } label: {
                Label("Erneut versuchen", systemImage: "arrow.clockwise")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .listRowSeparator(.hidden)
    }
}

struct PerfumeRowView: View {
    let perfume: Perfume
    var ratingStats: ReviewRemoteDataSource.RatingStats? = nil
    
    var body: some View {
        HStack {
            // Bild anzeigen
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
                        Color.gray.opacity(0.3)
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
                    .foregroundColor(.gray.opacity(0.3))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(perfume.name)
                    .font(.headline)
                Text(perfume.brand?.name ?? "Unbekannte Marke")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                HStack(spacing: 4) {
                    if let concentration = perfume.concentration, !concentration.isEmpty {
                        Text(concentration.uppercased())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if let stats = ratingStats, stats.reviewCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", stats.avgRating))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("(\(stats.reviewCount))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } else if perfume.performance > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", perfume.performance))
                                .font(.caption)
                                .foregroundColor(.secondary)
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
