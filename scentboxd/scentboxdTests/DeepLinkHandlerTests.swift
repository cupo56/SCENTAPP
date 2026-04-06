import XCTest
@testable import scentboxd

@MainActor
final class DeepLinkHandlerTests: XCTestCase {
    func testParsePerfumeLink() {
        let handler = DeepLinkHandler()
        let perfumeId = UUID()

        let route = handler.parse(url: URL(string: "scentboxd://perfume/\(perfumeId.uuidString)")!)

        XCTAssertEqual(route, .perfume(perfumeId))
    }

    func testParseTabLink() {
        let handler = DeepLinkHandler()

        let route = handler.parse(url: URL(string: "scentboxd://favorites")!)

        XCTAssertEqual(route, .tab(.favorites))
    }

    func testInvalidLinkIgnored() {
        let handler = DeepLinkHandler()

        let route = handler.parse(url: URL(string: "scentboxd://perfume/not-a-uuid")!)

        XCTAssertNil(route)
    }

    func testCompareLinkMultipleIds() {
        let handler = DeepLinkHandler()
        let firstId = UUID()
        let secondId = UUID()

        let route = handler.parse(
            url: URL(
                string: "scentboxd://compare?ids=\(firstId.uuidString),\(secondId.uuidString)"
            )!
        )

        XCTAssertEqual(route, .compare([firstId, secondId]))
    }
}
