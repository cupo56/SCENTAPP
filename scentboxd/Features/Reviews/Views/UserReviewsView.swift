//
//  UserReviewsView.swift
//  scentboxd
//
//  Created by AI on 27.02.26.
//

import SwiftUI
import SwiftData

struct UserReviewsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allPerfumes: [Perfume] // Needed to link reviews to Perfume details locally
    
    @State private var userReviews: [ReviewDTO] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    
    private let dataSource = ReviewRemoteDataSource()
    
    var body: some View {
        ZStack {
            DesignSystem.Colors.bgDark.ignoresSafeArea()
            
            if isLoading {
                ProgressView("Bewertungen laden...")
                    .tint(DesignSystem.Colors.primary)
                    .foregroundColor(DesignSystem.Colors.primary)
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red.opacity(0.8))
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "#94A3B8"))
                        .multilineTextAlignment(.center)
                    Button("Erneut versuchen") {
                        Task { await loadReviews() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DesignSystem.Colors.primary)
                }
                .padding()
            } else if userReviews.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "text.quote")
                        .font(.system(size: 48))
                        .foregroundColor(DesignSystem.Colors.primary.opacity(0.4))
                    Text("Noch keine Bewertungen")
                        .font(DesignSystem.Fonts.serif(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Du hast bisher keine Parfums bewertet.")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "#94A3B8"))
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(userReviews, id: \.id) { reviewDTO in
                            if let linkedPerfume = allPerfumes.first(where: { $0.id == reviewDTO.perfumeId }) {
                                NavigationLink(destination: PerfumeDetailView(perfume: linkedPerfume)) {
                                    userReviewCard(reviewDTO: reviewDTO, perfume: linkedPerfume)
                                }
                                .buttonStyle(.plain)
                            } else {
                                // If the perfume is not downloaded locally yet, still show the review but perhaps a simpler layout
                                userReviewCard(reviewDTO: reviewDTO, perfume: nil)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Meine Bewertungen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await loadReviews()
        }
    }
    
    // MARK: - Subviews
    
    private func userReviewCard(reviewDTO: ReviewDTO, perfume: Perfume?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Perfume Info
            HStack(spacing: 12) {
                // Image
                if let url = perfume?.imageUrl {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        DesignSystem.Colors.surfaceDark
                    }
                    .frame(width: 48, height: 48)
                    .cornerRadius(8)
                    .clipped()
                } else {
                    ZStack {
                        DesignSystem.Colors.surfaceDark
                        Image(systemName: "flame.circle.fill")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundColor(DesignSystem.Colors.primary.opacity(0.3))
                    }
                    .frame(width: 48, height: 48)
                    .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(perfume?.name ?? "Unbekanntes Parfum")
                        .font(DesignSystem.Fonts.serif(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(perfume?.brand?.name ?? "Marke unbekannt")
                        .font(.caption)
                        .foregroundColor(Color(hex: "#94A3B8"))
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text(reviewDTO.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundColor(Color(hex: "#64748B"))
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Rating
            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= reviewDTO.rating ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundColor(star <= reviewDTO.rating ? DesignSystem.Colors.champagne : Color.white.opacity(0.2))
                }
            }
            
            // Title & Text
            if !reviewDTO.title.isEmpty {
                Text(reviewDTO.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            
            // Text
            if !reviewDTO.text.isEmpty {
                Text(reviewDTO.text)
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "#CBD5E1"))
                    .lineLimit(4)
            }
            
            // Longevity & Sillage Badges
            if reviewDTO.longevity != nil || reviewDTO.sillage != nil {
                HStack(spacing: 8) {
                    if let lon = reviewDTO.longevity {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .foregroundColor(DesignSystem.Colors.champagne)
                            Text(longevityText(for: lon))
                                .foregroundColor(.white)
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(6)
                    }
                    
                    if let sil = reviewDTO.sillage {
                        HStack(spacing: 4) {
                            Image(systemName: "wind")
                                .foregroundColor(DesignSystem.Colors.champagne)
                            Text(sillageText(for: sil))
                                .foregroundColor(.white)
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(6)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(16)
        .glassPanel()
    }
    
    // MARK: - Actions
    
    private func loadReviews() async {
        isLoading = true
        errorMessage = nil
        do {
            userReviews = try await dataSource.fetchUserReviews()
        } catch {
            errorMessage = "Fehler beim Laden der Bewertungen: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    // MARK: - Helpers
    
    private func longevityText(for value: Int) -> String {
        if value < 33 { return "Flüchtig" }
        else if value < 66 { return "Moderat" }
        else { return "Ewig" }
    }
    
    private func sillageText(for value: Int) -> String {
        if value < 33 { return "Hautnah" }
        else if value < 66 { return "Moderat" }
        else { return "Raumfüllend" }
    }
}
