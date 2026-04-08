//
//  CollectionAnalyticsService.swift
//  scentboxd
//
//  Lokale Berechnung von Sammlungs-Statistiken aus SwiftData.
//  Reine Funktion ohne Server-Zugriff.
//

import Foundation

// MARK: - Model

struct CollectionAnalytics: Equatable {
    struct BrandCount: Identifiable, Equatable {
        let brand: String
        let count: Int
        var id: String { brand }
    }

    struct NoteCount: Identifiable, Equatable {
        let note: String
        let count: Int
        var id: String { note }
    }

    struct ConcentrationCount: Identifiable, Equatable {
        let type: String
        let count: Int
        var id: String { type }
    }

    struct MonthlyCount: Identifiable, Equatable {
        let month: Date
        let count: Int
        var id: Date { month }
    }

    let totalPerfumes: Int
    let totalBrands: Int
    let topBrands: [BrandCount]
    let topNotes: [NoteCount]
    let concentrationDistribution: [ConcentrationCount]
    let monthlyAdditions: [MonthlyCount]
    let averageRating: Double
    let totalReviews: Int
    let longevityDistribution: [Int: Int]
    let sillageDistribution: [Int: Int]
    let estimatedValue: Double?

    static let empty = CollectionAnalytics(
        totalPerfumes: 0,
        totalBrands: 0,
        topBrands: [],
        topNotes: [],
        concentrationDistribution: [],
        monthlyAdditions: [],
        averageRating: 0,
        totalReviews: 0,
        longevityDistribution: [:],
        sillageDistribution: [:],
        estimatedValue: nil
    )

    var isEmpty: Bool { totalPerfumes == 0 }
}

// MARK: - Service

@MainActor
final class CollectionAnalyticsService {

    /// Berechnet alle Sammlungs-Statistiken aus den uebergebenen (besessenen) Parfums
    /// und den Reviews des aktuellen Benutzers.
    ///
    /// - Parameters:
    ///   - perfumes: Die Parfums in der Sammlung des Users (`isOwned == true`).
    ///   - userReviews: Reviews, die der aktuelle User selbst geschrieben hat.
    func calculateAnalytics(
        from perfumes: [Perfume],
        userReviews: [Review] = []
    ) -> CollectionAnalytics {
        guard !perfumes.isEmpty else { return .empty }

        // Marken
        let brandNames = perfumes.compactMap { $0.brand?.name }
        let uniqueBrands = Set(brandNames)
        let brandCounts = Dictionary(grouping: brandNames, by: { $0 })
            .map { CollectionAnalytics.BrandCount(brand: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
        let topBrands = Array(brandCounts.prefix(5))

        // Noten (Top, Mid, Base zusammengefasst)
        let allNotes: [String] = perfumes.flatMap { perfume -> [String] in
            let top = perfume.topNotes.map { $0.name }
            let mid = perfume.midNotes.map { $0.name }
            let base = perfume.baseNotes.map { $0.name }
            return top + mid + base
        }
        let noteCounts = Dictionary(grouping: allNotes, by: { $0 })
            .map { CollectionAnalytics.NoteCount(note: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
        let topNotes = Array(noteCounts.prefix(10))

        // Konzentrations-Verteilung
        let concentrations = perfumes.compactMap { $0.concentration?.uppercased() }
            .map(Self.normalizeConcentration)
        let concentrationDistribution = Dictionary(grouping: concentrations, by: { $0 })
            .map { CollectionAnalytics.ConcentrationCount(type: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }

        // Monatliche Neuzugaenge (letzte 12 Monate)
        let monthlyAdditions = Self.computeMonthlyAdditions(from: perfumes)

        // Reviews / Bewertungen
        let totalReviews = userReviews.count
        let averageRating: Double
        if totalReviews > 0 {
            let sum = userReviews.reduce(0) { $0 + $1.rating }
            averageRating = Double(sum) / Double(totalReviews)
        } else {
            averageRating = 0
        }

        // Longevity / Sillage (aus den Reviews des Users)
        let longevityDistribution = Dictionary(
            grouping: userReviews.compactMap { $0.longevity },
            by: { $0 }
        ).mapValues { $0.count }

        let sillageDistribution = Dictionary(
            grouping: userReviews.compactMap { $0.sillage },
            by: { $0 }
        ).mapValues { $0.count }

        return CollectionAnalytics(
            totalPerfumes: perfumes.count,
            totalBrands: uniqueBrands.count,
            topBrands: topBrands,
            topNotes: topNotes,
            concentrationDistribution: concentrationDistribution,
            monthlyAdditions: monthlyAdditions,
            averageRating: averageRating,
            totalReviews: totalReviews,
            longevityDistribution: longevityDistribution,
            sillageDistribution: sillageDistribution,
            estimatedValue: nil
        )
    }

    // MARK: - Helpers

    /// Normalisiert verschiedene Schreibweisen von Konzentrationen auf eine
    /// kleine, konsistente Menge an Labels.
    private static func normalizeConcentration(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        switch trimmed {
        case "EDP", "EAU DE PARFUM":
            return "EDP"
        case "EDT", "EAU DE TOILETTE":
            return "EDT"
        case "PARFUM", "EXTRAIT", "EXTRAIT DE PARFUM":
            return "Parfum"
        case "EDC", "EAU DE COLOGNE":
            return "EDC"
        case "EDF", "EAU FRAICHE", "EAU FRAÎCHE":
            return "Eau Fraîche"
        default:
            return trimmed.capitalized
        }
    }

    /// Erzeugt monatliche Zaehlungen fuer die letzten 12 Monate (inklusive Monate ohne Zugaenge).
    private static func computeMonthlyAdditions(from perfumes: [Perfume]) -> [CollectionAnalytics.MonthlyCount] {
        let calendar = Calendar.current
        let now = Date()

        // Anker: Monatsanfang vor 11 Monaten (=> 12 Buckets inklusive aktuellem Monat)
        guard let earliestMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: calendar.date(byAdding: .month, value: -11, to: now) ?? now)
        ) else {
            return []
        }

        // Zaehle Zugaenge je Monat
        var counts: [Date: Int] = [:]
        for perfume in perfumes {
            guard let dateAdded = perfume.userMetadata?.dateAdded else { continue }
            guard dateAdded >= earliestMonth else { continue }
            let month = calendar.date(from: calendar.dateComponents([.year, .month], from: dateAdded)) ?? dateAdded
            counts[month, default: 0] += 1
        }

        // Buckets fuer alle 12 Monate erzeugen, auch wenn 0
        var buckets: [CollectionAnalytics.MonthlyCount] = []
        for offset in 0..<12 {
            guard let month = calendar.date(byAdding: .month, value: offset, to: earliestMonth) else { continue }
            buckets.append(CollectionAnalytics.MonthlyCount(month: month, count: counts[month] ?? 0))
        }
        return buckets
    }
}
