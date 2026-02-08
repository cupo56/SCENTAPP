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
                // Autor
                HStack(spacing: 6) {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.accentColor)
                    Text(review.authorName ?? "Anonym")
                        .fontWeight(.medium)
                }
                .font(.subheadline)
                
                Spacer()
                
                // Datum
                Text(review.createdAt, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Sterne
            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= review.rating ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundColor(star <= review.rating ? .yellow : .gray.opacity(0.3))
                }
            }
            
            // Titel
            if !review.title.isEmpty {
                Text(review.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            // Text
            if !review.text.isEmpty {
                Text(review.text)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(4)
            }
            
            // Bearbeiten / Löschen Buttons (nur für eigene Reviews)
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
                        .foregroundColor(.blue)
                    }
                    
                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("Löschen")
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                    
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color(uiColor: .systemGray6).opacity(0.5))
        .cornerRadius(12)
        .alert("Bewertung löschen", isPresented: $showDeleteConfirmation) {
            Button("Abbrechen", role: .cancel) { }
            Button("Löschen", role: .destructive) {
                onDelete?()
            }
        } message: {
            Text("Bist du sicher? Diese Aktion kann nicht rückgängig gemacht werden.")
        }
    }
}

#Preview {
    ReviewCard(
        review: Review(title: "Toller Duft!", text: "Einer meiner absoluten Favoriten. Perfekt für den Sommer.", rating: 5),
        isOwn: true,
        onEdit: { },
        onDelete: { }
    )
    .padding()
}
