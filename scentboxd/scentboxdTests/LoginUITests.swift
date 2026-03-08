//
//  LoginUITests.swift
//  scentboxdTests
//
//  Skeleton UI test for Login flow.
//  This is a placeholder — move to scentboxdUITests target and
//  uncomment XCUIApplication code when ready to run actual UI tests.
//

import XCTest

final class LoginUITests: XCTestCase {
    
    func testLoginFlow() throws {
        // UI tests require the XCUITest runner (scentboxdUITests target)
        // and valid test credentials (UI_TEST_EMAIL, UI_TEST_PASSWORD).
        //
        // To enable:
        // 1. Move this file to scentboxdUITests target
        // 2. Set UI_TEST_EMAIL and UI_TEST_PASSWORD env vars in scheme
        // 3. Uncomment the XCUIApplication code below
        //
        // Steps:
        // - Launch app
        // - Tap login button (accessibilityIdentifier: "loginButton")
        // - Enter email into "emailField"
        // - Enter password into "passwordField"
        // - Tap "submitLoginButton"
        // - Verify "Profil" tab appears
        //
        try XCTSkipIf(true, "UI-Test: Bitte im scentboxdUITests-Target ausführen.")
    }
}
