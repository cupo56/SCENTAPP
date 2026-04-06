//
//  WeatherService.swift
//  scentboxd
//
//  Wetter-Service für den Daily Pick. Verwendet WeatherKit + CoreLocation.
//  Fallback auf Jahreszeit aus Datum, wenn WeatherKit nicht verfügbar.
//

import Foundation
import CoreLocation
import WeatherKit
import os

@Observable @MainActor
final class WeatherService: NSObject {

    // MARK: - Public State

    var currentTemperature: Double?
    var currentCondition: WeatherCondition?
    var humidity: Double?
    var locationName: String?
    var isLoading = false
    var errorMessage: String?

    // MARK: - Weather Condition

    enum WeatherCondition: String, CaseIterable {
        case hot      // > 30°C
        case warm     // 22-30°C
        case mild     // 15-22°C
        case cool     // 5-15°C
        case cold     // < 5°C
        case rainy
        case humid    // humidity > 70%

        var displayName: String {
            switch self {
            case .hot:   return "Heiß"
            case .warm:  return "Warm"
            case .mild:  return "Mild"
            case .cool:  return "Kühl"
            case .cold:  return "Kalt"
            case .rainy: return "Regnerisch"
            case .humid: return "Schwül"
            }
        }

        var systemImage: String {
            switch self {
            case .hot:   return "sun.max.fill"
            case .warm:  return "sun.min.fill"
            case .mild:  return "cloud.sun.fill"
            case .cool:  return "wind"
            case .cold:  return "snowflake"
            case .rainy: return "cloud.rain.fill"
            case .humid: return "humidity.fill"
            }
        }
    }

    // MARK: - Private

    private let locationManager = CLLocationManager()
    private let weatherService = WeatherKit.WeatherService.shared
    private let logger = Logger(subsystem: "scentboxd", category: "WeatherService")
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    // MARK: - Public API

    func fetchCurrentWeather() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        // 1. Location anfordern
        guard let location = await requestLocation() else {
            logger.info("Standort nicht verfügbar — verwende saisonalen Fallback")
            applySeasonalFallback()
            return
        }

        // 2. WeatherKit abfragen
        do {
            let weather = try await weatherService.weather(for: location)
            let temp = weather.currentWeather.temperature.converted(to: .celsius).value
            let hum = weather.currentWeather.humidity * 100
            let isRaining = weather.currentWeather.condition.isRainy

            currentTemperature = temp
            humidity = hum
            currentCondition = classifyCondition(temperature: temp, humidity: hum, isRaining: isRaining)

            // Reverse-Geocode für Standortname
            await resolveLocationName(location)

            logger.info("Wetter geladen: \(temp, format: .fixed(precision: 1))°C, \(self.currentCondition?.rawValue ?? "?")")
        } catch {
            logger.error("WeatherKit Fehler: \(error.localizedDescription)")
            applySeasonalFallback()
        }
    }

    /// Saisonaler Fallback ohne WeatherKit.
    func applySeasonalFallback() {
        let season = Season.current
        switch season {
        case .summer:
            currentTemperature = 28
            currentCondition = .warm
            humidity = 50
        case .winter:
            currentTemperature = 2
            currentCondition = .cold
            humidity = 60
        case .spring:
            currentTemperature = 16
            currentCondition = .mild
            humidity = 55
        case .autumn:
            currentTemperature = 12
            currentCondition = .cool
            humidity = 65
        }
        locationName = nil
    }

    // MARK: - Helpers

    private func classifyCondition(temperature: Double, humidity: Double, isRaining: Bool) -> WeatherCondition {
        if isRaining { return .rainy }
        if humidity > 70 && temperature > 22 { return .humid }
        if temperature > 30 { return .hot }
        if temperature > 22 { return .warm }
        if temperature > 15 { return .mild }
        if temperature > 5 { return .cool }
        return .cold
    }

    private func requestLocation() async -> CLLocation? {
        let status = locationManager.authorizationStatus

        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            // Warte kurz auf Authorization-Callback
            try? await Task.sleep(for: .seconds(1))
            let newStatus = locationManager.authorizationStatus
            guard newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways else {
                return nil
            }
        case .denied, .restricted:
            return nil
        case .authorizedWhenInUse, .authorizedAlways:
            break
        @unknown default:
            return nil
        }

        return await withCheckedContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestLocation()
        }
    }

    private func resolveLocationName(_ location: CLLocation) async {
        let geocoder = CLGeocoder()
        if let placemarks = try? await geocoder.reverseGeocodeLocation(location),
           let placemark = placemarks.first {
            locationName = placemark.locality ?? placemark.administrativeArea
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension WeatherService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.last
        Task { @MainActor in
            locationContinuation?.resume(returning: location)
            locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            logger.error("Location Fehler: \(error.localizedDescription)")
            locationContinuation?.resume(returning: nil)
            locationContinuation = nil
        }
    }
}

// MARK: - WeatherKit Condition Extension

private extension WeatherKit.WeatherCondition {
    var isRainy: Bool {
        switch self {
        case .rain, .heavyRain, .drizzle, .freezingRain, .thunderstorms, .strongStorms:
            return true
        default:
            return false
        }
    }
}

// MARK: - Season

enum Season: String, CaseIterable {
    case spring, summer, autumn, winter

    /// Erkennt die aktuelle Jahreszeit basierend auf dem Datum (Nordhalbkugel).
    static var current: Season {
        from(date: Date())
    }

    static func from(date: Date) -> Season {
        let month = Calendar.current.component(.month, from: date)
        switch month {
        case 3...5:  return .spring
        case 6...8:  return .summer
        case 9...11: return .autumn
        default:     return .winter
        }
    }

    var displayName: String {
        switch self {
        case .spring: return "Frühling"
        case .summer: return "Sommer"
        case .autumn: return "Herbst"
        case .winter: return "Winter"
        }
    }
}

// MARK: - TimeOfDay

enum TimeOfDay: String, CaseIterable {
    case morning, afternoon, evening, night

    static var current: TimeOfDay {
        from(hour: Calendar.current.component(.hour, from: Date()))
    }

    static func from(hour: Int) -> TimeOfDay {
        switch hour {
        case 5..<12:  return .morning
        case 12..<17: return .afternoon
        case 17..<21: return .evening
        default:      return .night
        }
    }

    var displayName: String {
        switch self {
        case .morning:   return "Morgens"
        case .afternoon: return "Nachmittags"
        case .evening:   return "Abends"
        case .night:     return "Nachts"
        }
    }

    var systemImage: String {
        switch self {
        case .morning:   return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening:   return "sunset.fill"
        case .night:     return "moon.stars.fill"
        }
    }
}
