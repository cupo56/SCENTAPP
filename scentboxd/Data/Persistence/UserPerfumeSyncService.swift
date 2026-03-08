//
//  UserPerfumeSyncService.swift
//  scentboxd
//
//  Created by Cupo on 25.01.26.
//

import Foundation
import SwiftData
import os

@MainActor
class UserPerfumeSyncService {
    private let remoteDataSource: any UserPerfumeDataSourceProtocol

    init(remoteDataSource: any UserPerfumeDataSourceProtocol) {
        self.remoteDataSource = remoteDataSource
    }

    /// Vollständiger Sync: Erst lokale Änderungen hochladen, dann Remote-Daten übernehmen.
    func syncFromSupabase(modelContext: ModelContext, perfumes: [Perfume]) async throws {
        // 1. Zuerst ausstehende lokale Änderungen hochladen
        await uploadPendingChanges(perfumes: perfumes, modelContext: modelContext)

        // 2. Alle User-Parfum-Zuordnungen aus Supabase laden
        let remotePerfumes = try await remoteDataSource.fetchAllUserPerfumes()

        // 3. Map für schnellen Zugriff erstellen
        let remoteMap = Dictionary(
            uniqueKeysWithValues: remotePerfumes.map {
                ($0.perfumeId, (isFavorite: $0.isFavorite, isOwned: $0.isOwned, isEmpty: $0.isEmpty))
            }
        )

        // 4. Lokale Parfums aktualisieren
        for perfume in perfumes {
            // Lokale Änderungen mit ausstehender Synchronisierung NICHT überschreiben
            if perfume.userMetadata?.hasPendingSync == true {
                AppLogger.sync.debug("Überspringe \(perfume.name) — lokale Änderung noch ausstehend")
                continue
            }

            guard let flags = remoteMap[perfume.id] else { continue }

            // Parfum in Context einfügen falls noch nicht vorhanden
            if perfume.modelContext == nil {
                modelContext.insert(perfume)
            }

            // Metadata aktualisieren oder erstellen
            if let metadata = perfume.userMetadata {
                metadata.isFavorite = flags.isFavorite
                metadata.isOwned = flags.isOwned
                metadata.isEmpty = flags.isEmpty
            } else {
                let newMeta = UserPersonalData(
                    isFavorite: flags.isFavorite,
                    isOwned: flags.isOwned,
                    isEmpty: flags.isEmpty
                )
                perfume.userMetadata = newMeta
            }
        }

        // 5. Änderungen speichern
        try modelContext.save()

        AppLogger.sync.info("User-Parfums synchronisiert: \(remotePerfumes.count) Einträge")
    }

    // MARK: - Upload Pending Changes

    /// Lädt alle lokalen Änderungen hoch, die noch nicht zu Supabase synchronisiert wurden.
    private func uploadPendingChanges(perfumes: [Perfume], modelContext: ModelContext) async {
        let pendingPerfumes = perfumes.filter { $0.userMetadata?.hasPendingSync == true }

        guard !pendingPerfumes.isEmpty else { return }

        AppLogger.sync.info("Lade \(pendingPerfumes.count) ausstehende Änderung(en) hoch…")

        for perfume in pendingPerfumes {
            guard let metadata = perfume.userMetadata else { continue }

            do {
                if metadata.hasNoStatus {
                    try await remoteDataSource.deleteUserPerfume(perfumeId: perfume.id)
                } else {
                    try await remoteDataSource.saveUserPerfume(
                        perfumeId: perfume.id,
                        isFavorite: metadata.isFavorite,
                        isOwned: metadata.isOwned,
                        isEmpty: metadata.isEmpty
                    )
                }
                // Upload erfolgreich → Pending-Flag löschen
                metadata.hasPendingSync = false
            } catch {
                AppLogger.sync.error("Upload fehlgeschlagen für \(perfume.name): \(error.localizedDescription)")
                // Nicht fatal — beim nächsten Sync erneut versuchen
            }
        }

        // Pending-Status-Änderungen speichern
        do {
            try modelContext.save()
        } catch {
            AppLogger.cache.error("SwiftData-Speichern fehlgeschlagen (uploadPending): \(error.localizedDescription)")
        }
    }
}
