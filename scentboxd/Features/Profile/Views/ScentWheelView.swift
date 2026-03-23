//
//  ScentWheelView.swift
//  scentboxd
//

import SwiftUI
import Charts

struct ScentWheelView: View {
    let segments: [ScentWheelSegment]

    @State private var selectedFamily: String?
    @State private var animationProgress: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader

            if segments.isEmpty {
                emptyState
            } else {
                chart
                legend
            }
        }
        .padding(16)
        .glassPanel()
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animationProgress = 1.0
            }
        }
    }

    // MARK: - Header

    private var sectionHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "chart.pie")
                .font(.system(size: 12))
            Text("DUFTFAMILIEN")
                .tracking(1.5)
        }
        .font(DesignSystem.Fonts.display(size: 11, weight: .semibold))
        .foregroundStyle(Color(hex: "#94A3B8"))
    }

    // MARK: - Chart

    private var chart: some View {
        Chart(segments) { segment in
            SectorMark(
                angle: .value("Anteil", segment.percentage * animationProgress),
                innerRadius: .ratio(0.5),
                angularInset: 2
            )
            .foregroundStyle(colorForFamily(segment.family))
            .cornerRadius(4)
            .opacity(selectedFamily == nil || selectedFamily == segment.family ? 1.0 : 0.35)
        }
        .frame(height: 200)
        .chartOverlay { proxy in
            GeometryReader { geo in
                // Tap-Handling über unsichtbares Overlay
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        handleChartTap(location: location, proxy: proxy, geometry: geo)
                    }
            }
        }
        // Ausgewählte Familie als Annotation in der Mitte
        .overlay(alignment: .center) {
            if let family = selectedFamily,
               let segment = segments.first(where: { $0.family == family }) {
                VStack(spacing: 2) {
                    Text(segment.family)
                        .font(DesignSystem.Fonts.display(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(String(format: "%.0f%%", segment.percentage))
                        .font(DesignSystem.Fonts.display(size: 11))
                        .foregroundStyle(DesignSystem.Colors.champagne)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: - Legend

    private var legend: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(segments) { segment in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedFamily = selectedFamily == segment.family ? nil : segment.family
                    }
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(colorForFamily(segment.family))
                            .frame(width: 10, height: 10)
                        Text(segment.family)
                            .font(DesignSystem.Fonts.display(size: 13))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer()
                        Text("\(segment.count)")
                            .font(DesignSystem.Fonts.display(size: 12, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.champagne)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .background(
                        selectedFamily == segment.family
                        ? colorForFamily(segment.family).opacity(0.15)
                        : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        HStack {
            Spacer()
            Text("Keine Duftfamilien gefunden")
                .font(DesignSystem.Fonts.display(size: 13))
                .foregroundStyle(Color(hex: "#94A3B8"))
            Spacer()
        }
        .padding(.vertical, 16)
    }

    // MARK: - Helpers

    private func colorForFamily(_ family: String) -> Color {
        DesignSystem.Colors.scentFamily(family)
    }

    /// Einfacher Chart-Tap: Segment per Winkel bestimmen.
    private func handleChartTap(location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        // Berechne Winkel relativ zur Chart-Mitte
        let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let radius = sqrt(dx * dx + dy * dy)
        let innerRadius = min(geometry.size.width, geometry.size.height) / 4

        // Nur außerhalb des Innenkreises
        guard radius > innerRadius else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedFamily = nil
            }
            return
        }

        // Winkel berechnen (0° oben, im Uhrzeigersinn)
        var angle = atan2(dx, -dy) * 180 / .pi
        if angle < 0 { angle += 360 }

        // Segment anhand des kumulierten Winkels finden
        var cumulative: Double = 0
        for segment in segments {
            let segmentAngle = segment.percentage / 100.0 * 360.0
            if angle < cumulative + segmentAngle {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedFamily = selectedFamily == segment.family ? nil : segment.family
                }
                return
            }
            cumulative += segmentAngle
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        DesignSystem.Colors.bgDark.ignoresSafeArea()
        ScentWheelView(segments: [
            ScentWheelSegment(family: "Woody", count: 8, percentage: 32),
            ScentWheelSegment(family: "Floral", count: 6, percentage: 24),
            ScentWheelSegment(family: "Oriental", count: 5, percentage: 20),
            ScentWheelSegment(family: "Fresh", count: 4, percentage: 16),
            ScentWheelSegment(family: "Citrus", count: 2, percentage: 8)
        ])
        .padding()
    }
}
