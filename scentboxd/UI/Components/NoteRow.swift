//
//  NoteRow.swift
//  scentboxd
//
//  Created by Cupo on 09.02.26.
//

import SwiftUI

struct NoteRow: View {
    let title: String
    let icon: String
    let notes: [Note]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.primary)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color(hex: "#94A3B8"))
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(notes) { note in
                        Text(note.name)
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.medium)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(DesignSystem.Colors.primary.opacity(0.15))
                            .foregroundColor(DesignSystem.Colors.primary)
                            .cornerRadius(12)
                    }
                }
            }
        }
    }
}
