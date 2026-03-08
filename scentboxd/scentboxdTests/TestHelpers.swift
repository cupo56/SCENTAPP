//
//  TestHelpers.swift
//  scentboxdTests
//

import Foundation
import SwiftData
@testable import scentboxd

// MARK: - Factory Methods

enum TestFactory {
    
    static func makePerfume(
        id: UUID = UUID(),
        name: String = "Test Parfum",
        concentration: String? = "EDP",
        longevity: String = "Lang",
        sillage: String = "Mittel",
        performance: Double = 4.0,
        desc: String? = "Ein Testparfum",
        occasions: [String] = [],
        imageUrl: URL? = nil
    ) -> Perfume {
        Perfume(
            id: id,
            name: name,
            concentration: concentration,
            longevity: longevity,
            sillage: sillage,
            performance: performance,
            desc: desc,
            occasions: occasions,
            imageUrl: imageUrl
        )
    }
    
    static func makeReview(
        id: UUID = UUID(),
        title: String = "Toller Duft",
        text: String = "Wirklich angenehm und langanhaltend.",
        rating: Int = 4,
        longevity: Int? = 3,
        sillage: Int? = 4,
        createdAt: Date = Date(),
        authorName: String? = "TestUser",
        userId: UUID? = nil
    ) -> Review {
        Review(
            id: id,
            title: title,
            text: text,
            rating: rating,
            longevity: longevity,
            sillage: sillage,
            createdAt: createdAt,
            authorName: authorName,
            userId: userId
        )
    }
    
    static func makeBrand(
        name: String = "TestBrand",
        country: String? = "Germany"
    ) -> Brand {
        Brand(name: name, country: country)
    }
    
    static func makeRatingStats(
        perfumeId: UUID = UUID(),
        avgRating: Double = 4.2,
        reviewCount: Int = 10
    ) -> RatingStats {
        RatingStats(
            perfumeId: perfumeId,
            avgRating: avgRating,
            reviewCount: reviewCount
        )
    }
    
    /// Creates an in-memory SwiftData ModelContainer for testing.
    @MainActor
    static func makeModelContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Perfume.self, Brand.self, Note.self, Review.self, UserPersonalData.self,
            configurations: config
        )
    }
}
