//
//  NetworkError.swift
//  scentboxd
//

import Foundation

enum NetworkError: LocalizedError {
    case noConnection
    case timeout
    case serverError(statusCode: Int)
    case unknown(underlying: Error)
    
    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "Keine Internetverbindung. Bitte überprüfe deine Netzwerkeinstellungen."
        case .timeout:
            return "Die Anfrage hat zu lange gedauert. Bitte versuche es erneut."
        case .serverError(let statusCode):
            return "Serverfehler (\(statusCode)). Bitte versuche es später erneut."
        case .unknown:
            return "Ein unbekannter Fehler ist aufgetreten. Bitte versuche es erneut."
        }
    }
    
    /// Bestimmt, ob ein erneuter Versuch sinnvoll ist
    var isTransient: Bool {
        switch self {
        case .timeout, .serverError:
            return true
        case .noConnection, .unknown:
            return false
        }
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
        if let statusCode = nsError.userInfo["statusCode"] as? Int, statusCode >= 500 {
            return .serverError(statusCode: statusCode)
        }
        
        return .unknown(underlying: error)
    }
}
