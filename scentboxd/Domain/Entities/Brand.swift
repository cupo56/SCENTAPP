//
//  Brand.swift
//  scentboxd
//
//  Created by Cupo on 09.01.26.
//

import SwiftData

@Model
class Brand {
    @Attribute(.unique) var name: String
    var country: String?
    
    // Relationship: Wenn eine Marke gelöscht wird, was passiert mit den Parfums?
    // Hier .nullify -> Parfums bleiben, haben aber keine Marke mehr.
    // Oder .cascade -> Parfums werden auch gelöscht.
    @Relationship(deleteRule: .nullify, inverse: \Perfume.brand)
    var perfumes: [Perfume]? = []
    
    init(name: String, country: String? = nil) {
        self.name = name
        self.country = country
    }
}
