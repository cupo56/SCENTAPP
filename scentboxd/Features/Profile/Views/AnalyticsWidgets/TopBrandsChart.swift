//
//  TopBrandsChart.swift
//  scentboxd
//
//  Horizontales Balkendiagramm der Top-Marken in der Sammlung.
//

import SwiftUI
import Charts

struct TopBrandsChart: View {
    let brands: [CollectionAnalytics.BrandCount]

    var body: some View {
        Chart(brands) { item in
            BarMark(
                x: .value("Anzahl", item.count),
                y: .value("Marke", item.brand)
            )
            .foregroundStyle(DesignSystem.Colors.primary.gradient)
            .cornerRadius(6)
            .annotation(position: .trailing) {
                Text("\(item.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.appTextSecondary)
                    .padding(.leading, 4)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisValueLabel()
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.primary)
            }
        }
        .frame(height: CGFloat(max(brands.count, 1)) * 36 + 16)
    }
}
