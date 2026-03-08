//
//  NetworkRetryTests.swift
//  scentboxdTests
//

import XCTest
@testable import scentboxd

final class NetworkRetryTests: XCTestCase {
    
    // MARK: - Success Cases
    
    func testSucceedsOnFirstAttempt() async throws {
        // GIVEN / WHEN
        let result = try await withRetry(maxAttempts: 3, initialDelay: 0.01) {
            return "Erfolg"
        }
        
        // THEN
        XCTAssertEqual(result, "Erfolg")
    }
    
    func testRetriesAndEventuallySucceeds() async throws {
        // GIVEN
        var attemptCount = 0
        
        // WHEN: Fails twice with transient error, succeeds on 3rd attempt
        let result: String = try await withRetry(maxAttempts: 3, initialDelay: 0.01) {
            attemptCount += 1
            if attemptCount < 3 {
                throw NetworkError.timeout
            }
            return "Erfolg nach Retry"
        }
        
        // THEN
        XCTAssertEqual(result, "Erfolg nach Retry")
        XCTAssertEqual(attemptCount, 3, "Sollte 3 Versuche gebraucht haben.")
    }
    
    // MARK: - Failure Cases
    
    func testThrowsAfterMaxAttempts() async {
        // GIVEN
        var attemptCount = 0
        
        // WHEN / THEN
        do {
            let _: String = try await withRetry(maxAttempts: 2, initialDelay: 0.01) {
                attemptCount += 1
                throw NetworkError.timeout
            }
            XCTFail("Sollte einen Fehler werfen.")
        } catch {
            XCTAssertEqual(attemptCount, 2, "Sollte genau 2 Versuche gemacht haben.")
            XCTAssertTrue(error is NetworkError, "Sollte ein NetworkError sein.")
        }
    }
    
    func testDoesNotRetryNonTransientError() async {
        // GIVEN
        var attemptCount = 0
        
        // WHEN / THEN: Client errors are non-transient
        do {
            let _: String = try await withRetry(maxAttempts: 3, initialDelay: 0.01) {
                attemptCount += 1
                throw NetworkError.clientError(statusCode: 401)
            }
            XCTFail("Sollte einen Fehler werfen.")
        } catch {
            XCTAssertEqual(attemptCount, 1, "Sollte nach dem ersten Versuch aufhören (nicht-transient).")
        }
    }
    
    func testCancellationNotRetried() async {
        // GIVEN
        var attemptCount = 0
        
        // WHEN / THEN
        do {
            let _: String = try await withRetry(maxAttempts: 3, initialDelay: 0.01) {
                attemptCount += 1
                throw CancellationError()
            }
            XCTFail("Sollte CancellationError werfen.")
        } catch is CancellationError {
            XCTAssertEqual(attemptCount, 1, "CancellationError sollte sofort weitergegeben werden.")
        } catch {
            XCTFail("Falscher Fehlertyp: \(error)")
        }
    }
    
    func testServerError501NotRetried() async {
        // GIVEN: 501 is non-transient despite being a server error
        var attemptCount = 0
        
        // WHEN / THEN
        do {
            let _: String = try await withRetry(maxAttempts: 3, initialDelay: 0.01) {
                attemptCount += 1
                throw NetworkError.serverError(statusCode: 501)
            }
            XCTFail("Sollte einen Fehler werfen.")
        } catch {
            XCTAssertEqual(attemptCount, 1, "501 ist nicht transient, kein Retry erwartet.")
        }
    }
}
