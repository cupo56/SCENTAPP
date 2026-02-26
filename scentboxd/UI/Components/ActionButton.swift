//
//  ActionButton.swift
//  scentboxd
//
//  Created by Cupo on 09.02.26.
//

import SwiftUI

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
            .foregroundColor(isActive ? .white : Color(hex: "#CBD5E1"))
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                isActive ? color : DesignSystem.Colors.surfaceDark
            )
            .overlay(
                Capsule().stroke(Color.white.opacity(isActive ? 0 : 0.08), lineWidth: 1)
            )
            .clipShape(Capsule())
            .animation(.spring(response: 0.3), value: isActive)
        }
        .accessibilityLabel("\(label), \(isActive ? "aktiv" : "nicht aktiv")")
        .accessibilityAddTraits(.isButton)
    }
}
