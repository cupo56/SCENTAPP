//
//  SplashScreenView.swift
//  scentboxd
//
//  Created by Cupo on 24.01.26.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var isAnimating = false
    @State private var liquidOffset: CGFloat = 0
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            // Hintergrund mit Gradient
            LinearGradient(
                colors: [
                    Color(hex: "#221019"),
                    Color(hex: "#1a0c12")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Logo mit Liquid-Effekt
                ZStack {
                    // Liquid Blob Hintergrund
                    LiquidBlobView(isAnimating: isAnimating)
                        .frame(width: 200, height: 200)
                    
                    // App Icon
                    Image("scentboxdicon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .shadow(color: Color(hex: "#C20A66").opacity(0.5), radius: 20, x: 0, y: 10)
                }
                .scaleEffect(scale)
                
                // App Name
                Text("ScentBox")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color(hex: "#C20A66").opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .opacity(opacity)
                
                // Subtitel
                Text("Deine Parfüm-Sammlung")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                scale = 1.0
                opacity = 1.0
            }
            // Finite Animation statt repeatForever — Splash ist nur ~1.5s sichtbar
            withAnimation(.easeInOut(duration: 1.5)) {
                isAnimating = true
            }
        }
    }
}

// Liquid Blob Animation
struct LiquidBlobView: View {
    var isAnimating: Bool
    
    var body: some View {
        ZStack {
            // Mehrere überlappende Blobs für den Liquid-Effekt
            ForEach(0..<3) { index in
                BlobShape(offset: isAnimating ? CGFloat(index) * 20 : 0)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "#C20A66").opacity(0.4 - Double(index) * 0.1),
                                Color(hex: "#F7E7CE").opacity(0.2 - Double(index) * 0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 100
                        )
                    )
                    .scaleEffect(isAnimating ? 1.1 + CGFloat(index) * 0.1 : 1.0)
                    .rotationEffect(.degrees(isAnimating ? Double(index) * 30 : 0))
                    .animation(
                        .easeInOut(duration: 2 + Double(index) * 0.5),
                        value: isAnimating
                    )
            }
        }
    }
}

// Custom Shape für den Blob-Effekt
struct BlobShape: Shape {
    var offset: CGFloat
    
    var animatableData: CGFloat {
        get { offset }
        set { offset = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let centerX = width / 2
        let centerY = height / 2
        let radius = min(width, height) / 2
        
        var path = Path()
        
        // Erstelle einen organischen Blob mit Bezier-Kurven
        let points = 8
        let angleStep = (2 * .pi) / Double(points)
        
        for i in 0..<points {
            let angle = Double(i) * angleStep
            let radiusVariation = radius * (0.8 + 0.2 * sin(angle * 3 + Double(offset) * 0.1))
            let x = centerX + CGFloat(cos(angle)) * radiusVariation
            let y = centerY + CGFloat(sin(angle)) * radiusVariation
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                let prevAngle = Double(i - 1) * angleStep
                let controlRadius = radius * (0.9 + 0.1 * sin(prevAngle * 2))
                let controlX = centerX + CGFloat(cos(prevAngle + angleStep / 2)) * controlRadius
                let controlY = centerY + CGFloat(sin(prevAngle + angleStep / 2)) * controlRadius
                path.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: controlX, y: controlY))
            }
        }
        
        path.closeSubpath()
        return path
    }
}

#Preview {
    SplashScreenView()
}
