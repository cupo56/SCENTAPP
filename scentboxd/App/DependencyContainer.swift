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
    let profileService: ProfileService
    let publicProfileDataSource: any PublicProfileDataSourceProtocol
    let curatedListDataSource: any CuratedListDataSourceProtocol

    // MARK: - Production Init

    /// Erstellt den Container mit den produktiven Implementierungen.
    init() {
        self.perfumeRepository = PerfumeRemoteDataSource()
        self.profileService = ProfileService()
        self.reviewDataSource = ReviewRemoteDataSource(profileService: self.profileService)
        self.userPerfumeDataSource = UserPerfumeRemoteDataSource()
        self.networkMonitor = NetworkMonitor.shared
        self.cacheService = PerfumeCacheService()
        self.publicProfileDataSource = PublicProfileDataSource()
        self.curatedListDataSource = CuratedListRemoteDataSource()
    }
    
    // MARK: - Test / Custom Init
    
    /// Erstellt den Container mit benutzerdefinierten Abhängigkeiten (z.B. für Tests).
    init(
        perfumeRepository: PerfumeRepository,
        reviewDataSource: any ReviewDataSourceProtocol,
        userPerfumeDataSource: any UserPerfumeDataSourceProtocol,
        networkMonitor: NetworkMonitor,
        cacheService: PerfumeCacheService,
        profileService: ProfileService,
        publicProfileDataSource: any PublicProfileDataSourceProtocol,
        curatedListDataSource: any CuratedListDataSourceProtocol
    ) {
        self.perfumeRepository = perfumeRepository
        self.reviewDataSource = reviewDataSource
        self.userPerfumeDataSource = userPerfumeDataSource
        self.networkMonitor = networkMonitor
        self.cacheService = cacheService
        self.profileService = profileService
        self.publicProfileDataSource = publicProfileDataSource
        self.curatedListDataSource = curatedListDataSource
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

    func makeSearchSuggestionService() -> SearchSuggestionService {
        SearchSuggestionService(repository: perfumeRepository)
    }

    func makePerfumeListViewModel(filterVM: PerfumeFilterViewModel) -> PerfumeListViewModel {
        PerfumeListViewModel(
            dataLoader: makePerfumeDataLoader(),
            networkMonitor: networkMonitor,
            filterVM: filterVM,
            searchSuggestionService: makeSearchSuggestionService()
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
            ),
            similarService: SimilarPerfumesService(
                repository: perfumeRepository
            )
        )
    }
    
    func makeSyncService() -> UserPerfumeSyncService {
        UserPerfumeSyncService(remoteDataSource: userPerfumeDataSource)
    }

    func makePerfumeResolver() -> PerfumeResolver {
        PerfumeResolver(repository: perfumeRepository)
    }

    func makeReviewSyncService() -> ReviewSyncService {
        ReviewSyncService(reviewDataSource: reviewDataSource)
    }

    func makeFragranceProfileService() -> FragranceProfileService {
        FragranceProfileService()
    }

    func makeScentWheelService() -> ScentWheelService {
        ScentWheelService()
    }
    
    func makeBarcodeScannerViewModel() -> BarcodeScannerViewModel {
        BarcodeScannerViewModel(repository: perfumeRepository, networkMonitor: networkMonitor)
    }

    func makePublicProfileViewModel() -> PublicProfileViewModel {
        PublicProfileViewModel(dataSource: publicProfileDataSource)
    }

    func makeRecommendationsViewModel() -> RecommendationsViewModel {
        RecommendationsViewModel(repository: perfumeRepository)
    }

    func makeAuthManager() -> AuthManager {
        AuthManager(profileService: profileService)
    }

    // MARK: - Daily Pick

    private(set) lazy var weatherService = WeatherService()

    func makeDailyPickViewModel() -> DailyPickViewModel {
        DailyPickViewModel(weatherService: weatherService)
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
