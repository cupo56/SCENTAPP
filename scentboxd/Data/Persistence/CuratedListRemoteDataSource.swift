//
//  CuratedListRemoteDataSource.swift
//  scentboxd
//

import Foundation
import Supabase
import os

@MainActor
final class CuratedListRemoteDataSource: CuratedListDataSourceProtocol {
    private let client = AppConfig.client

    // MARK: - Read

    func fetchLists() async throws -> [CuratedListDTO] {
        try await withRetry {
            try await self.client
                .rpc("get_my_lists")
                .execute()
                .value
        }
    }

    func fetchPublicLists(userId: UUID) async throws -> [CuratedListDTO] {
        try await withRetry {
            try await self.client
                .rpc("get_public_lists", params: ["p_user_id": userId])
                .execute()
                .value
        }
    }

    func fetchListItems(listId: UUID) async throws -> [UUID] {
        struct ItemRow: Decodable {
            let perfumeId: UUID
            enum CodingKeys: String, CodingKey { case perfumeId = "perfume_id" }
        }
        let rows: [ItemRow] = try await withRetry {
            try await self.client
                .from("list_items")
                .select("perfume_id")
                .eq("list_id", value: listId)
                .order("added_at", ascending: false)
                .execute()
                .value
        }
        return rows.map(\.perfumeId)
    }

    func fetchListIdsContaining(perfumeId: UUID) async throws -> Set<UUID> {
        struct ItemRow: Decodable {
            let listId: UUID
            enum CodingKeys: String, CodingKey { case listId = "list_id" }
        }
        // Nutze get_my_lists um nur eigene Listen zu berücksichtigen,
        // dann filtere lokal nach perfume_id-Mitgliedschaft.
        let myLists: [CuratedListDTO] = try await withRetry {
            try await self.client
                .rpc("get_my_lists")
                .execute()
                .value
        }
        guard !myLists.isEmpty else { return [] }

        let myListIds = myLists.map(\.id)
        let rows: [ItemRow] = try await withRetry {
            try await self.client
                .from("list_items")
                .select("list_id")
                .eq("perfume_id", value: perfumeId)
                .in("list_id", values: myListIds)
                .execute()
                .value
        }
        return Set(rows.map(\.listId))
    }

    func fetchListCount() async throws -> Int {
        let response = try await withRetry {
            try await self.client
                .from("lists")
                .select("id", head: true, count: .exact)
                .execute()
        }
        return response.count ?? 0
    }

    // MARK: - Create

    func createList(name: String, description: String?, isPublic: Bool) async throws -> CuratedListDTO {
        try validateListName(name)
        let userId = try await AuthSessionCache.shared.getUserId()
        let dto = CuratedListInsertDTO(
            userId: userId,
            name: name.trimmingCharacters(in: .whitespaces),
            description: description,
            isPublic: isPublic
        )
        let created: CuratedListDTO = try await withRetry {
            try await self.client
                .from("lists")
                .insert(dto)
                .select()
                .single()
                .execute()
                .value
        }
        return created
    }

    // MARK: - Update

    func updateList(listId: UUID, name: String, description: String?, isPublic: Bool) async throws {
        try validateListName(name)
        let dto = CuratedListUpdateDTO(name: name.trimmingCharacters(in: .whitespaces), description: description, isPublic: isPublic)
        try await withRetry {
            try await self.client
                .from("lists")
                .update(dto)
                .eq("id", value: listId)
                .execute()
        }
    }

    // MARK: - Delete

    func deleteList(listId: UUID) async throws {
        try await withRetry {
            try await self.client
                .from("lists")
                .delete()
                .eq("id", value: listId)
                .execute()
        }
    }

    // MARK: - Items

    func addPerfume(listId: UUID, perfumeId: UUID) async throws {
        struct InsertRow: Encodable {
            let listId: UUID
            let perfumeId: UUID
            enum CodingKeys: String, CodingKey {
                case listId = "list_id"
                case perfumeId = "perfume_id"
            }
        }
        try await withRetry {
            try await self.client
                .from("list_items")
                .upsert(InsertRow(listId: listId, perfumeId: perfumeId), onConflict: "list_id,perfume_id")
                .execute()
        }
    }

    func removePerfume(listId: UUID, perfumeId: UUID) async throws {
        try await withRetry {
            try await self.client
                .from("list_items")
                .delete()
                .eq("list_id", value: listId)
                .eq("perfume_id", value: perfumeId)
                .execute()
        }
    }

    // MARK: - Validation

    private func validateListName(_ name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            throw NetworkError.validationFailed("Der Listenname darf nicht leer sein.")
        }
        guard trimmed.count <= 100 else {
            throw NetworkError.validationFailed("Der Listenname darf maximal 100 Zeichen lang sein.")
        }
    }
}
