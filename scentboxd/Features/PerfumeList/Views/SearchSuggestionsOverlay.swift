import SwiftUI

struct SearchSuggestionsOverlay: View {
    let suggestions: [SearchSuggestionDTO]
    let isLoading: Bool
    let onBrandTap: (String) -> Void
    let onNoteTap: (String) -> Void
    let onPerfumeTap: (UUID) -> Void

    var body: some View {
        if isLoading {
            Label("Suche Vorschläge...", systemImage: "magnifyingglass")
        } else {
            ForEach(SearchSuggestionKind.allCases, id: \.rawValue) { kind in
                let groupedSuggestions = suggestions.filter { $0.kind == kind }

                if !groupedSuggestions.isEmpty {
                    Section(kind.title) {
                        ForEach(groupedSuggestions) { suggestion in
                            suggestionRow(for: suggestion, kind: kind)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func suggestionRow(for suggestion: SearchSuggestionDTO, kind: SearchSuggestionKind) -> some View {
        switch kind {
        case .brand:
            Button {
                onBrandTap(suggestion.suggestionText)
            } label: {
                suggestionLabel(for: suggestion, kind: kind)
            }

        case .note:
            Button {
                onNoteTap(suggestion.suggestionText)
            } label: {
                suggestionLabel(for: suggestion, kind: kind)
            }

        case .perfume:
            if let suggestionId = suggestion.suggestionId {
                Button {
                    onPerfumeTap(suggestionId)
                } label: {
                    suggestionLabel(for: suggestion, kind: kind)
                }
            }
        }
    }

    private func suggestionLabel(for suggestion: SearchSuggestionDTO, kind: SearchSuggestionKind) -> some View {
        Label(suggestion.suggestionText, systemImage: kind.iconName)
    }
}
