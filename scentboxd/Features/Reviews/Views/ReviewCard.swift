//
//  ReviewCard.swift
//  scentboxd
//
//  Created by Cupo on 22.01.26.
//

import SwiftUI

struct ReviewCard: View {
    let review: Review
    
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
        }
        .padding(16)
        .background(Color(uiColor: .systemGray6).opacity(0.5))
        .cornerRadius(12)
    }
}

#Preview {
    ReviewCard(review: Review(title: "Toller Duft!", text: "Einer meiner absoluten Favoriten. Perfekt für den Sommer.", rating: 5))
        .padding()
}
