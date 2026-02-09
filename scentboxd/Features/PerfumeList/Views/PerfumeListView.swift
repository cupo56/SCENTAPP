import SwiftUI
import SwiftData

struct PerfumeListView: View {
    // Environment modelContext brauchen wir hier für das reine Anzeigen aus der Cloud nicht mehr zwingend,
    // lassen es aber drin, falls du später speichern willst.
    @Environment(\.modelContext) private var modelContext
    
    @EnvironmentObject var viewModel: PerfumeListViewModel
    
    var body: some View {
        NavigationStack {
            List {
                // Offline-Banner
                if viewModel.isOffline && !viewModel.perfumes.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "wifi.slash")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Offline-Modus — Daten eventuell nicht aktuell")
                                .font(.caption)
                                .fontWeight(.medium)
                            if let lastSync = viewModel.lastSyncedAt {
                                Text("Zuletzt synchronisiert: \(lastSync, style: .relative) ago")
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
                
                if let errorMessage = viewModel.errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.largeTitle)
                            .foregroundColor(.red.opacity(0.7))
                        Text(errorMessage)
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
                
                if viewModel.isLoading {
                    ProgressView("Lade Parfums...")
                }
                
                ForEach(viewModel.perfumes) { perfume in
                    NavigationLink(destination: PerfumeDetailView(perfume: perfume)) {
                        PerfumeRowView(perfume: perfume)
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
        }
    }
}

struct PerfumeRowView: View {
    let perfume: Perfume
    
    var body: some View {
        HStack { // HStack, damit Bild links und Text rechts ist
            // Bild anzeigen
            if let url = perfume.imageUrl {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.3) // Platzhalter während es lädt
                }
                .frame(width: 60, height: 60)
                .cornerRadius(8)
                .clipped()
            } else {
                // Fallback Icon, wenn kein Bild da ist
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
                if let concentration = perfume.concentration, !concentration.isEmpty {
                    Text(concentration.uppercased())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

#Preview {
    PerfumeListView()
        .environmentObject(PerfumeListViewModel())
}
