//
//  NetworkErrorTests.swift
//  scentboxdTests
//

import XCTest
@testable import scentboxd

final class NetworkErrorTests: XCTestCase {
    
    // MARK: - NetworkError.from(_:)
    
    func testFromNetworkErrorPassesThrough() {
        let original = NetworkError.timeout
        let result = NetworkError.from(original)
        
        if case .timeout = result {
            // OK
        } else {
            XCTFail("Sollte .timeout zurückgeben, bekam: \(result)")
        }
    }
    
    func testFromURLErrorNoConnection() {
        let urlError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: nil
        )
        let result = NetworkError.from(urlError)
        
        if case .noConnection = result {
            // OK
        } else {
            XCTFail("Sollte .noConnection sein, bekam: \(result)")
        }
    }
    
    func testFromURLErrorNetworkConnectionLost() {
        let urlError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNetworkConnectionLost,
            userInfo: nil
        )
        let result = NetworkError.from(urlError)
        
        if case .noConnection = result {
            // OK
        } else {
            XCTFail("Sollte .noConnection sein, bekam: \(result)")
        }
    }
    
    func testFromURLErrorTimeout() {
        let urlError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorTimedOut,
            userInfo: nil
        )
        let result = NetworkError.from(urlError)
        
        if case .timeout = result {
            // OK
        } else {
            XCTFail("Sollte .timeout sein, bekam: \(result)")
        }
    }
    
    func testFromHTTPServerError() {
        let error = NSError(
            domain: "HTTP",
            code: 0,
            userInfo: ["statusCode": 503]
        )
        let result = NetworkError.from(error)
        
        if case .serverError(let code) = result {
            XCTAssertEqual(code, 503)
        } else {
            XCTFail("Sollte .serverError(503) sein, bekam: \(result)")
        }
    }
    
    func testFromHTTPClientError() {
        let error = NSError(
            domain: "HTTP",
            code: 0,
            userInfo: ["statusCode": 403]
        )
        let result = NetworkError.from(error)
        
        if case .clientError(let code) = result {
            XCTAssertEqual(code, 403)
        } else {
            XCTFail("Sollte .clientError(403) sein, bekam: \(result)")
        }
    }
    
    func testFromUnknownError() {
        let error = NSError(domain: "Custom", code: 42, userInfo: nil)
        let result = NetworkError.from(error)
        
        if case .unknown = result {
            // OK
        } else {
            XCTFail("Sollte .unknown sein, bekam: \(result)")
        }
    }
    
    // MARK: - isTransient
    
    func testTimeoutIsTransient() {
        XCTAssertTrue(NetworkError.timeout.isTransient, "Timeout sollte transient sein.")
    }
    
    func testServerError500IsTransient() {
        XCTAssertTrue(
            NetworkError.serverError(statusCode: 500).isTransient,
            "500 sollte transient sein."
        )
    }
    
    func testServerError501IsNotTransient() {
        XCTAssertFalse(
            NetworkError.serverError(statusCode: 501).isTransient,
            "501 sollte NICHT transient sein."
        )
    }
    
    func testNoConnectionIsNotTransient() {
        XCTAssertFalse(
            NetworkError.noConnection.isTransient,
            "noConnection sollte nicht transient sein."
        )
    }
    
    func testClientErrorIsNotTransient() {
        XCTAssertFalse(
            NetworkError.clientError(statusCode: 404).isTransient,
            "clientError sollte nicht transient sein."
        )
    }
    
    func testUnknownIsNotTransient() {
        let error = NetworkError.unknown(underlying: NSError(domain: "", code: 0))
        XCTAssertFalse(error.isTransient, "unknown sollte nicht transient sein.")
    }
    
    // MARK: - errorDescription
    
    func testErrorDescriptionsNotNil() {
        let cases: [NetworkError] = [
            .noConnection,
            .timeout,
            .serverError(statusCode: 500),
            .clientError(statusCode: 401),
            .notSupported(reason: "Test"),
            .unknown(underlying: NSError(domain: "", code: 0))
        ]
        
        for error in cases {
            XCTAssertNotNil(error.errorDescription, "errorDescription für \(error) sollte nicht nil sein.")
        }
    }
}
