//
//  RecommendationEngine.swift
//  scentboxd
//
//  Content-Based Filtering über Noten-Ähnlichkeit (Cosine Similarity).
//  Läuft vollständig lokal auf dem Gerät – kein Server erforderlich.
//

import Foundation
import SwiftData

/// Berechnet personalisierte Parfum-Empfehlungen anhand der Noten-Übereinstimmung
/// zwischen dem Nutzerprofil (owned + favorisierte Düfte) und dem gesamten Katalog.
@Observable
@MainActor
final class RecommendationEngine {

    // MARK: - Types

    struct RecommendedPerfume: Identifiable {
        let id: UUID
        let perfume: Perfume
        /// Cosine-Ähnlichkeit zum Nutzerprofil (0…1)
        let score: Double
        /// Menschenlesbare Begründung, z.B. "Weil du Oud-Noten magst"
        let reason: String

        init(perfume: Perfume, score: Double, reason: String) {
            self.id = perfume.id
            self.perfume = perfume
            self.score = score
            self.reason = reason
        }
    }

    // MARK: - Public API

    /// Berechnet Empfehlungen asynchron.
    ///
    /// - Parameters:
    ///   - ownedPerfumes:     Vom Nutzer besessene Parfums
    ///   - favoritePerfumes:  Vom Nutzer favorisierte Parfums
    ///   - allPerfumes:       Gesamter Katalog (Datengrundlage)
    ///   - limit:             Maximale Anzahl Empfehlungen
    /// - Returns: Sortierte Liste der besten Empfehlungen (höchster Score zuerst)
    func calculateRecommendations(
        ownedPerfumes: [Perfume],
        favoritePerfumes: [Perfume],
        allPerfumes: [Perfume],
        limit: Int = 20
    ) async -> [RecommendedPerfume] {

        // Basis-Sammlung: owned + favorites (dedupliziert)
        var seen = Set<UUID>()
        let basePerfumes = (ownedPerfumes + favoritePerfumes).filter { seen.insert($0.id).inserted }
        guard !basePerfumes.isEmpty else { return [] }

        let excludedIds = Set(basePerfumes.map { $0.id })

        // ── Noten-Vokabular aufbauen ──────────────────────────────────────────
        let vocab = buildVocabulary(from: allPerfumes)
        guard !vocab.isEmpty else { return [] }

        // ── Nutzerprofil-Vektor ───────────────────────────────────────────────
        // Gewichtung: Favoriten zählen doppelt (stärkere Präferenz-Aussage)
        var userVector = [Double](repeating: 0, count: vocab.count)
        for perfume in ownedPerfumes {
            accumulate(notes: allNotes(of: perfume), into: &userVector, vocab: vocab, weight: 1.0)
        }
        for perfume in favoritePerfumes {
            accumulate(notes: allNotes(of: perfume), into: &userVector, vocab: vocab, weight: 2.0)
        }
        // Auf Durchschnitt normalisieren
        let weightSum = Double(ownedPerfumes.count) + Double(favoritePerfumes.count) * 2.0
        if weightSum > 0 {
            userVector = userVector.map { $0 / weightSum }
        }

        // ── Noten-Häufigkeiten für Begründungstexte ───────────────────────────
        let noteFrequency = buildNoteFrequency(basePerfumes: basePerfumes)

        // ── Kandidaten-Perfums bewerten ───────────────────────────────────────
        var results: [RecommendedPerfume] = []

        for perfume in allPerfumes {
            guard !excludedIds.contains(perfume.id) else { continue }

            let notes = allNotes(of: perfume)
            guard !notes.isEmpty else { continue }

            var perfumeVector = [Double](repeating: 0, count: vocab.count)
            accumulate(notes: notes, into: &perfumeVector, vocab: vocab, weight: 1.0)

            let score = cosineSimilarity(userVector, perfumeVector)
            guard score > 0 else { continue }

            let reason = buildReason(
                perfumeNotes: notes,
                noteFrequency: noteFrequency,
                perfume: perfume
            )

            results.append(RecommendedPerfume(perfume: perfume, score: score, reason: reason))
        }

        return results
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Private Helpers

    private func allNotes(of perfume: Perfume) -> [String] {
        (perfume.topNotes + perfume.midNotes + perfume.baseNotes).map { $0.name }
    }

    /// Erstellt ein Wörterbuch Note → Index aus dem gesamten Katalog.
    private func buildVocabulary(from perfumes: [Perfume]) -> [String: Int] {
        var allNames = Set<String>()
        for perfume in perfumes {
            allNames.formUnion(allNotes(of: perfume))
        }
        return Dictionary(uniqueKeysWithValues: allNames.sorted().enumerated().map { ($0.element, $0.offset) })
    }

    /// Addiert die gewichteten Noten-Beiträge eines Parfums auf einen Vektor.
    private func accumulate(
        notes: [String],
        into vector: inout [Double],
        vocab: [String: Int],
        weight: Double
    ) {
        for note in notes {
            if let idx = vocab[note] {
                vector[idx] += weight
            }
        }
    }

    /// Cosine-Ähnlichkeit zweier Vektoren gleicher Länge.
    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        var dot = 0.0, magA = 0.0, magB = 0.0
        for i in 0..<a.count {
            dot  += a[i] * b[i]
            magA += a[i] * a[i]
            magB += b[i] * b[i]
        }
        guard magA > 0, magB > 0 else { return 0 }
        return dot / (sqrt(magA) * sqrt(magB))
    }

    /// Zählt wie oft jede Note in der Basis-Sammlung vorkommt.
    private func buildNoteFrequency(basePerfumes: [Perfume]) -> [String: Int] {
        var freq: [String: Int] = [:]
        for perfume in basePerfumes {
            for note in allNotes(of: perfume) {
                freq[note, default: 0] += 1
            }
        }
        return freq
    }

    /// Liefert einen deutschen Begründungstext für eine Empfehlung.
    private func buildReason(
        perfumeNotes: [String],
        noteFrequency: [String: Int],
        perfume: Perfume
    ) -> String {
        // Die Note aus dem Kandidaten, die am häufigsten im Nutzerprofil vorkommt
        let bestNote = perfumeNotes
            .compactMap { note -> (String, Int)? in
                guard let freq = noteFrequency[note] else { return nil }
                return (note, freq)
            }
            .max(by: { $0.1 < $1.1 })
            .map { $0.0 }

        if let note = bestNote {
            return "Weil du \(note)-Noten magst"
        }

        // Kategorie-Fallback
        let categories = (perfume.topNotes + perfume.midNotes + perfume.baseNotes)
            .compactMap { $0.category }
        if let category = categories.first {
            return "Passend zu deinen \(category)-Düften"
        }

        return "Basierend auf deiner Sammlung"
    }
}
