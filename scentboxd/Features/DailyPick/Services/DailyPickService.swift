//
//  DailyPickService.swift
//  scentboxd
//
//  Scoring-Algorithmus für tägliche Parfum-Empfehlungen basierend auf
//  Wetter, Anlass, Tageszeit und den Noten der Parfums.
//

import Foundation

// MARK: - Models

enum Occasion: String, CaseIterable, Identifiable {
    case casual  = "casual"
    case work    = "work"
    case date    = "date"
    case sport   = "sport"
    case evening = "evening"
    case formal  = "formal"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .casual:  return "Casual"
        case .work:    return "Arbeit"
        case .date:    return "Date"
        case .sport:   return "Sport"
        case .evening: return "Abend"
        case .formal:  return "Formal"
        }
    }

    var systemImage: String {
        switch self {
        case .casual:  return "tshirt.fill"
        case .work:    return "briefcase.fill"
        case .date:    return "heart.fill"
        case .sport:   return "figure.run"
        case .evening: return "moon.stars.fill"
        case .formal:  return "suit.fill"
        }
    }
}

struct DailyPickCriteria {
    let temperature: Double?
    let humidity: Double?
    let occasion: Occasion
    let timeOfDay: TimeOfDay
    let season: Season
}

struct RecommendedPerfume: Identifiable {
    let id = UUID()
    let perfume: Perfume
    let score: Double
    let reason: String
    let matchPercentage: Int // 0-100
}

// MARK: - Service

@MainActor
final class DailyPickService {

    // MARK: - Seasonal Note Mapping

    private static let seasonalNotes: [Season: Set<String>] = [
        .summer: ["Citrus", "Aquatic", "Fresh", "Green", "Bergamot", "Lemon", "Grapefruit", "Marine", "Mint", "Cucumber"],
        .winter: ["Oriental", "Woody", "Spicy", "Gourmand", "Oud", "Amber", "Vanilla", "Cinnamon", "Tobacco", "Leather"],
        .spring: ["Floral", "Green", "Fresh", "Rose", "Jasmine", "Lily", "Peony", "Iris", "Magnolia", "Violet"],
        .autumn: ["Woody", "Spicy", "Oriental", "Sandalwood", "Cedar", "Patchouli", "Cardamom", "Pepper", "Nutmeg", "Fig"]
    ]

    /// Bevorzugte Sillage je Occasion (1=schwach … 5=stark)
    private static let occasionSillagePreference: [Occasion: Double] = [
        .casual:  2.0,
        .work:    1.5,
        .date:    4.0,
        .sport:   1.0,
        .evening: 4.5,
        .formal:  3.0
    ]

    /// Bevorzugte Longevity je Occasion (1=kurz … 5=lang)
    private static let occasionLongevityPreference: [Occasion: Double] = [
        .casual:  2.5,
        .work:    4.0,
        .date:    4.0,
        .sport:   1.5,
        .evening: 4.5,
        .formal:  4.0
    ]

    // MARK: - Public API

    /// Berechnet die Top-Empfehlungen aus der Sammlung des Users.
    func calculateRecommendations(
        ownedPerfumes: [Perfume],
        criteria: DailyPickCriteria,
        maxResults: Int = 4
    ) -> [RecommendedPerfume] {
        guard !ownedPerfumes.isEmpty else { return [] }

        let scored = ownedPerfumes.map { perfume -> RecommendedPerfume in
            let (score, reason) = calculateScore(for: perfume, criteria: criteria)
            let matchPct = min(100, max(0, Int(score * 100)))
            return RecommendedPerfume(
                perfume: perfume,
                score: score,
                reason: reason,
                matchPercentage: matchPct
            )
        }

        return scored
            .sorted { $0.score > $1.score }
            .prefix(maxResults)
            .map { $0 }
    }

    // MARK: - Scoring Algorithm

    /// Score =
    ///   Noten-Passung (seasonal notes) × 0.3
    ///   + Sillage-Passung              × 0.2
    ///   + Longevity-Passung            × 0.2
    ///   + User-Rating (performance)    × 0.2
    ///   + Zufalls-Bonus                × 0.1
    func calculateScore(for perfume: Perfume, criteria: DailyPickCriteria) -> (score: Double, reason: String) {
        let noteScore = notePassungScore(perfume: perfume, season: criteria.season)
        let sillageScore = sillagePassungScore(perfume: perfume, occasion: criteria.occasion)
        let longevityScore = longevityPassungScore(perfume: perfume, occasion: criteria.occasion)
        let ratingScore = ratingPassungScore(perfume: perfume)
        let randomBonus = Double.random(in: 0.0...1.0)

        let total = noteScore * 0.3
            + sillageScore * 0.2
            + longevityScore * 0.2
            + ratingScore * 0.2
            + randomBonus * 0.1

        let reason = buildReason(
            perfume: perfume,
            criteria: criteria,
            noteScore: noteScore,
            sillageScore: sillageScore
        )

        return (total, reason)
    }

    // MARK: - Individual Scores (0.0 … 1.0)

    /// Wie gut passen die Noten zur Jahreszeit?
    func notePassungScore(perfume: Perfume, season: Season) -> Double {
        let seasonNotes = Self.seasonalNotes[season] ?? []
        guard !seasonNotes.isEmpty else { return 0.5 }

        let allNotes = perfume.topNotes + perfume.midNotes + perfume.baseNotes
        guard !allNotes.isEmpty else { return 0.3 } // Keine Noten → neutraler Score

        let allNoteNames = allNotes.map { $0.name.lowercased() }
        let allCategories = allNotes.compactMap { $0.category?.lowercased() }
        let allIdentifiers = Set(allNoteNames + allCategories)

        let seasonLower = seasonNotes.map { $0.lowercased() }
        let matchCount = allIdentifiers.filter { identifier in
            seasonLower.contains(where: { identifier.contains($0) || $0.contains(identifier) })
        }.count

        // Top Notes zählen extra: Citrus-Top-Noten im Sommer = besser
        let topNoteNames = perfume.topNotes.map { $0.name.lowercased() }
        let topCategories = perfume.topNotes.compactMap { $0.category?.lowercased() }
        let topMatch = Set(topNoteNames + topCategories).filter { identifier in
            seasonLower.contains(where: { identifier.contains($0) || $0.contains(identifier) })
        }.count

        let raw = Double(matchCount + topMatch) / Double(allIdentifiers.count + 1)
        return min(1.0, raw)
    }

    /// Wie gut passt die Sillage zum Anlass?
    func sillagePassungScore(perfume: Perfume, occasion: Occasion) -> Double {
        let preferred = Self.occasionSillagePreference[occasion] ?? 2.5
        let actual = parseSillageLevel(perfume.sillage)
        let diff = abs(preferred - actual)
        // Je näher, desto besser (max diff = 4.0)
        return max(0.0, 1.0 - diff / 4.0)
    }

    /// Wie gut passt die Longevity zum Anlass?
    func longevityPassungScore(perfume: Perfume, occasion: Occasion) -> Double {
        let preferred = Self.occasionLongevityPreference[occasion] ?? 3.0
        let actual = parseLongevityLevel(perfume.longevity)
        let diff = abs(preferred - actual)
        return max(0.0, 1.0 - diff / 4.0)
    }

    /// Normalisiertes Performance-Rating (0…1).
    func ratingPassungScore(perfume: Perfume) -> Double {
        // Performance ist bereits 0…5
        return min(1.0, max(0.0, perfume.performance / 5.0))
    }

    // MARK: - Parsing Helpers

    /// Wandelt String-Sillage in numerischen Wert (1…5).
    private func parseSillageLevel(_ sillage: String) -> Double {
        let lower = sillage.lowercased()
        if lower.contains("stark") || lower.contains("heavy") || lower.contains("enormous") { return 5.0 }
        if lower.contains("mäßig") || lower.contains("moderate") || lower.contains("mittel") { return 3.0 }
        if lower.contains("leicht") || lower.contains("light") || lower.contains("intimate") { return 1.5 }
        if lower.contains("soft") || lower.contains("schwach") { return 1.0 }
        return 2.5 // Default: moderat
    }

    /// Wandelt String-Longevity in numerischen Wert (1…5).
    private func parseLongevityLevel(_ longevity: String) -> Double {
        let lower = longevity.lowercased()
        if lower.contains("lang") || lower.contains("long") || lower.contains("eternal") { return 5.0 }
        if lower.contains("mäßig") || lower.contains("moderate") || lower.contains("mittel") { return 3.0 }
        if lower.contains("kurz") || lower.contains("short") || lower.contains("weak") { return 1.5 }
        if lower.contains("sehr kurz") || lower.contains("very short") { return 1.0 }
        return 3.0 // Default: moderat
    }

    // MARK: - Reason Builder

    private func buildReason(
        perfume: Perfume,
        criteria: DailyPickCriteria,
        noteScore: Double,
        sillageScore: Double
    ) -> String {
        var parts: [String] = []

        // Noten-Passung
        if noteScore > 0.5 {
            let seasonName = criteria.season.displayName
            let topNoteNames = perfume.topNotes.prefix(2).map(\.name).joined(separator: " & ")
            if !topNoteNames.isEmpty {
                parts.append("\(topNoteNames)-Noten passen zum \(seasonName)")
            } else {
                parts.append("Noten passen zur Jahreszeit")
            }
        }

        // Sillage
        if sillageScore > 0.6 {
            let occasionName = criteria.occasion.displayName
            parts.append("Sillage ideal für \(occasionName)")
        }

        // Temperatur
        if let temp = criteria.temperature {
            if temp > 25 {
                parts.append("Leicht & frisch bei \(Int(temp))°C")
            } else if temp < 10 {
                parts.append("Warm & intensiv bei \(Int(temp))°C")
            }
        }

        if parts.isEmpty {
            parts.append("Gute Wahl für \(criteria.occasion.displayName)")
        }

        return parts.joined(separator: " · ")
    }
}
