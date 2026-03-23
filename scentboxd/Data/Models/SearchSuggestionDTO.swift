import Foundation

struct SearchSuggestionDTO: Codable, Identifiable, Equatable {
    let suggestionType: String
    let suggestionText: String
    let suggestionId: UUID?

    var id: String { "\(suggestionType)_\(suggestionText)" }

    var kind: SearchSuggestionKind? {
        SearchSuggestionKind(rawValue: suggestionType)
    }

    enum CodingKeys: String, CodingKey {
        case suggestionType = "suggestion_type"
        case suggestionText = "suggestion_text"
        case suggestionId = "suggestion_id"
    }
}

enum SearchSuggestionKind: String, CaseIterable {
    case brand
    case note
    case perfume

    var title: String {
        switch self {
        case .brand:
            return "Marken"
        case .note:
            return "Noten"
        case .perfume:
            return "Düfte"
        }
    }

    var iconName: String {
        switch self {
        case .brand:
            return "tag.fill"
        case .note:
            return "leaf.fill"
        case .perfume:
            return "drop.fill"
        }
    }
}
