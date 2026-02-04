//
//  UserPerfumeStatus.swift
//  scentboxd
//
//  Created by Cupo on 09.01.26.
//

import Foundation

enum UserPerfumeStatus: String, Codable, CaseIterable {
    case none = "Kein Status"
    case wishlist = "Wunschliste"
    case owned = "Sammlung"
    case empty = "Leer / Aufgebraucht"
}
