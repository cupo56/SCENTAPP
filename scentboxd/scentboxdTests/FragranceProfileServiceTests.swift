//
//  FragranceProfileServiceTests.swift
//  scentboxdTests
//

import XCTest
@testable import scentboxd

@MainActor
final class FragranceProfileServiceTests: XCTestCase {

    // FragranceProfileService hängt direkt von Supabase + AuthSessionCache ab,
    // daher testen wir hier den Initialzustand und die State-Logik.
    // Für volle Integration braucht man einen Supabase-Mock (zukünftig extrahierbar).

    private var sut: FragranceProfileService!

    override func setUp() {
        sut = FragranceProfileService()
    }

    override func tearDown() {
        sut = nil
    }

    // MARK: - Initialzustand

    func testInitialState() {
        XCTAssertNil(sut.profile)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.showErrorAlert)
    }

    // MARK: - loadProfile ohne Auth → Fehler

    func testLoadProfileWithoutAuthSetsError() async {
        // WHEN: Kein User eingeloggt → AuthSessionCache wirft Fehler
        await sut.loadProfile()

        // THEN
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.profile)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertTrue(sut.showErrorAlert)
    }
}
