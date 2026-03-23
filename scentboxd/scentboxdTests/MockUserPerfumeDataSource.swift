//
//  MockUserPerfumeDataSource.swift
//  scentboxdTests
//

import Foundation
@testable import scentboxd

@MainActor
final class MockUserPerfumeDataSource: UserPerfumeDataSourceProtocol {
    
    // MARK: - Configurable Responses
    
    var errorToThrow: Error?
    
    // MARK: - Call Tracking
    
    private(set) var saveCalled = 0
    private(set) var deleteCalled = 0
    private(set) var lastSavedPerfumeId: UUID?
    private(set) var lastSavedIsFavorite: Bool?
    private(set) var lastSavedIsOwned: Bool?
    private(set) var lastSavedIsWantToTry: Bool?
    private(set) var lastDeletedPerfumeId: UUID?
    
    // MARK: - UserPerfumeDataSourceProtocol
    
    func saveUserPerfume(perfumeId: UUID, isFavorite: Bool, isOwned: Bool, isWantToTry: Bool) async throws {
        saveCalled += 1
        lastSavedPerfumeId = perfumeId
        lastSavedIsFavorite = isFavorite
        lastSavedIsOwned = isOwned
        lastSavedIsWantToTry = isWantToTry
        if let error = errorToThrow { throw error }
    }
    
    func deleteUserPerfume(perfumeId: UUID) async throws {
        deleteCalled += 1
        lastDeletedPerfumeId = perfumeId
        if let error = errorToThrow { throw error }
    }
    
    // MARK: - fetchAllUserPerfumes
    
    var userPerfumesToReturn: [UserPerfumeDTO] = []
    private(set) var fetchAllUserPerfumesCalled = 0
    
    func fetchAllUserPerfumes() async throws -> [UserPerfumeDTO] {
        fetchAllUserPerfumesCalled += 1
        if let error = errorToThrow { throw error }
        return userPerfumesToReturn
    }
}
