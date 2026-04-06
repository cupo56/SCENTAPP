//
//  ReviewSyncAction.swift
//  scentboxd
//

import Foundation

/// Art der ausstehenden Review-Aenderung fuer die Offline-Synchronisierung.
enum ReviewSyncAction: Int, Codable {
    case save = 1
    case update = 2
    case delete = 3
}
