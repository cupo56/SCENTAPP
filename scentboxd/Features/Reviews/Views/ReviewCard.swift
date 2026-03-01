//
//  ReviewCard.swift
//  scentboxd
//
//  Created by Cupo on 22.01.26.
//

import SwiftUI

struct ReviewCard: View {
    let review: Review
    let isOwn: Bool
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Autor + Datum
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(DesignSystem.Colors.primary)
                    Text(review.authorName ?? "Anonym")
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                .font(.subheadline)
                
                Spacer()
                
                Text(review.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(Color(hex: "#94A3B8"))
            }
            
            // Sterne
            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= review.rating ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundColor(star <= review.rating ? DesignSystem.Colors.champagne : Color.white.opacity(0.2))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(review.rating) von 5 Sternen")
            
            // Titel
            if !review.title.isEmpty {
                Text(review.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            
            // Text
            if !review.text.isEmpty {
                Text(review.text)
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "#CBD5E1"))
                    .lineLimit(4)
            }
            
            // Longevity & Sillage Badges
            if review.longevity != nil || review.sillage != nil {
                HStack(spacing: 8) {
                    if let lon = review.longevity {
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
                    
                    if let sil = review.sillage {
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
            
            // Bearbeiten / Löschen Buttons
            if isOwn {
                HStack(spacing: 12) {
                    Button {
                        onEdit?()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                            Text("Bearbeiten")
                        }
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.champagne)
                    }
                    .accessibilityLabel("Bewertung bearbeiten")
                    
                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("Löschen")
                        }
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.8))
                    }
                    .accessibilityLabel("Bewertung löschen")
                    
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color(hex: "#341826"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .alert("Bewertung löschen", isPresented: $showDeleteConfirmation) {
            Button("Abbrechen", role: .cancel) { }
            Button("Löschen", role: .destructive) {
                onDelete?()
            }
        } message: {
            Text("Bist du sicher? Diese Aktion kann nicht rückgängig gemacht werden.")
        }
    }
    
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

#Preview {
    ReviewCard(
        review: Review(title: "Toller Duft!", text: "Einer meiner absoluten Favoriten. Perfekt für den Sommer.", rating: 5, longevity: 80, sillage: 45),
        isOwn: true,
        onEdit: { },
        onDelete: { }
    )
    .padding()
    .background(Color(hex: "#221019"))
}
