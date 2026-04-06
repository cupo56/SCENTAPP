import Foundation
import Observation
import os

@Observable
@MainActor
final class SearchSuggestionService {
    var suggestions: [SearchSuggestionDTO] = []
    var isLoading = false

    private let repository: PerfumeRepository
    private var searchTask: Task<Void, Never>?

    init(repository: PerfumeRepository) {
        self.repository = repository
    }

    func fetchSuggestions(for query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedQuery.count >= 2 else {
            clear()
            return
        }

        searchTask?.cancel()
        isLoading = true

        searchTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(AppConfig.Timing.searchSuggestionsDebounceMs))
                guard !Task.isCancelled else { return }

                let fetchedSuggestions = try await repository.fetchSearchSuggestions(query: trimmedQuery)
                guard !Task.isCancelled else { return }

                suggestions = fetchedSuggestions
            } catch is CancellationError {
                return
            } catch {
                AppLogger.perfumes.error("Suchvorschlaege laden fehlgeschlagen: \(error.localizedDescription)")
                suggestions = []
            }

            isLoading = false
        }
    }

    func clear() {
        searchTask?.cancel()
        searchTask = nil
        suggestions = []
        isLoading = false
    }
}
