//
//  CollectionTimeline.swift
//  scentboxd
//
//  Linien-Chart der monatlichen Sammlungs-Neuzugaenge (letzte 12 Monate).
//

import SwiftUI
import Charts

struct CollectionTimeline: View {
    let monthlyAdditions: [CollectionAnalytics.MonthlyCount]

    var body: some View {
        Chart(monthlyAdditions) { item in
            AreaMark(
                x: .value("Monat", item.month, unit: .month),
                y: .value("Anzahl", item.count)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        DesignSystem.Colors.primary.opacity(0.35),
                        DesignSystem.Colors.primary.opacity(0.02)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.monotone)

            LineMark(
                x: .value("Monat", item.month, unit: .month),
                y: .value("Anzahl", item.count)
            )
            .foregroundStyle(DesignSystem.Colors.primary)
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .interpolationMethod(.monotone)

            PointMark(
                x: .value("Monat", item.month, unit: .month),
                y: .value("Anzahl", item.count)
            )
            .foregroundStyle(DesignSystem.Colors.primary)
            .symbolSize(item.count > 0 ? 50 : 0)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month, count: 2)) { value in
                AxisValueLabel(format: .dateTime.month(.narrow), centered: false)
                    .font(.system(size: 10))
                    .foregroundStyle(DesignSystem.Colors.appTextSecondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine()
                    .foregroundStyle(Color.primary.opacity(0.06))
                AxisValueLabel()
                    .font(.system(size: 10))
                    .foregroundStyle(DesignSystem.Colors.appTextSecondary)
            }
        }
        .frame(height: 160)
    }
}
