//
//  FragranceProfileDTOTests.swift
//  scentboxdTests
//

import XCTest
@testable import scentboxd

final class FragranceProfileDTOTests: XCTestCase {

    // MARK: - totalReviewCount

    func testTotalReviewCountSumsDistribution() {
        let profile = makeProfile(ratingDistribution: [
            .init(rating: 1, count: 2),
            .init(rating: 3, count: 5),
            .init(rating: 5, count: 8)
        ])
        XCTAssertEqual(profile.totalReviewCount, 15)
    }

    func testTotalReviewCountEmptyDistribution() {
        let profile = makeProfile(ratingDistribution: [])
        XCTAssertEqual(profile.totalReviewCount, 0)
    }

    // MARK: - totalCollectionCount

    func testTotalCollectionCountSumsConcentrations() {
        let profile = makeProfile(concentrations: [
            .init(type: "EDP", count: 3),
            .init(type: "EDT", count: 7)
        ])
        XCTAssertEqual(profile.totalCollectionCount, 10)
    }

    func testTotalCollectionCountEmpty() {
        let profile = makeProfile(concentrations: [])
        XCTAssertEqual(profile.totalCollectionCount, 0)
    }

    // MARK: - isEmpty

    func testIsEmptyWhenAllEmpty() {
        let profile = makeProfile()
        XCTAssertTrue(profile.isEmpty)
    }

    func testIsNotEmptyWithNotes() {
        let profile = makeProfile(topNotes: [.init(name: "Rose", count: 3)])
        XCTAssertFalse(profile.isEmpty)
    }

    func testIsNotEmptyWithConcentrations() {
        let profile = makeProfile(concentrations: [.init(type: "EDP", count: 1)])
        XCTAssertFalse(profile.isEmpty)
    }

    func testIsNotEmptyWithRatings() {
        let profile = makeProfile(ratingDistribution: [.init(rating: 5, count: 1)])
        XCTAssertFalse(profile.isEmpty)
    }

    // MARK: - JSON Decoding

    func testDecodingFromJSON() throws {
        let json = """
        {
            "top_notes": [{"name": "Vanille", "count": 5}],
            "concentrations": [{"type": "EDP", "count": 3}],
            "avg_rating": 4.2,
            "rating_distribution": [{"rating": 5, "count": 10}]
        }
        """.data(using: .utf8)!

        let profile = try JSONDecoder().decode(FragranceProfileDTO.self, from: json)
        XCTAssertEqual(profile.topNotes.count, 1)
        XCTAssertEqual(profile.topNotes.first?.name, "Vanille")
        XCTAssertEqual(profile.avgRating, 4.2)
        XCTAssertEqual(profile.concentrations.first?.type, "EDP")
        XCTAssertEqual(profile.ratingDistribution.first?.count, 10)
    }

    // MARK: - UserPerfumeDTO Decoding

    func testUserPerfumeDTODecoding() throws {
        let json = """
        {
            "user_id": "11111111-1111-1111-1111-111111111111",
            "perfume_id": "22222222-2222-2222-2222-222222222222",
            "is_favorite": true,
            "is_owned": false,
            "is_empty": false,
            "created_at": null
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(UserPerfumeDTO.self, from: json)
        XCTAssertTrue(dto.isFavorite)
        XCTAssertFalse(dto.isOwned)
        XCTAssertFalse(dto.isWantToTry)
        XCTAssertEqual(dto.perfumeId, UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
    }

    // MARK: - PerfumeDTO Decoding

    func testPerfumeDTODecodingWithNotes() throws {
        let json = """
        {
            "id": "33333333-3333-3333-3333-333333333333",
            "name": "Sauvage",
            "concentration": "EDP",
            "longevity": "Lang",
            "sillage": "Stark",
            "performance": 4.5,
            "desc": "Ein kräftiger Duft",
            "image_url": null,
            "occasions": ["Abend"],
            "brands": {"id": "44444444-4444-4444-4444-444444444444", "name": "Dior", "country": "France"},
            "perfume_notes": [
                {"note_type": "top", "notes": {"name": "Bergamotte", "category": "Zitrus"}}
            ]
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(PerfumeDTO.self, from: json)
        XCTAssertEqual(dto.name, "Sauvage")
        XCTAssertEqual(dto.brand?.name, "Dior")
        XCTAssertEqual(dto.perfumeNotes?.count, 1)
        XCTAssertEqual(dto.perfumeNotes?.first?.noteType, "top")
        XCTAssertEqual(dto.perfumeNotes?.first?.note?.name, "Bergamotte")
    }

    // MARK: - SimilarPerfumeDTO Decoding

    func testSimilarPerfumeDTODecoding() throws {
        let json = """
        {
            "perfume_id": "55555555-5555-5555-5555-555555555555",
            "similarity_score": 0.87
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(SimilarPerfumeDTO.self, from: json)
        XCTAssertEqual(dto.perfumeId, UUID(uuidString: "55555555-5555-5555-5555-555555555555"))
        XCTAssertEqual(dto.similarityScore, 0.87)
    }

    // MARK: - Helpers

    private func makeProfile(
        topNotes: [FragranceProfileDTO.NoteCount] = [],
        concentrations: [FragranceProfileDTO.ConcentrationCount] = [],
        avgRating: Double = 0,
        ratingDistribution: [FragranceProfileDTO.RatingBucket] = []
    ) -> FragranceProfileDTO {
        FragranceProfileDTO(
            topNotes: topNotes,
            concentrations: concentrations,
            avgRating: avgRating,
            ratingDistribution: ratingDistribution
        )
    }
}
