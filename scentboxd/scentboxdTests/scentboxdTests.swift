//
//  scentboxdTests.swift
//  scentboxdTests
//
//  Created by Cupo on 09.01.26.
//

import XCTest
import SwiftData
@testable import scentboxd

// Wir nutzen MainActor, da SwiftData eng mit dem UI-Thread verknüpft ist
@MainActor
final class PerfumeModelTests: XCTestCase {

    var container: ModelContainer!

    override func setUpWithError() throws {
        // 1. Wir erstellen eine Datenbank, die nur im Arbeitsspeicher lebt (RAM).
        // So wird nichts auf die Festplatte geschrieben und jeder Test ist frisch.
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        
        container = try ModelContainer(for: Perfume.self, Brand.self, Note.self, configurations: config)
    }

    override func tearDownWithError() throws {
        container = nil
    }

    func testSavingPerfumeWithRelationships() throws {
        // GIVEN: Wir erstellen die Test-Daten (Context ist der "Arbeitsbereich" der Datenbank)
        let context = container.mainContext
        
        let chanel = Brand(name: "Chanel", country: "France")
        let citrusNote = Note(name: "Bergamotte")
        
        let perfume = Perfume(
            name: "Bleu de Chanel",
            longevity: "Lang",
            sillage: "Mittel",
            performance: 4.5
        )
        
        // Beziehungen setzen
        perfume.brand = chanel
        perfume.topNotes = [citrusNote]
        
        // WHEN: Wir speichern die Daten in den Context
        context.insert(perfume)
        // (Marke und Note werden automatisch mitgespeichert, weil sie verknüpft sind)
        
        // THEN: Wir versuchen, die Daten wieder abzurufen, um zu prüfen ob es geklappt hat
        let fetchDescriptor = FetchDescriptor<Perfume>()
        let savedPerfumes = try context.fetch(fetchDescriptor)
        
        // Prüfungen (Assertions)
        XCTAssertEqual(savedPerfumes.count, 1, "Es sollte genau ein Parfum in der DB sein.")
        XCTAssertEqual(savedPerfumes.first?.name, "Bleu de Chanel")
        XCTAssertEqual(savedPerfumes.first?.brand?.name, "Chanel", "Die Marke sollte korrekt verknüpft sein.")
        XCTAssertEqual(savedPerfumes.first?.topNotes.first?.name, "Bergamotte", "Die Note sollte verknüpft sein.")
    }
}
