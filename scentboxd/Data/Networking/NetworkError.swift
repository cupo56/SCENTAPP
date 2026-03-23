//
//  NetworkError.swift
//  scentboxd
//

import Foundation
import os

enum NetworkError: LocalizedError {
    case noConnection
    case timeout
    case serverError(statusCode: Int)
    case clientError(statusCode: Int)
    case notSupported(reason: String)
    case validationFailed(String)
    case unknown(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .noConnection:
            return String(localized: "Keine Internetverbindung. Bitte überprüfe deine Netzwerkeinstellungen.")
        case .timeout:
            return String(localized: "Die Anfrage hat zu lange gedauert. Bitte versuche es erneut.")
        case .serverError(let statusCode):
            return String(localized: "Serverfehler (\(statusCode)). Bitte versuche es später erneut.")
        case .clientError(let statusCode):
            return String(localized: "Anfragefehler (\(statusCode)). Bitte prüfe deine Anmeldung.")
        case .notSupported(let reason):
            return reason
        case .validationFailed(let reason):
            return reason
        case .unknown:
            return String(localized: "Ein unbekannter Fehler ist aufgetreten. Bitte versuche es erneut.")
        }
    }

    /// Bestimmt, ob ein erneuter Versuch sinnvoll ist
    var isTransient: Bool {
        switch self {
        case .timeout:
            return true
        case .serverError(let statusCode):
            // Nur echte Server-Fehler (5xx) sind transient, nicht 501 Not Implemented
            return statusCode != 501
        case .noConnection, .clientError, .unknown, .notSupported, .validationFailed:
            return false
        }
    }

    /// Wandelt einen Error in NetworkError um, loggt ihn und gibt die User-Message zurück.
    @discardableResult
    static func handle(_ error: Error, logger: Logger, context: String) -> String {
        let networkError = Self.from(error)
        logger.error("\(context): \(networkError.localizedDescription)")
        return networkError.localizedDescription
    }

    /// Wandelt einen beliebigen Error in einen NetworkError um
    static func from(_ error: Error) -> NetworkError {
        if let networkError = error as? NetworkError {
            return networkError
        }

        let nsError = error as NSError

        // URLError-Codes prüfen
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorDataNotAllowed:
                return .noConnection
            case NSURLErrorTimedOut:
                return .timeout
            default:
                break
            }
        }

        // HTTP-Statusfehler (z.B. von Supabase)
        if let statusCode = nsError.userInfo["statusCode"] as? Int {
            if statusCode >= 500 {
                return .serverError(statusCode: statusCode)
            } else if statusCode >= 400 {
                return .clientError(statusCode: statusCode)
            }
        }

        return .unknown(underlying: error)
    }
}
