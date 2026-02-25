import SwiftUI
import SwiftData
import Nuke
import NukeUI

struct PerfumeDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var authManager
    @Environment(\.selectedTab) private var selectedTab
    
    @State private var viewModel: PerfumeDetailViewModel
    
    init(perfume: Perfume, reviewDataSource: ReviewRemoteDataSource? = nil, userPerfumeDataSource: UserPerfumeRemoteDataSource? = nil) {
        _viewModel = State(initialValue: PerfumeDetailViewModel(
            perfume: perfume,
            reviewDataSource: reviewDataSource ?? ReviewRemoteDataSource(),
            userPerfumeDataSource: userPerfumeDataSource ?? UserPerfumeRemoteDataSource()
        ))
    }
    
    private var perfume: Perfume { viewModel.perfume }
    
    var body: some View {
        // 1. Äußerer GeometryReader, um die Bildschirmgröße sicher zu ermitteln
        GeometryReader { screenGeometry in
            ScrollView {
                VStack(spacing: 0) {
                    
                    // --- GROSSER HEADER ---
                    // Hier nutzen wir jetzt screenGeometry statt UIScreen.main
                    let headerHeight = max(screenGeometry.size.height * 0.55, 450)
                    
                    GeometryReader { innerGeo in
                        ZStack(alignment: .top) { // Wir richten erst mal alles oben aus
                            
                            // 1. Hintergrund (Füllt alles aus)
                            Rectangle()
                                .foregroundColor(Color(uiColor: .systemGray6).opacity(0.4))
                                .frame(height: headerHeight)
                            
                            // 2. Das Bild (Zentriert durch Spacer)
                            if let url = perfume.imageUrl {
                                VStack {
                                    // A. Oberer Platzhalter (Drückt das Bild weg von der Notch)
                                    Spacer()
                                    
                                    LazyImage(url: url) { state in
                                        if let image = state.image {
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(maxWidth: innerGeo.size.width * 0.9)
                                                .frame(maxHeight: headerHeight * 0.85)
                                                .shadow(color: Color.black.opacity(0.12), radius: 15, x: 0, y: 15)
                                        } else if state.error != nil {
                                            Image(systemName: "photo")
                                                .font(.system(size: 40))
                                                .foregroundColor(.gray.opacity(0.3))
                                        } else {
                                            ProgressView()
                                        }
                                    }
                                    .transition(.opacity)
                                    
                                    // B. Unterer Platzhalter (Drückt das Bild nach oben)
                                    Spacer()
                                    
                                    // C. Kleiner Ausgleich für den Text-Layer, der unten drüber liegt
                                    Spacer().frame(height: 30)
                                }
                                // WICHTIG: Das sorgt dafür, dass der VStack die volle Höhe nutzt
                                .frame(width: innerGeo.size.width, height: headerHeight)
                                // Kleiner Bonus: Schiebt den ganzen Inhalt optisch etwas tiefer,
                                // damit die Notch nicht genau auf dem Flaschenkopf sitzt.
                                .padding(.top, 40)
                                
                            } else {
                                // Fallback zentriert
                                VStack {
                                    Spacer()
                                    Image(systemName: "flame")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(height: 80)
                                        .foregroundColor(.gray.opacity(0.2))
                                    Spacer()
                                }
                                .frame(width: innerGeo.size.width, height: headerHeight)
                            }
                        }
                    }
                    .frame(height: headerHeight)
                    
                    
                    // --- INHALT ---
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // Titel & Marke
                        VStack(alignment: .leading, spacing: 8) {
                            Text(perfume.brand?.name ?? "Unbekannte Marke")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            Text(perfume.name)
                                .font(.system(size: 34, weight: .bold, design: .default))
                                .foregroundColor(.primary)
                            
                            if let concentration = perfume.concentration, !concentration.isEmpty {
                                Text(concentration.uppercased())
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        HStack(spacing: 12) {
                            // Button 1: Wunschliste
                            ActionButton(
                                icon: viewModel.isActive(.wishlist) ? "heart.fill" : "heart",
                                label: "Wunschliste",
                                color: .red,
                                isActive: viewModel.isActive(.wishlist)
                            ) {
                                if authManager.isAuthenticated {
                                    viewModel.toggleStatus(.wishlist, modelContext: modelContext, isAuthenticated: authManager.isAuthenticated)
                                } else {
                                    viewModel.showLoginAlert = true
                                }
                            }
                            
                            // Button 2: Sammlung
                            ActionButton(
                                icon: viewModel.isActive(.owned) ? "star.fill" : "star",
                                label: "In Besitz",
                                color: .yellow,
                                isActive: viewModel.isActive(.owned)
                            ) {
                                if authManager.isAuthenticated {
                                    viewModel.toggleStatus(.owned, modelContext: modelContext, isAuthenticated: authManager.isAuthenticated)
                                } else {
                                    viewModel.showLoginAlert = true
                                }
                            }
                        }
                        
                        // Button 3: Bewertung schreiben / bearbeiten
                        Button {
                            if authManager.isAuthenticated {
                                Task { await viewModel.handleReviewButtonTapped() }
                            } else {
                                viewModel.showLoginAlert = true
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: viewModel.hasExistingReview ? "pencil" : "pencil.line")
                                Text(viewModel.hasExistingReview ? "Bewertung bearbeiten" : "Bewertung schreiben")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        
                        Divider()
                        
                        // Noten
                        if !perfume.topNotes.isEmpty || !perfume.midNotes.isEmpty || !perfume.baseNotes.isEmpty {
                            VStack(alignment: .leading, spacing: 20) {
                                if !perfume.topNotes.isEmpty {
                                    NoteRow(title: "Kopfnoten", icon: "arrow.up.circle", notes: perfume.topNotes)
                                }
                                if !perfume.midNotes.isEmpty {
                                    NoteRow(title: "Herznoten", icon: "heart.circle", notes: perfume.midNotes)
                                }
                                if !perfume.baseNotes.isEmpty {
                                    NoteRow(title: "Basisnoten", icon: "arrow.down.circle", notes: perfume.baseNotes)
                                }
                            }
                        }
                        
                        // Performance Box
                        HStack(spacing: 0) {
                            PerformanceBox(title: "Haltbarkeit", value: perfume.longevity.isEmpty ? "-" : perfume.longevity, icon: "hourglass")
                            Divider().frame(height: 40)
                            if let avg = viewModel.averageRating {
                                PerformanceBox(title: "Bewertung (\(viewModel.reviewCount))", value: String(format: "%.1f / 5.0", avg), icon: "star.fill", highlight: true)
                            } else {
                                PerformanceBox(title: "Bewertung", value: "– / 5.0", icon: "star.fill", highlight: false)
                            }
                        }
                        .padding(.vertical, 12)
                        .background(Color(uiColor: .systemGray6).opacity(0.5))
                        .cornerRadius(16)
                        
                        // Beschreibung
                        if let desc = perfume.desc, !desc.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Über den Duft")
                                    .font(.headline)
                                Text(desc)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .lineSpacing(6)
                            }
                            .padding(.top, 8)
                        }
                        
                        // Bewertungen
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Bewertungen")
                                    .font(.headline)
                                Spacer()
                                if let total = viewModel.reviewTotalCount {
                                    Text("\(total)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                } else if !viewModel.reviews.isEmpty {
                                    Text("\(viewModel.reviews.count)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if viewModel.isLoadingReviews {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                    Spacer()
                                }
                                .padding(.vertical, 20)
                            } else if viewModel.reviews.isEmpty {
                                Text("Noch keine Bewertungen vorhanden.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 8)
                            } else {
                                ForEach(viewModel.reviews, id: \.id) { review in
                                    ReviewCard(
                                        review: review,
                                        isOwn: review.userId == viewModel.currentUserId,
                                        onEdit: {
                                            viewModel.editingReview = review
                                            viewModel.showReviewSheet = true
                                        },
                                        onDelete: {
                                            Task { await viewModel.deleteReview(review, modelContext: modelContext) }
                                        }
                                    )
                                    .onAppear {
                                        Task {
                                            await viewModel.loadMoreReviewsIfNeeded(currentReview: review)
                                        }
                                    }
                                }
                                
                                if viewModel.isLoadingMoreReviews {
                                    HStack {
                                        Spacer()
                                        ProgressView("Lade weitere Bewertungen…")
                                            .font(.caption)
                                        Spacer()
                                    }
                                    .padding(.vertical, 8)
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding(24)
                    .background(Color(uiColor: .systemBackground))
                    .cornerRadius(30, corners: [.topLeft, .topRight])
                    .offset(y: -30)
                    .padding(.bottom, -30)
                }
            }
            .ignoresSafeArea(.all, edges: .top)
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Bindable(viewModel).showReviewSheet, onDismiss: {
            viewModel.editingReview = nil
        }) {
            ReviewFormView(perfume: perfume, existingReview: viewModel.editingReview) { review in
                Task {
                    if viewModel.editingReview != nil {
                        await viewModel.updateReview(review)
                    } else {
                        await viewModel.saveReview(review, modelContext: modelContext)
                    }
                }
            }
        }
        .task {
            await viewModel.loadCurrentUserId()
            await viewModel.loadReviews()
        }
        .alert("Anmeldung erforderlich", isPresented: Bindable(viewModel).showLoginAlert) {
            Button("Abbrechen", role: .cancel) { }
            Button("Zum Profil") { selectedTab.wrappedValue = 3 }
        } message: {
            Text("Bitte melde dich an oder registriere dich, um diese Funktion zu nutzen.")
        }
        .alert("Bewertungsfehler", isPresented: Bindable(viewModel).showReviewErrorAlert) {
            Button("OK", role: .cancel) { }
            Button("Erneut versuchen") {
                Task { await viewModel.loadReviews() }
            }
        } message: {
            Text(viewModel.reviewErrorMessage ?? "Ein Fehler ist aufgetreten.")
        }
        .alert("Synchronisierungsfehler", isPresented: Bindable(viewModel).showSyncErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.syncErrorMessage ?? "Ein Fehler ist aufgetreten.")
        }
    }
}
