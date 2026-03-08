//
//  UserPerfumeDataSourceProtocol.swift
//  scentboxd
//

import Foundation

/// Protocol for user-perfume status operations, enabling dependency injection and testability.
@MainActor
protocol UserPerfumeDataSourceProtocol {
    /// Saves or updates a perfume status for the current user.
    func saveUserPerfume(perfumeId: UUID, isFavorite: Bool, isOwned: Bool, isEmpty: Bool) async throws
    
    /// Deletes a perfume status for the current user.
    func deleteUserPerfume(perfumeId: UUID) async throws
    
    /// Fetches all user-perfume associations for the current user.
    func fetchAllUserPerfumes() async throws -> [UserPerfumeDTO]
}
