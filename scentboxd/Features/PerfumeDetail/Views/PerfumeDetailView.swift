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
        GeometryReader { screenGeometry in
            ScrollView {
                VStack(spacing: 0) {
                    
                    // ─── HERO IMAGE ───
                    let heroHeight = max(screenGeometry.size.height * 0.6, 480)
                    
                    ZStack(alignment: .top) {
                        // Background Image
                        if let url = perfume.imageUrl {
                            Color.clear
                                .frame(height: heroHeight)
                                .overlay {
                                    LazyImage(url: url) { state in
                                        if let image = state.image {
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        } else {
                                            DesignSystem.Colors.bgDark
                                        }
                                    }
                                    .transition(.opacity)
                                }
                                .clipped()
                        } else {
                            ZStack {
                                DesignSystem.Colors.bgDark
                                Image(systemName: "flame")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 80)
                                    .foregroundColor(.gray.opacity(0.2))
                            }
                            .frame(height: heroHeight)
                        }
                        
                        // Gradient overlays
                        VStack {
                            // Top fade
                            LinearGradient(
                                colors: [Color.black.opacity(0.3), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 120)
                            
                            Spacer()
                            
                            // Bottom fade into bgDark
                            LinearGradient(
                                colors: [.clear, DesignSystem.Colors.bgDark],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 140)
                        }
                        .frame(height: heroHeight)
                    }
                    .frame(height: heroHeight)
                    .accessibilityLabel("Parfum-Bild von \(perfume.name)")
                    
                    // ─── CONTENT ───
                    VStack(alignment: .leading, spacing: 28) {
                        
                        // Header Info
                        VStack(alignment: .leading, spacing: 6) {
                            Text(perfume.brand?.name ?? "Unbekannte Marke")
                                .font(DesignSystem.Fonts.display(size: 13, weight: .bold))
                                .tracking(2)
                                .foregroundColor(DesignSystem.Colors.champagne)
                                .textCase(.uppercase)
                            
                            Text(perfume.name)
                                .font(DesignSystem.Fonts.serif(size: 34, weight: .bold))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 10) {
                                // Concentration
                                if let concentration = perfume.concentration, !concentration.isEmpty {
                                    Text(concentration.uppercased())
                                        .font(.system(size: 10, weight: .bold))
                                        .tracking(1.5)
                                        .foregroundColor(DesignSystem.Colors.primary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(DesignSystem.Colors.primary.opacity(0.15))
                                        .overlay(
                                            Capsule().stroke(DesignSystem.Colors.primary.opacity(0.3), lineWidth: 1)
                                        )
                                        .clipShape(Capsule())
                                }
                                
                                // Rating
                                if let avg = viewModel.averageRating {
                                    HStack(spacing: 4) {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(DesignSystem.Colors.champagne)
                                        Text(String(format: "%.1f", avg))
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.white)
                                        if viewModel.reviewCount > 0 {
                                            Text("(\(viewModel.reviewCount))")
                                                .font(.system(size: 11))
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(Color.black.opacity(0.2))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.top, 6)
                        }
                        
                        // ─── ACTION BUTTONS ───
                        HStack(spacing: 12) {
                            // Sammlung
                            Button {
                                if authManager.isAuthenticated {
                                    viewModel.toggleStatus(.owned, modelContext: modelContext, isAuthenticated: authManager.isAuthenticated)
                                } else {
                                    viewModel.showLoginAlert = true
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: viewModel.isActive(.owned) ? "star.fill" : "star")
                                        .font(.system(size: 14))
                                    Text("Sammlung")
                                        .font(.system(size: 13, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(DesignSystem.Colors.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: DesignSystem.Colors.primary.opacity(0.25), radius: 10, x: 0, y: 4)
                            }
                            
                            // Wunschliste
                            Button {
                                if authManager.isAuthenticated {
                                    viewModel.toggleStatus(.wishlist, modelContext: modelContext, isAuthenticated: authManager.isAuthenticated)
                                } else {
                                    viewModel.showLoginAlert = true
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: viewModel.isActive(.wishlist) ? "heart.fill" : "heart")
                                        .font(.system(size: 14))
                                    Text("Wunschliste")
                                        .font(.system(size: 13, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .glassPanel()
                            }
                        }
                        
                        // ─── FRAGRANCE PYRAMID ───
                        if !perfume.topNotes.isEmpty || !perfume.midNotes.isEmpty || !perfume.baseNotes.isEmpty {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Duftpyramide")
                                    .font(DesignSystem.Fonts.serif(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                VStack(spacing: 10) {
                                    if !perfume.topNotes.isEmpty {
                                        notePyramidRow(
                                            icon: "wind",
                                            label: "Kopfnoten",
                                            notes: perfume.topNotes.map(\.name).joined(separator: ", ")
                                        )
                                    }
                                    if !perfume.midNotes.isEmpty {
                                        notePyramidRow(
                                            icon: "leaf",
                                            label: "Herznoten",
                                            notes: perfume.midNotes.map(\.name).joined(separator: ", ")
                                        )
                                    }
                                    if !perfume.baseNotes.isEmpty {
                                        notePyramidRow(
                                            icon: "drop.fill",
                                            label: "Basisnoten",
                                            notes: perfume.baseNotes.map(\.name).joined(separator: ", ")
                                        )
                                    }
                                }
                            }
                        }
                        
                        // ─── PERFORMANCE ───
                        VStack(alignment: .leading, spacing: 18) {
                            Text("Performance")
                                .font(DesignSystem.Fonts.serif(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                            
                            VStack(spacing: 16) {
                                // Longevity
                                performanceBar(
                                    label: "Haltbarkeit",
                                    value: perfume.longevity,
                                    percentage: longevityPercentage(perfume.longevity)
                                )
                                
                                // Sillage
                                performanceBar(
                                    label: "Sillage",
                                    value: perfume.sillage,
                                    percentage: sillagePercentage(perfume.sillage)
                                )
                            }
                        }
                        .padding(20)
                        .glassPanel()
                        
                        // ─── BESCHREIBUNG ───
                        if let desc = perfume.desc, !desc.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Über den Duft")
                                    .font(DesignSystem.Fonts.serif(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                Text(desc)
                                    .font(.subheadline)
                                    .foregroundColor(Color(hex: "#94A3B8"))
                                    .lineSpacing(6)
                            }
                        }
                        
                        // ─── BEWERTUNGEN ───
                        VStack(alignment: .leading, spacing: 16) {
                            // Header
                            HStack {
                                Text("Community Reviews")
                                    .font(DesignSystem.Fonts.serif(size: 22, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                                if let total = viewModel.reviewTotalCount, total > 0 {
                                    Text("\(total)")
                                        .font(.subheadline)
                                        .foregroundColor(Color(hex: "#94A3B8"))
                                }
                            }
                            
                            // Loading
                            if viewModel.isLoadingReviews {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .tint(DesignSystem.Colors.primary)
                                    Spacer()
                                }
                                .padding(.vertical, 20)
                            } else if viewModel.reviews.isEmpty {
                                Text("Noch keine Bewertungen vorhanden.")
                                    .font(.subheadline)
                                    .foregroundColor(Color(hex: "#94A3B8"))
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
                                        ProgressView("Lade weitere…")
                                            .font(.caption)
                                            .tint(DesignSystem.Colors.primary)
                                        Spacer()
                                    }
                                    .padding(.vertical, 8)
                                }
                            }
                            
                            // Write Review Button
                            Button {
                                if authManager.isAuthenticated {
                                    Task { await viewModel.handleReviewButtonTapped() }
                                } else {
                                    viewModel.showLoginAlert = true
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: viewModel.hasExistingReview ? "pencil" : "pencil.line")
                                        .font(.system(size: 14))
                                    Text(viewModel.hasExistingReview ? "Bewertung bearbeiten" : "Bewertung schreiben")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .background(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                                .cornerRadius(12)
                            }
                        }
                        .padding(.top, 4)
                        
                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, -24)
                    .background(DesignSystem.Colors.bgDark)
                }
            }
            .ignoresSafeArea(.all, edges: .top)
            .background(DesignSystem.Colors.bgDark)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
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
            await viewModel.loadRatingStats()
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
    
    // MARK: - Fragrance Pyramid Row
    
    private func notePyramidRow(icon: String, label: String, notes: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.5)
                    .foregroundColor(.white.opacity(0.4))
                Text(notes)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
            }
            
            Spacer()
        }
        .padding(14)
        .glassPanel()
    }
    
    // MARK: - Performance Bar
    
    private func performanceBar(label: String, value: String, percentage: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Text(value.isEmpty ? "–" : value)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.primary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 6)
                    Capsule()
                        .fill(DesignSystem.Colors.primary)
                        .frame(width: geo.size.width * percentage, height: 6)
                }
            }
            .frame(height: 6)
        }
    }
    
    // MARK: - Helpers
    
    private func longevityPercentage(_ value: String) -> Double {
        switch value.lowercased() {
        case "sehr lang", "very long": return 0.95
        case "lang", "long": return 0.80
        case "mittel", "moderate": return 0.55
        case "kurz", "short": return 0.30
        case "sehr kurz", "very short": return 0.15
        default: return 0.5
        }
    }
    
    private func sillagePercentage(_ value: String) -> Double {
        switch value.lowercased() {
        case "enorm", "enormous": return 0.95
        case "stark", "strong": return 0.80
        case "mittel", "moderate": return 0.55
        case "leicht", "light": return 0.30
        case "intim", "intimate": return 0.15
        default: return 0.5
        }
    }
}
