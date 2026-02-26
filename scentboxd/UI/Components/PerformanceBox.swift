//
//  PerformanceBox.swift
//  scentboxd
//
//  Created by Cupo on 09.02.26.
//

import SwiftUI

struct PerformanceBox: View {
    let title: String
    let value: String
    let icon: String
    var highlight: Bool = false
    
    var body: some View {
        VStack(spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundColor(Color(hex: "#94A3B8"))
            
            Text(value)
                .font(.headline)
                .foregroundColor(highlight ? DesignSystem.Colors.champagne : .white)
        }
        .frame(maxWidth: .infinity)
    }
}
