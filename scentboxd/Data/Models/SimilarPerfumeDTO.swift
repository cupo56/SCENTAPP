import Foundation

struct SimilarPerfumeDTO: Codable {
    let perfumeId: UUID
    let similarityScore: Double

    enum CodingKeys: String, CodingKey {
        case perfumeId = "perfume_id"
        case similarityScore = "similarity_score"
    }
}
