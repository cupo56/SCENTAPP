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
    private let remoteDataSource = UserPerfumeRemoteDataSource()
    
    /// Synchronisiert die User-Parfums aus Supabase mit dem lokalen SwiftData Store
    func syncFromSupabase(modelContext: ModelContext, perfumes: [Perfume]) async throws {
        // 1. Alle User-Parfum-Zuordnungen aus Supabase laden
        let remotePerfumes = try await withRetry {
            try await self.remoteDataSource.fetchAllUserPerfumes()
        }
        
        // 2. Map für schnellen Zugriff erstellen
        let remoteStatusMap = Dictionary(
            uniqueKeysWithValues: remotePerfumes.map { ($0.perfumeId, $0.status) }
        )
        
        // 3. Lokale Parfums aktualisieren
        for perfume in perfumes {
            if let statusString = remoteStatusMap[perfume.id],
               let status = UserPerfumeStatus(rawValue: statusString) {
                
                // Parfum in Context einfügen falls noch nicht vorhanden
                if perfume.modelContext == nil {
                    modelContext.insert(perfume)
                }
                
                // Metadata aktualisieren oder erstellen
                if let metadata = perfume.userMetadata {
                    if metadata.status != status {
                        metadata.status = status
                    }
                } else {
                    let newMeta = UserPersonalData(status: status)
                    perfume.userMetadata = newMeta
                }
            } else {
                // Kein Remote-Status -> lokalen Status auf .none setzen (falls vorhanden)
                if let metadata = perfume.userMetadata, metadata.status != .none {
                    metadata.status = .none
                }
            }
        }
        
        // 4. Änderungen speichern
        try modelContext.save()
        
        AppLogger.sync.info("User-Parfums synchronisiert: \(remotePerfumes.count) Einträge")
    }
}
