//
//  ConcentrationDonut.swift
//  scentboxd
//
//  Donut Chart fuer die Verteilung der Konzentrationen (EDP, EDT, etc.).
//

import SwiftUI
import Charts

struct ConcentrationDonut: View {
    let distribution: [CollectionAnalytics.ConcentrationCount]

    private static let palette: [Color] = [
        DesignSystem.Colors.primary,
        DesignSystem.Colors.champagne,
        Color(hex: "#7C3AED"),
        Color(hex: "#0EA5E9"),
        Color(hex: "#22C55E"),
        Color(hex: "#F97316")
    ]

    private var total: Int {
        distribution.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            Chart(Array(distribution.enumerated()), id: \.element.id) { index, item in
                SectorMark(
                    angle: .value("Anzahl", item.count),
                    innerRadius: .ratio(0.62),
                    angularInset: 2
                )
                .cornerRadius(4)
                .foregroundStyle(Self.palette[index % Self.palette.count])
            }
            .frame(width: 140, height: 140)
            .overlay {
                VStack(spacing: 2) {
                    Text("\(total)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.primary)
                    Text("Parfums")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.appTextSecondary)
                        .textCase(.uppercase)
                        .tracking(1)
                }
            }

            // Legende
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(distribution.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Self.palette[index % Self.palette.count])
                            .frame(width: 10, height: 10)
                        Text(item.type)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.primary)
                        Spacer(minLength: 8)
                        Text("\(item.count)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.appTextSecondary)
                            .monospacedDigit()
                    }
                }
            }
        }
    }
}
