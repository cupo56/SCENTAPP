import XCTest
@testable import scentboxd

@MainActor
final class SearchSuggestionServiceTests: XCTestCase {
    private var mockRepo: MockPerfumeRepository!
    private var sut: SearchSuggestionService!

    override func setUp() {
        super.setUp()
        mockRepo = MockPerfumeRepository()
        sut = SearchSuggestionService(repository: mockRepo)
    }

    override func tearDown() {
        sut = nil
        mockRepo = nil
        super.tearDown()
    }

    func testFetchSuggestionsReturnsMixed() async {
        mockRepo.searchSuggestionsToReturn = [
            SearchSuggestionDTO(suggestionType: "brand", suggestionText: "Dior", suggestionId: nil),
            SearchSuggestionDTO(suggestionType: "note", suggestionText: "Vanille", suggestionId: nil),
            SearchSuggestionDTO(suggestionType: "perfume", suggestionText: "Sauvage", suggestionId: UUID())
        ]

        sut.fetchSuggestions(for: "di")
        try? await Task.sleep(for: .milliseconds(300))

        XCTAssertEqual(sut.suggestions, mockRepo.searchSuggestionsToReturn)
        XCTAssertEqual(mockRepo.fetchSearchSuggestionsCalled, 1)
    }

    func testFetchSuggestionsDebounces() async {
        sut.fetchSuggestions(for: "d")
        sut.fetchSuggestions(for: "di")
        sut.fetchSuggestions(for: "dio")
        try? await Task.sleep(for: .milliseconds(300))

        XCTAssertEqual(mockRepo.fetchSearchSuggestionsCalled, 1)
        XCTAssertEqual(mockRepo.lastSuggestionQuery, "dio")
    }

    func testClearCancelsTask() async {
        sut.fetchSuggestions(for: "dio")
        sut.clear()
        try? await Task.sleep(for: .milliseconds(300))

        XCTAssertTrue(sut.suggestions.isEmpty)
        XCTAssertEqual(mockRepo.fetchSearchSuggestionsCalled, 0)
        XCTAssertFalse(sut.isLoading)
    }

    func testEmptyQueryNoRequest() async {
        sut.fetchSuggestions(for: "")
        try? await Task.sleep(for: .milliseconds(250))

        XCTAssertEqual(mockRepo.fetchSearchSuggestionsCalled, 0)
        XCTAssertTrue(sut.suggestions.isEmpty)
        XCTAssertFalse(sut.isLoading)
    }
}
