# Scentboxd — Feature-Roadmap & Detaillierte Todos

> Zuletzt aktualisiert: 23.03.2026 | Basierend auf Codebase-Analyse
> Priorisierung: Phase 0 (Bugfixes) → Phase 1 (Quick Wins) → Phase 2 (Mittelfristig) → Phase 3 (Langfristig)

---

## PHASE 0 — Bugfixes & Technische Schulden (VOR neuen Features)

## PHASE 1 — Quick Wins (1-2 Tage pro Feature)

## PHASE 2 — Mittelfristige Features (3-7 Tage pro Feature)

### 2.3 Barcode-Scanner
**Priorität:** Mittel | **Aufwand:** 3-4 Tage | **User-Value:** Hoch

**Warum:** Schnellster Weg ein Parfum zu finden — im Laden einfach scannen.

#### Backend
- [ ] `perfumes`-Tabelle erweitern:
  - [ ] `ean TEXT` (EAN-13 Barcode)
  - [ ] Index: `CREATE INDEX idx_perfumes_ean ON perfumes(ean)`
- [ ] EAN-Daten beschaffen (manuell oder via Open Beauty Facts API)
- [ ] Supabase Endpunkt: `GET /perfumes?ean=eq.{barcode}`

#### Data Layer
- [ ] `PerfumeRepository` erweitern:
  - [ ] `func fetchPerfumeByBarcode(ean: String) async throws -> Perfume?`
- [ ] `PerfumeRemoteDataSource.swift`:
  - [ ] Implementierung mit Supabase `.eq("ean", ean)`

#### Feature Layer
- [ ] `Features/Scanner/` Ordner erstellen
- [ ] `Features/Scanner/Views/BarcodeScannerView.swift`:
  ```swift
  struct BarcodeScannerView: View {
      @State private var scannedCode: String?
      @State private var isScanning = true
      @State private var foundPerfume: Perfume?
      @State private var isSearching = false
      @State private var errorMessage: String?

      var body: some View {
          ZStack {
              // Camera Preview (DataScannerViewController Wrapper)
              DataScannerRepresentable(
                  recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce])],
                  onScan: { barcode in
                      scannedCode = barcode
                      await searchPerfume(barcode)
                  }
              )

              // Overlay: Scan-Rahmen
              ScannerOverlayView()

              // Ergebnis-Sheet
              if let perfume = foundPerfume {
                  PerfumeQuickPreviewSheet(perfume: perfume)
              }

              // "Nicht gefunden" State
              if let error = errorMessage {
                  NotFoundOverlay(message: error)
              }
          }
      }
  }
  ```
- [ ] `Features/Scanner/Views/DataScannerRepresentable.swift`:
  - [ ] UIViewControllerRepresentable Wrapper für `DataScannerViewController` (iOS 16+)
  - [ ] Kamera-Permission handling
  - [ ] Scan-Feedback: Haptic + Sound
- [ ] `Features/Scanner/Views/ScannerOverlayView.swift`:
  - [ ] Animierter Scan-Rahmen (gestrichelte Linie)
  - [ ] Hinweistext: "Halte den Barcode in den Rahmen"
  - [ ] Taschenlampen-Toggle Button
- [ ] `Features/Scanner/Views/PerfumeQuickPreviewSheet.swift`:
  - [ ] Mini-Card mit Bild, Name, Brand
  - [ ] "Details ansehen" Button → Navigation zu Detail
  - [ ] "Zur Sammlung hinzufügen" Quick-Action
  - [ ] "Erneut scannen" Button

#### Navigation
- [ ] `PerfumeListView.swift`:
  - [ ] Scanner-Button in Toolbar (barcode.viewfinder Icon)
  - [ ] Sheet öffnen mit `BarcodeScannerView`
- [ ] Kamera-Permission in Info.plist:
  ```xml
  <key>NSCameraUsageDescription</key>
  <string>Scanne Parfum-Barcodes um sie schnell zu finden</string>
  ```

#### Fallback für nicht-gefundene Barcodes
- [ ] "Parfum nicht gefunden" Overlay:
  - [ ] "Möchtest du diesen Barcode melden?" → Feedback an Backend senden
  - [ ] Manuelle Suche vorschlagen

#### Tests
- [ ] `BarcodeLookupTests.swift`:
  - [ ] `testValidEAN_findsPerfume`
  - [ ] `testInvalidEAN_returnsNil`
  - [ ] `testOffline_showsError`

---

## PHASE 3 — Langfristige Features (1-3 Wochen pro Feature)

### 3.1 Parfum-Empfehlungen (ML-basiert)
**Priorität:** Hoch (Langfristig) | **Aufwand:** 2-3 Wochen | **User-Value:** Sehr Hoch

**Warum:** DAS Killer-Feature. Personalisierte Empfehlungen basierend auf Geschmack.

#### Strategie: Content-Based Filtering (Phase 1) + Collaborative Filtering (Phase 2)

##### Phase 1: Content-Based (Noten-Ähnlichkeit)
- [ ] **Algorithmus lokal auf dem Gerät (CoreML oder rein Swift)**:
  ```
  Für jedes Parfum: Feature-Vektor aus Noten erstellen
  → One-Hot-Encoding aller Notes
  → User-Profil = Mittelwert aller owned/favoriten Vektoren
  → Cosine Similarity zwischen User-Profil und allen Parfums
  → Top-N zurückgeben (die nicht schon owned/favorisiert sind)
  ```
- [ ] `Features/Recommendations/Services/RecommendationEngine.swift`:
  ```swift
  @Observable @MainActor
  class RecommendationEngine {
      var recommendations: [RecommendedPerfume] = []
      var isCalculating = false

      struct RecommendedPerfume: Identifiable {
          let perfume: Perfume
          let score: Double
          let reason: String  // "Basierend auf deiner Vorliebe für Oud-Noten"
      }

      func calculateRecommendations(
          ownedPerfumes: [Perfume],
          favoritePerfumes: [Perfume],
          allPerfumes: [Perfume]
      ) async { ... }
  }
  ```
- [ ] `Features/Recommendations/Views/RecommendationsView.swift`:
  - [ ] "Für dich empfohlen" Header
  - [ ] Horizontal-Scroll Cards mit Begründung ("Weil du X magst")
  - [ ] "Nicht interessiert" Swipe-Action (verbessert Algorithmus)
  - [ ] Pull-to-Refresh: Empfehlungen neu berechnen
- [ ] In `PerfumeDetailView.swift` einbinden:
  - [ ] Unter "Ähnliche Düfte": "Weil du [Grund]"

##### Phase 2: Collaborative Filtering (Server-Side)
- [ ] Supabase Edge Function: Matrix Factorization auf User-Ratings
- [ ] "User die X mögen, mögen auch Y" Logik
- [ ] A/B Test: Content-Based vs Collaborative vs Hybrid

#### Tests
- [ ] `RecommendationEngineTests.swift`:
  - [ ] `testEmptyCollection_noRecommendations`
  - [ ] `testSinglePerfume_recommendsSimilarNotes`
  - [ ] `testExcludesAlreadyOwned`
  - [ ] `testScoreOrdering`

---

### 3.2 Seasonal/Occasion Planner — "Was trage ich heute?"
**Priorität:** Mittel | **Aufwand:** 1-2 Wochen | **User-Value:** Hoch

**Warum:** Täglicher Use-Case. Bringt User jeden Tag zurück in die App.

#### WeatherKit Integration
- [x] Apple Developer Portal: WeatherKit Capability aktivieren
- [x] `Data/Services/WeatherService.swift`:
  ```swift
  @Observable @MainActor
  class WeatherService {
      var currentTemperature: Double?
      var currentCondition: WeatherCondition?
      var humidity: Double?

      enum WeatherCondition { case hot, warm, mild, cool, cold, rainy, humid }

      func fetchCurrentWeather() async { ... }
  }
  ```
- [x] Location-Permission: `NSLocationWhenInUseUsageDescription`

#### Empfehlungs-Logik
- [x] `Features/DailyPick/Services/DailyPickService.swift`:
  ```swift
  struct DailyPickCriteria {
      let temperature: Double
      let humidity: Double
      let occasion: Occasion
      let timeOfDay: TimeOfDay
  }

  enum Occasion: String, CaseIterable {
      case work, date, casual, sport, evening, formal
  }

  enum TimeOfDay { case morning, afternoon, evening, night }
  ```
- [x] Scoring-Algorithmus:
  ```
  Score =
    Noten-Passung (seasonal notes) × 0.3
    + Sillage-Passung (leicht im Büro, stark abends) × 0.2
    + Longevity-Passung (lang für Arbeit, mittel für casual) × 0.2
    + User-Rating × 0.2
    + Zufalls-Bonus (damit nicht immer dasselbe) × 0.1
  ```
- [x] Seasonal Note-Mapping:
  - [x] Sommer/Heiß: Citrus, Aquatic, Fresh, Green
  - [x] Winter/Kalt: Oriental, Woody, Spicy, Gourmand
  - [x] Frühling: Floral, Green, Fresh
  - [x] Herbst: Woody, Spicy, Oriental

#### Views
- [x] `Features/DailyPick/Views/DailyPickView.swift`:
  - [x] **Hero-Card**: Empfohlenes Parfum mit großem Bild
  - [x] Wetter-Widget: Temperatur + Icon
  - [x] Occasion-Selector: Horizontale Chips (Arbeit, Date, Casual...)
  - [x] "Warum dieser Duft?" Erklärung
  - [x] "Anderer Vorschlag" Button
  - [x] 3 Alternative Vorschläge darunter
- [x] Widget (optional, Phase 2):
  - [x] iOS Widget: Tagesempfehlung auf dem Homescreen
  - [x] WidgetKit Integration

#### Navigation
- [x] `RootTabView.swift`:
  - [x] Home-Tab umbenennen oder neuer Tab "Heute" als erste Position
  - [x] Alternativ: In Katalog als Top-Banner einbetten

---

### 3.3 Collection Analytics Dashboard
**Priorität:** Mittel | **Aufwand:** 1 Woche | **User-Value:** Hoch

**Warum:** Gamification. User lieben Statistiken über ihre Sammlung.

#### Data Layer
- [ ] `Data/Models/CollectionAnalyticsDTO.swift`:
  ```swift
  struct CollectionAnalytics {
      let totalPerfumes: Int
      let totalBrands: Int
      let topBrands: [(brand: String, count: Int)]
      let topNotes: [(note: String, count: Int)]
      let concentrationDistribution: [(type: String, count: Int)]
      let monthlyAdditions: [(month: Date, count: Int)]
      let averageRating: Double
      let totalReviews: Int
      let longevityDistribution: [Int: Int]
      let sillageDistribution: [Int: Int]
      let estimatedValue: Double?
  }
  ```
- [ ] Lokale Berechnung aus SwiftData (kein Server nötig):
  ```swift
  @MainActor
  class CollectionAnalyticsService {
      func calculateAnalytics(from perfumes: [Perfume]) -> CollectionAnalytics { ... }
  }
  ```

#### Views
- [ ] `Features/Profile/Views/CollectionAnalyticsView.swift`:
  - [ ] **Header**: "Deine Sammlung in Zahlen"
  - [ ] **Stat Cards** (Grid):
    - [ ] Gesamtzahl Parfums, Verschiedene Marken, Durchschnittsbewertung, Geschriebene Reviews
  - [ ] **Top 5 Marken** (Balkendiagramm, Swift Charts)
  - [ ] **Top 10 Noten** (Bubble Chart oder Word Cloud)
  - [ ] **Konzentrations-Verteilung** (Donut Chart): EDP vs EDT vs Parfum vs EDC
  - [ ] **Timeline** (Linien-Chart): Monatliche Neuzugänge
  - [ ] **Performance-Verteilung**: Longevity- und Sillage-Histogramm
- [ ] `Features/Profile/Views/AnalyticsWidgets/`:
  - [ ] `TopBrandsChart.swift`
  - [ ] `ConcentrationDonut.swift`
  - [ ] `CollectionTimeline.swift`
  - [ ] `NoteCloud.swift`

#### Integration
- [ ] `ProfileView.swift`:
  - [ ] "Sammlungs-Statistiken" Button → NavigationLink
- [ ] `FragranceProfileView.swift`:
  - [ ] Analytics als zusätzliche Section

---

### 3.4 Freunde & Social Graph
**Priorität:** Niedrig | **Aufwand:** 2-3 Wochen | **User-Value:** Hoch (langfristig)

**Warum:** Community-Building. Macht die App "sticky".

#### Backend
- [ ] `friendships`-Tabelle:
  ```sql
  CREATE TABLE friendships (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      requester_id UUID REFERENCES auth.users(id),
      addressee_id UUID REFERENCES auth.users(id),
      status TEXT CHECK (status IN ('pending', 'accepted', 'blocked')),
      created_at TIMESTAMPTZ DEFAULT NOW(),
      UNIQUE(requester_id, addressee_id)
  );
  ```
- [ ] RLS: Nur eigene Freundschaften lesen/schreiben
- [ ] RPCs:
  - [ ] `send_friend_request(target_user_id)`
  - [ ] `accept_friend_request(friendship_id)`
  - [ ] `reject_friend_request(friendship_id)`
  - [ ] `remove_friend(friendship_id)`
  - [ ] `get_friends(user_id)` → Liste mit Profil-Info
  - [ ] `get_friend_activity(user_id)` → Neueste Aktionen der Freunde

#### Data Layer
- [ ] `Data/Models/FriendshipDTO.swift`
- [ ] `Data/Models/ActivityFeedItemDTO.swift`:
  ```swift
  struct ActivityFeedItem: Codable, Identifiable {
      let id: UUID
      let userId: UUID
      let username: String
      let actionType: String     // "added_to_collection", "reviewed", "favorited", "liked_review"
      let perfumeId: UUID
      let perfumeName: String
      let timestamp: Date
  }
  ```
- [ ] `Data/Persistence/FriendshipDataSource.swift`

#### Feature Layer
- [ ] `Features/Social/ViewModels/FriendsViewModel.swift`
- [ ] `Features/Social/ViewModels/ActivityFeedViewModel.swift`
- [ ] `Features/Social/Views/FriendsListView.swift`:
  - [ ] Liste aller Freunde mit Avatar + Username
  - [ ] Pending Requests Section (mit Accept/Reject)
  - [ ] "Freund hinzufügen" Button → UserSearchView
- [ ] `Features/Social/Views/ActivityFeedView.swift`:
  - [ ] Chronologischer Feed: "hat [Parfum] zur Sammlung hinzugefügt", "hat [Parfum] mit X Sternen bewertet", etc.
  - [ ] Tap → Navigation zu Parfum oder Profil
  - [ ] Pull-to-Refresh + Infinite Scroll

#### Navigation
- [ ] `RootTabView.swift`:
  - [ ] "Community"-Tab mit ActivityFeedView als Root (aktuell: UserSearchView)
  - [ ] Tab-Reihenfolge überdenken: Katalog | Community | Meine | Wunschliste | Profil

---

### 3.5 Multi-Language Support
**Priorität:** Niedrig | **Aufwand:** 1 Woche | **User-Value:** Mittel (erweitert Zielgruppe)

**Warum:** App ist aktuell nur Deutsch. Englisch + Französisch öffnet größeren Markt.

- [ ] String Catalog erstellen:
  - [ ] `Localizable.xcstrings` Datei in Xcode erstellen
  - [ ] Alle hardcoded deutschen Strings extrahieren
- [ ] Systematisch durch alle Views:
  - [ ] `"Katalog"` → `String(localized: "tab.catalog")`
  - [ ] `"Favoriten"` → `String(localized: "tab.favorites")`
  - [ ] `"Keine Ergebnisse"` → `String(localized: "search.noResults")`
  - [ ] etc. für alle ~100+ Strings
- [ ] Sprachen hinzufügen:
  - [ ] Englisch (en)
  - [ ] Französisch (fr)
- [ ] Plural-Formen:
  ```
  "%lld Düfte" → String(localized: "\(count) perfumes", comment: "Perfume count")
  // Stringsdict: one = "%lld Duft", other = "%lld Düfte"
  ```
- [ ] `SettingsView.swift`:
  - [ ] Sprach-Auswahl (oder System-Standard)
- [ ] Error-Messages in `NetworkError.swift`:
  - [ ] Alle `String(localized:)` verwenden
- [ ] Testen: Gerät auf EN/FR umstellen → alle Screens prüfen