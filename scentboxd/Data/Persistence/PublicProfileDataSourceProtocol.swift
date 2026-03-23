//
//  PublicProfileDataSourceProtocol.swift
//  scentboxd
//

import Foundation

/// Protocol for public profile data source operations, enabling dependency injection and testability.
@MainActor
protocol PublicProfileDataSourceProtocol {
    /// Fetches the public profile for a user.
    func fetchPublicProfile(userId: UUID) async throws -> PublicProfileDTO

    /// Fetches the public collection of a user (paginated).
    func fetchPublicCollection(userId: UUID, page: Int, pageSize: Int) async throws -> [PublicCollectionItemDTO]

    /// Searches for users by username.
    func searchUsers(query: String) async throws -> [PublicProfileDTO]

    /// Updates the visibility of the current user's profile.
    func updateProfileVisibility(userId: UUID, isPublic: Bool) async throws

    /// Updates the bio of the current user's profile.
    func updateBio(userId: UUID, bio: String) async throws
}
