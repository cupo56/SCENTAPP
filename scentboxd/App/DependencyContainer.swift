//
//  DependencyContainer.swift
//  scentboxd
//

import Foundation
import SwiftUI

/// Zentraler Dependency-Injection-Container.
/// Hält alle Abhängigkeiten als Protocols und erzeugt fertig konfigurierte ViewModels/Services.
@MainActor
final class DependencyContainer {
    
    // MARK: - Dependencies
    
    let perfumeRepository: PerfumeRepository
    let reviewDataSource: any ReviewDataSourceProtocol
    let userPerfumeDataSource: any UserPerfumeDataSourceProtocol
    let networkMonitor: NetworkMonitor
    let cacheService: PerfumeCacheService
    
    // MARK: - Production Init
    
    /// Erstellt den Container mit den produktiven Implementierungen.
    init() {
        self.perfumeRepository = PerfumeRemoteDataSource()
        self.reviewDataSource = ReviewRemoteDataSource()
        self.userPerfumeDataSource = UserPerfumeRemoteDataSource()
        self.networkMonitor = NetworkMonitor.shared
        self.cacheService = PerfumeCacheService()
    }
    
    // MARK: - Test / Custom Init
    
    /// Erstellt den Container mit benutzerdefinierten Abhängigkeiten (z.B. für Tests).
    init(
        perfumeRepository: PerfumeRepository,
        reviewDataSource: any ReviewDataSourceProtocol,
        userPerfumeDataSource: any UserPerfumeDataSourceProtocol,
        networkMonitor: NetworkMonitor,
        cacheService: PerfumeCacheService
    ) {
        self.perfumeRepository = perfumeRepository
        self.reviewDataSource = reviewDataSource
        self.userPerfumeDataSource = userPerfumeDataSource
        self.networkMonitor = networkMonitor
        self.cacheService = cacheService
    }
    
    // MARK: - Factory Methods
    
    func makePerfumeFilterViewModel() -> PerfumeFilterViewModel {
        PerfumeFilterViewModel(repository: perfumeRepository)
    }

    func makePerfumeDataLoader() -> PerfumeDataLoader {
        PerfumeDataLoader(
            repository: perfumeRepository,
            reviewDataSource: reviewDataSource,
            cacheService: cacheService,
            networkMonitor: networkMonitor
        )
    }

    func makePerfumeListViewModel(filterVM: PerfumeFilterViewModel) -> PerfumeListViewModel {
        PerfumeListViewModel(
            dataLoader: makePerfumeDataLoader(),
            networkMonitor: networkMonitor,
            filterVM: filterVM
        )
    }

    func makePerfumeDetailViewModel(perfume: Perfume) -> PerfumeDetailViewModel {
        PerfumeDetailViewModel(
            perfume: perfume,
            reviewService: ReviewManagementService(
                perfumeId: perfume.id,
                reviewDataSource: reviewDataSource
            ),
            statusService: PerfumeStatusService(
                userPerfumeDataSource: userPerfumeDataSource
            )
        )
    }
    
    func makeSyncService() -> UserPerfumeSyncService {
        UserPerfumeSyncService(remoteDataSource: userPerfumeDataSource)
    }

    func makeReviewSyncService() -> ReviewSyncService {
        ReviewSyncService(reviewDataSource: reviewDataSource)
    }
}

// MARK: - SwiftUI Environment

private struct DependencyContainerKey: EnvironmentKey {
    @MainActor static let defaultValue = DependencyContainer()
}

extension EnvironmentValues {
    var dependencies: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}
