//
//  SkeletonRowView.swift
//  scentboxd
//

import SwiftUI

/// Skeleton-Platzhalter für eine Parfum-Zeile während des Ladens.
struct SkeletonRowView: View {
    var body: some View {
        HStack(spacing: 12) {
            // Bild-Platzhalter
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.15))
                .frame(width: 60, height: 60)
            
            VStack(alignment: .leading, spacing: 8) {
                // Titel
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 140, height: 14)
                
                // Marke
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.12))
                    .frame(width: 100, height: 12)
                
                // Konzentration
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 60, height: 10)
            }
            
            Spacer()
        }
        .shimmer()
        .accessibilityHidden(true)
    }
}
