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
                if viewModel.isLoading {
                    ProgressView("Lade Parfums...")
                }
                
                ForEach(viewModel.filteredPerfumes) { perfume in
                    NavigationLink(destination: PerfumeDetailView(perfume: perfume)) {
                        PerfumeRowView(perfume: perfume)
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Suche Parfum...")
            .navigationTitle("Parfums")
            .refreshable {
                // Ermöglicht "Pull to Refresh"
                await viewModel.loadData()
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
