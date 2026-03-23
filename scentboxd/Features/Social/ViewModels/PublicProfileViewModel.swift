//
//  PublicProfileViewModel.swift
//  scentboxd
//

import Foundation
import os

@Observable
@MainActor
class PublicProfileViewModel {
    var profile: PublicProfileDTO?
    var collection: [PublicCollectionItemDTO] = []
    var isLoading = false
    var isLoadingCollection = false
    var errorMessage: String?
    var hasMorePages = true

    private let dataSource: PublicProfileDataSource
    private let pageSize = AppConfig.Pagination.perfumePageSize
    private var currentPage = 0

    init(dataSource: PublicProfileDataSource) {
        self.dataSource = dataSource
    }

    func loadProfile(userId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            profile = try await dataSource.fetchPublicProfile(userId: userId)
        } catch {
            errorMessage = NetworkError.handle(error, logger: AppLogger.perfumes, context: "PublicProfile")
        }

        isLoading = false
    }

    func loadCollection(userId: UUID) async {
        guard !isLoadingCollection, hasMorePages else { return }
        isLoadingCollection = true

        do {
            let page = try await dataSource.fetchPublicCollection(
                userId: userId,
                page: currentPage,
                pageSize: pageSize
            )
            collection.append(contentsOf: page)
            hasMorePages = page.count >= pageSize
            currentPage += 1
        } catch {
            AppLogger.perfumes.error("Failed to load public collection: \(error.localizedDescription)")
        }

        isLoadingCollection = false
    }

    func resetCollection() {
        collection = []
        currentPage = 0
        hasMorePages = true
    }
}
