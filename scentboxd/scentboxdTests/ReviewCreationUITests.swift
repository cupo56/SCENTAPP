//
//  ReviewCreationUITests.swift
//  scentboxdTests
//
//  Skeleton UI test for creating a review.
//  This is a placeholder — move to scentboxdUITests target and
//  uncomment XCUIApplication code when ready to run actual UI tests.
//

import XCTest

final class ReviewCreationUITests: XCTestCase {

    func testCreateReviewFlow() throws {
        // UI tests require the XCUITest runner (scentboxdUITests target)
        // and a logged-in test account.
        //
        // To enable:
        // 1. Move this file to scentboxdUITests target
        // 2. Set UI_TEST_EMAIL and UI_TEST_PASSWORD env vars in scheme
        // 3. Uncomment the XCUIApplication code below
        //
        // Steps:
        // - Launch app
        // - Tap first perfume in list
        // - Tap review button ("reviewButton")
        // - Fill reviewTitleField, reviewTextField
        // - Tap ratingStar4
        // - Tap submitReviewButton
        // - Verify "UI Test Review" appears
        //
        try XCTSkipIf(true, "UI-Test: Bitte im scentboxdUITests-Target ausführen.")
    }
}
