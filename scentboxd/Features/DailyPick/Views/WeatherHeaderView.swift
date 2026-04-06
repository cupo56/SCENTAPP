//
//  WeatherHeaderView.swift
//  scentboxd
//
//  Wetter-Widget oben in der DailyPickView.
//  Glassmorphism-Card mit Temperatur, Condition und Standort.
//

import SwiftUI

struct WeatherHeaderView: View {
    let weatherService: WeatherService

    var body: some View {
        HStack(spacing: 16) {
            // Wetter-Icon
            ZStack {
                Circle()
                    .fill(iconGradient)
                    .frame(width: 56, height: 56)

                Image(systemName: conditionIcon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: .repeating)
            }

            VStack(alignment: .leading, spacing: 4) {
                // Temperatur
                if let temp = weatherService.currentTemperature {
                    Text("\(Int(temp))°C")
                        .font(DesignSystem.Fonts.display(size: 28, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.appText)
                }

                // Condition + Standort
                HStack(spacing: 6) {
                    if let condition = weatherService.currentCondition {
                        Text(condition.displayName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.primary)
                    }

                    if let location = weatherService.locationName {
                        Text("·")
                            .foregroundStyle(DesignSystem.Colors.appTextSecondary)
                        Text(location)
                            .font(.system(size: 13))
                            .foregroundStyle(DesignSystem.Colors.appTextSecondary)
                    }
                }

                // Tageszeit
                HStack(spacing: 4) {
                    Image(systemName: TimeOfDay.current.systemImage)
                        .font(.system(size: 10))
                    Text(TimeOfDay.current.displayName)
                        .font(.system(size: 11))
                    Text("·")
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 10))
                    Text(Season.current.displayName)
                        .font(.system(size: 11))
                }
                .foregroundStyle(DesignSystem.Colors.appTextSecondary.opacity(0.7))
            }

            Spacer()
        }
        .padding(16)
        .glassPanel()
    }

    // MARK: - Helpers

    private var conditionIcon: String {
        weatherService.currentCondition?.systemImage ?? "cloud.fill"
    }

    private var iconGradient: LinearGradient {
        let condition = weatherService.currentCondition ?? .mild
        let colors: [Color]
        switch condition {
        case .hot:
            colors = [Color(hex: "#FF6B35"), Color(hex: "#F7931E")]
        case .warm:
            colors = [Color(hex: "#FFD700"), Color(hex: "#FFA500")]
        case .mild:
            colors = [Color(hex: "#87CEEB"), Color(hex: "#4AB0E5")]
        case .cool:
            colors = [Color(hex: "#6BB5E6"), Color(hex: "#4A90D9")]
        case .cold:
            colors = [Color(hex: "#A8D8EA"), Color(hex: "#6FB1D6")]
        case .rainy:
            colors = [Color(hex: "#5C7AEA"), Color(hex: "#3D5AF1")]
        case .humid:
            colors = [Color(hex: "#43B581"), Color(hex: "#2D9B6F")]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
