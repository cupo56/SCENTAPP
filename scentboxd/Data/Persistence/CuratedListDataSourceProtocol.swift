//
//  CuratedListDataSourceProtocol.swift
//  scentboxd
//

import Foundation

/// Protocol für Curated-List-Operationen, ermöglicht Dependency-Injection und Testbarkeit.
@MainActor
protocol CuratedListDataSourceProtocol {
    /// Lädt alle eigenen Listen des aktuellen Users (inkl. Item-Anzahl).
    func fetchLists() async throws -> [CuratedListDTO]

    /// Lädt alle öffentlichen Listen eines bestimmten Users.
    func fetchPublicLists(userId: UUID) async throws -> [CuratedListDTO]

    /// Erstellt eine neue Liste.
    func createList(name: String, description: String?, isPublic: Bool) async throws -> CuratedListDTO

    /// Aktualisiert Name, Beschreibung und Sichtbarkeit einer Liste.
    func updateList(listId: UUID, name: String, description: String?, isPublic: Bool) async throws

    /// Löscht eine Liste samt aller Einträge.
    func deleteList(listId: UUID) async throws

    /// Lädt die Parfum-IDs in einer Liste (nicht paginiert — Listen sind klein).
    func fetchListItems(listId: UUID) async throws -> [UUID]

    /// Fügt ein Parfum zu einer Liste hinzu.
    func addPerfume(listId: UUID, perfumeId: UUID) async throws

    /// Entfernt ein Parfum aus einer Liste.
    func removePerfume(listId: UUID, perfumeId: UUID) async throws

    /// Gibt die IDs aller Listen zurück, die ein bestimmtes Parfum enthalten.
    func fetchListIdsContaining(perfumeId: UUID) async throws -> Set<UUID>

    /// Zählt alle eigenen Listen des aktuellen Users.
    func fetchListCount() async throws -> Int
}
