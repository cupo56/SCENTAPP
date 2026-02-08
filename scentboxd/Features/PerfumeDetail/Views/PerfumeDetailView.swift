import SwiftUI
import SwiftData
import Auth
import Supabase

struct PerfumeDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var authManager
    
    let perfume: Perfume
    
    @State private var showReviewSheet = false
    @State private var isSavingReview = false
    @State private var reviews: [Review] = []
    @State private var isLoadingReviews = false
    @State private var showLoginAlert = false
    @State private var editingReview: Review? = nil
    @State private var currentUserId: UUID? = nil
    
    private let reviewDataSource = ReviewRemoteDataSource()
    private let userPerfumeDataSource = UserPerfumeRemoteDataSource()
    
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
                                    
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                            // Maximale Größe definieren, damit es nicht riesig wird
                                                .frame(maxWidth: innerGeo.size.width * 0.9)
                                                .frame(maxHeight: headerHeight * 0.85) // Max 65% der Box-Höhe nutzen
                                                .shadow(color: Color.black.opacity(0.12), radius: 15, x: 0, y: 15)
                                        case .failure:
                                            Image(systemName: "photo")
                                                .font(.system(size: 40))
                                                .foregroundColor(.gray.opacity(0.3))
                                        case .empty:
                                            ProgressView()
                                        @unknown default:
                                            EmptyView()
                                        }
                                    }
                                    
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
                                icon: isActive(.wishlist) ? "heart.fill" : "heart",
                                label: "Wunschliste",
                                color: .red,
                                isActive: isActive(.wishlist)
                            ) {
                                if authManager.isAuthenticated {
                                    toggleStatus(.wishlist)
                                } else {
                                    showLoginAlert = true
                                }
                            }
                            
                            // Button 2: Sammlung
                            ActionButton(
                                icon: isActive(.owned) ? "star.fill" : "star",
                                label: "In Besitz",
                                color: .yellow,
                                isActive: isActive(.owned)
                            ) {
                                if authManager.isAuthenticated {
                                    toggleStatus(.owned)
                                } else {
                                    showLoginAlert = true
                                }
                            }
                        }
                        
                        // Button 3: Bewertung schreiben / bearbeiten
                        Button {
                            if authManager.isAuthenticated {
                                Task { await handleReviewButtonTapped() }
                            } else {
                                showLoginAlert = true
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: hasExistingReview ? "pencil" : "pencil.line")
                                Text(hasExistingReview ? "Bewertung bearbeiten" : "Bewertung schreiben")
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
                            PerformanceBox(title: "Bewertung", value: String(format: "%.1f / 5.0", perfume.performance), icon: "star.fill", highlight: true)
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
                                if !reviews.isEmpty {
                                    Text("\(reviews.count)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if isLoadingReviews {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                    Spacer()
                                }
                                .padding(.vertical, 20)
                            } else if reviews.isEmpty {
                                Text("Noch keine Bewertungen vorhanden.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 8)
                            } else {
                                ForEach(reviews, id: \.id) { review in
                                    ReviewCard(
                                        review: review,
                                        isOwn: review.userId == currentUserId,
                                        onEdit: {
                                            editingReview = review
                                            showReviewSheet = true
                                        },
                                        onDelete: {
                                            Task { await deleteReview(review) }
                                        }
                                    )
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
            .edgesIgnoringSafeArea(.top)
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showReviewSheet, onDismiss: {
            editingReview = nil
        }) {
            ReviewFormView(perfume: perfume, existingReview: editingReview) { review in
                Task {
                    if editingReview != nil {
                        await updateReview(review)
                    } else {
                        await saveReview(review)
                    }
                }
            }
        }
        .task {
            await loadCurrentUserId()
            await loadReviews()
        }
        .alert("Anmeldung erforderlich", isPresented: $showLoginAlert) {
            Button("Abbrechen", role: .cancel) { }
            Button("OK") { }
        } message: {
            Text("Bitte melde dich an oder registriere dich, um diese Funktion zu nutzen.")
        }
    }
    
    private func loadReviews() async {
        isLoadingReviews = true
        do {
            reviews = try await reviewDataSource.fetchReviews(for: perfume.id)
        } catch {
            print("Fehler beim Laden der Bewertungen: \(error)")
        }
        isLoadingReviews = false
    }
    
    private var hasExistingReview: Bool {
        guard let userId = currentUserId else { return false }
        return reviews.contains { $0.userId == userId }
    }
    
    private func loadCurrentUserId() async {
        do {
            let session = try await AppConfig.client.auth.session
            currentUserId = session.user.id
        } catch {
            currentUserId = nil
        }
    }
    
    private func handleReviewButtonTapped() async {
        // Duplikat-Prüfung: Hat der Nutzer bereits eine Review?
        if let existing = reviews.first(where: { $0.userId == currentUserId }) {
            editingReview = existing
            showReviewSheet = true
        } else {
            editingReview = nil
            showReviewSheet = true
        }
    }
    
    private func saveReview(_ review: Review) async {
        isSavingReview = true
        do {
            try await reviewDataSource.saveReview(review, for: perfume.id)
            
            // Neu laden um userId etc. korrekt zu haben
            await loadReviews()
            
            // Auch lokal speichern
            if perfume.modelContext == nil {
                modelContext.insert(perfume)
            }
            review.perfume = perfume
            perfume.reviews.append(review)
            try? modelContext.save()
        } catch {
            print("Fehler beim Speichern der Bewertung: \(error)")
        }
        isSavingReview = false
    }
    
    private func updateReview(_ review: Review) async {
        do {
            try await reviewDataSource.updateReview(review, for: perfume.id)
            await loadReviews()
        } catch {
            print("Fehler beim Aktualisieren der Bewertung: \(error)")
        }
    }
    
    private func deleteReview(_ review: Review) async {
        do {
            try await reviewDataSource.deleteReview(id: review.id)
            reviews.removeAll { $0.id == review.id }
            
            // Auch lokal entfernen
            perfume.reviews.removeAll { $0.id == review.id }
            try? modelContext.save()
        } catch {
            print("Fehler beim Löschen der Bewertung: \(error)")
        }
    }
    private func isActive(_ status: UserPerfumeStatus) -> Bool {
        return perfume.userMetadata?.statusRaw == status.rawValue
    }
    
    private func toggleStatus(_ targetStatus: UserPerfumeStatus) {
        // 1. Aus Cloud lokal übernehmen, falls nötig
        if perfume.modelContext == nil {
            modelContext.insert(perfume)
        }
        
        // 2. Bestimme den neuen Status
        let newStatus: UserPerfumeStatus
        if let metadata = perfume.userMetadata {
            // Toggle Logik: Wenn schon aktiv, dann deaktivieren (.none)
            if metadata.statusRaw == targetStatus.rawValue {
                newStatus = .none
            } else {
                newStatus = targetStatus
            }
            metadata.status = newStatus
        } else {
            // Neu anlegen
            newStatus = targetStatus
            let newMeta = UserPersonalData(status: targetStatus)
            perfume.userMetadata = newMeta
        }
        
        // 3. Lokal speichern
        try? modelContext.save()
        
        // 4. In Supabase speichern (wenn eingeloggt)
        if authManager.isAuthenticated {
            Task {
                await syncStatusToSupabase(perfumeId: perfume.id, status: newStatus)
            }
        }
    }
    
    private func syncStatusToSupabase(perfumeId: UUID, status: UserPerfumeStatus) async {
        do {
            if status == .none {
                // Eintrag löschen wenn Status auf "none" gesetzt wird
                try await userPerfumeDataSource.deleteUserPerfume(perfumeId: perfumeId)
            } else {
                // Status speichern/aktualisieren
                try await userPerfumeDataSource.saveUserPerfume(perfumeId: perfumeId, status: status)
            }
        } catch {
            print("Fehler beim Sync mit Supabase: \(error)")
        }
    }
}

// --- Hilfs-Strukturen bleiben gleich ---

struct NoteRow: View {
    let title: String
    let icon: String
    let notes: [Note]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(notes) { note in
                        Text(note.name)
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.medium)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.08))
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                    }
                }
            }
        }
    }
}

struct PerformanceBox: View {
    let title: String
    let value: String
    let icon: String
    var highlight: Bool = false
    
    var body: some View {
        VStack(spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundColor(.gray)
            
            Text(value)
                .font(.headline)
                .foregroundColor(highlight ? .blue : .primary)
        }
        .frame(maxWidth: .infinity)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

struct ActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.subheadline)
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(isActive ? .white : .primary)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                isActive ? color : Color(uiColor: .systemGray6)
            )
            .clipShape(Capsule())
            .animation(.spring(response: 0.3), value: isActive)
        }
    }
}
