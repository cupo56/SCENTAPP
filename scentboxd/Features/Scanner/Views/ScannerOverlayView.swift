//
//  ScannerOverlayView.swift
//  scentboxd
//

import SwiftUI

struct ScannerOverlayView: View {
    @State private var animate = false

    private let frameWidth: CGFloat = 260
    private let frameHeight: CGFloat = 160

    var body: some View {
        ZStack {
            // Gedimmter Hintergrund mit Ausschnitt für den Scan-Bereich
            Color.black.opacity(0.55)
                .mask(
                    Rectangle()
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .frame(width: frameWidth, height: frameHeight)
                                .blendMode(.destinationOut)
                        )
                        .compositingGroup()
                )

            // Scan-Rahmen
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(DesignSystem.Colors.primary, lineWidth: 2)
                .frame(width: frameWidth, height: frameHeight)

            // Animierte Scan-Linie
            Rectangle()
                .fill(DesignSystem.Colors.primary.opacity(0.75))
                .frame(width: frameWidth - 20, height: 2)
                .offset(y: animate ? (frameHeight / 2 - 4) : -(frameHeight / 2 - 4))
                .animation(
                    .easeInOut(duration: 1.6).repeatForever(autoreverses: true),
                    value: animate
                )
                .frame(width: frameWidth, height: frameHeight)
                .clipped()
                .cornerRadius(16)

            // Hinweistext
            VStack {
                Spacer()
                Text("Halte den Barcode in den Rahmen")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(8)
                    .padding(.bottom, 80)
            }
        }
        .ignoresSafeArea()
        .onAppear { animate = true }
    }
}
