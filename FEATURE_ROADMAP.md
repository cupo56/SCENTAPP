# Scentboxd — Feature-Roadmap & Detaillierte Todos

> Erstellt am 12.03.2026 | Basierend auf Codebase-Analyse
> Priorisierung: Phase 1 (Sofort) → Phase 2 (Nächste Wochen) → Phase 3 (Langfristig)

---

## PHASE 0 — Bugfixes & Technische Schulden (VOR neuen Features)

### 0.7 Accessibility Labels hinzufügen
**Priorität:** Mittel | **Aufwand:** 2-3 Std

- [ ] `PerfumeCardView.swift`:
  - [ ] `.accessibilityLabel("\(perfume.name) von \(perfume.brand?.name ?? "Unbekannt")")` auf Card
  - [ ] `.accessibilityHint("Doppeltippen für Details")`
  - [ ] Favorite-Heart: `.accessibilityLabel(isFavorite ? "Favorit entfernen" : "Als Favorit markieren")`
- [ ] `PerfumeActionsSection.swift`:
  - [ ] Jeder Button: `.accessibilityLabel()` mit aktuellem Status
- [ ] `ReviewFormView.swift`:
  - [ ] Star-Rating: `.accessibilityValue("\(rating) von 5 Sternen")`
  - [ ] `.accessibilityAdjustableAction` für Stern-Auswahl per Swipe
- [ ] `PerfumeListView.swift`:
  - [ ] Filter-Chips: `.accessibilityLabel("Filter: \(filterName) aktiv")`
  - [ ] Sort-Button: `.accessibilityLabel("Sortierung: \(sortOption.displayName)")`
- [ ] `RootTabView.swift`:
  - [ ] Tab-Badge für Anzahl Favoriten/Owned (optional)
- [ ] VoiceOver-Test auf echtem Gerät durchführen

---

## PHASE 1 — Quick Wins (1-2 Tage pro Feature)

## PHASE 2 — Mittelfristige Features (3-7 Tage pro Feature)

### 2.1 Social Features: User-Profile ansehen
**Priorität:** Hoch | **Aufwand:** 3-5 Tage | **User-Value:** Sehr Hoch

**Warum:** Community ist das Herz einer App wie Letterboxd. User wollen sehen, was andere sammeln.

#### Backend (Supabase)
- [ ] `profiles`-Tabelle erweitern (falls nötig):
  - [ ] `is_public BOOLEAN DEFAULT true`
  - [ ] `bio TEXT`
  - [ ] `avatar_url TEXT`
- [ ] Row Level Security:
  - [ ] Public Profiles: `SELECT` für alle authentifizierten User
  - [ ] Private Profiles: Nur eigenes Profil
- [ ] RPC `get_public_user_profile(target_user_id UUID)`:
  - [ ] Gibt Profil + Stats (owned_count, review_count, favorite_count) zurück
- [ ] RPC `get_public_user_collection(target_user_id UUID, page INT, page_size INT)`:
  - [ ] Gibt öffentliche Sammlung zurück

#### Data Layer
- [ ] `Data/Models/PublicProfileDTO.swift`:
  ```swift
  struct PublicProfileDTO: Codable, Identifiable {
      let id: UUID
      let username: String
      let bio: String?
      let avatarUrl: String?
      let isPublic: Bool
      let ownedCount: Int
      let reviewCount: Int
      let favoriteCount: Int
      let memberSince: Date
  }
  ```
- [ ] `Data/Persistence/PublicProfileDataSource.swift`:
  - [ ] `fetchPublicProfile(userId: UUID) async throws -> PublicProfileDTO`
  - [ ] `fetchPublicCollection(userId: UUID, page: Int, pageSize: Int) async throws -> [PerfumeDTO]`
  - [ ] `searchUsers(query: String) async throws -> [PublicProfileDTO]`

#### Feature Layer
- [ ] `Features/Social/` Ordner erstellen
- [ ] `Features/Social/ViewModels/PublicProfileViewModel.swift`:
  ```swift
  @Observable @MainActor
  class PublicProfileViewModel {
      var profile: PublicProfileDTO?
      var collection: [Perfume] = []
      var isLoading = false
      var errorMessage: String?

      func loadProfile(userId: UUID) async { ... }
      func loadCollection(userId: UUID, page: Int) async { ... }
  }
  ```
- [ ] `Features/Social/Views/PublicProfileView.swift`:
  - [ ] Header: Avatar, Username, Bio, Member Since
  - [ ] Stats-Grid: Owned, Reviews, Favorites
  - [ ] Sammlung als Grid (PerfumeCardView wiederverwenden)
  - [ ] Reviews-Tab (UserReviewsView-Stil)
  - [ ] "Privates Profil"-Hinweis wenn `!isPublic`
- [ ] `Features/Social/Views/UserSearchView.swift`:
  - [ ] Suchfeld für Usernamen
  - [ ] Ergebnisliste mit Avatar + Username + Stats
  - [ ] Navigation zu PublicProfileView

#### Integration
- [ ] `ReviewCard.swift`:
  - [ ] Tap auf Author-Name → Navigation zu PublicProfileView
- [ ] `ProfileView.swift`:
  - [ ] Toggle: "Profil öffentlich" (Supabase Update)
  - [ ] Bio-Textfeld hinzufügen
- [ ] `RootTabView.swift`:
  - [ ] Optional: "Community"-Tab oder in Katalog integrieren

#### Tests
- [ ] `PublicProfileViewModelTests.swift`
- [ ] `UserSearchTests.swift`
- [ ] RLS-Tests: Sicherstellen dass private Profile nicht lesbar sind

---

### 2.2 Duftrad / Scent Wheel Visualisierung
**Priorität:** Mittel | **Aufwand:** 3-4 Tage | **User-Value:** Hoch

**Warum:** Einzigartiges Feature, das die App visuell von der Konkurrenz abhebt.

#### Backend
- [ ] Duftfamilien-Kategorisierung in `notes`-Tabelle (falls nicht vorhanden):
  - [ ] `family TEXT` (z.B. "Floral", "Woody", "Oriental", "Fresh", "Citrus", "Gourmand", "Aquatic", "Green", "Spicy", "Musky")
- [ ] RPC `get_user_scent_wheel(user_id UUID)`:
  ```sql
  RETURNS TABLE(family TEXT, count INT, percentage FLOAT)
  -- Zählt alle Noten-Familien der owned/favorisierten Parfums
  ```

#### Data Layer
- [ ] `Data/Models/ScentWheelDTO.swift`:
  ```swift
  struct ScentWheelSegment: Codable, Identifiable {
      let family: String
      let count: Int
      let percentage: Double
      var id: String { family }
  }
  ```
- [ ] Repository-Erweiterung: `fetchScentWheel(userId: UUID) async throws -> [ScentWheelSegment]`

#### Feature Layer
- [ ] `Features/Profile/Services/ScentWheelService.swift`:
  - [ ] Daten laden + cachen (ändert sich selten)
  - [ ] Fallback: Lokal berechnen aus SwiftData wenn offline
- [ ] `Features/Profile/Views/ScentWheelView.swift`:
  - [ ] **Kreisdiagramm** mit Swift Charts:
    ```swift
    Chart(segments) { segment in
        SectorMark(
            angle: .value("Anteil", segment.percentage),
            innerRadius: .ratio(0.5),
            angularInset: 2
        )
        .foregroundStyle(colorForFamily(segment.family))
        .annotation(position: .overlay) {
            Text(segment.family)
        }
    }
    ```
  - [ ] Tap auf Segment → Liste der Parfums mit dieser Duftfamilie
  - [ ] Legende unter dem Chart
  - [ ] Animation: Segmente wachsen ein bei onAppear
- [ ] `Features/Profile/Views/FragranceProfileView.swift`:
  - [ ] `ScentWheelView` als erste Section einbinden
  - [ ] "Dein Duftprofil basiert auf X Düften"

#### Design
- [ ] Farbpalette für Familien definieren:
  - [ ] Floral: Rosa (#FFB6C1)
  - [ ] Woody: Braun (#8B7355)
  - [ ] Oriental: Gold (#DAA520)
  - [ ] Fresh: Mint (#98FB98)
  - [ ] Citrus: Gelb (#FFD700)
  - [ ] Gourmand: Schokolade (#D2691E)
  - [ ] Aquatic: Blau (#87CEEB)
  - [ ] Green: Grün (#3CB371)
  - [ ] Spicy: Rot (#CD5C5C)
  - [ ] Musky: Grau (#C0C0C0)
- [ ] In `DesignSystem.swift` als `scentFamilyColors` Dictionary

---

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

### 2.4 Benachrichtigungen (Push Notifications)
**Priorität:** Niedrig-Mittel | **Aufwand:** 5-7 Tage | **User-Value:** Mittel

**Warum:** Engagement-Feature. Bringt User zurück in die App.

#### Backend (Supabase Edge Functions)
- [ ] `supabase/functions/send-notification/` erstellen
- [ ] APNs Integration über Supabase (oder Firebase Cloud Messaging)
- [ ] `device_tokens`-Tabelle:
  ```sql
  CREATE TABLE device_tokens (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID REFERENCES auth.users(id),
      token TEXT NOT NULL,
      platform TEXT DEFAULT 'ios',
      created_at TIMESTAMPTZ DEFAULT NOW()
  );
  ```
- [ ] Trigger-Funktionen:
  - [ ] `on_new_review`: Wenn jemand ein Parfum aus deiner Sammlung bewertet
  - [ ] `on_similar_added`: Wenn ein ähnliches Parfum hinzugefügt wird (optional)

#### iOS Implementation
- [ ] `App/NotificationManager.swift`:
  ```swift
  @Observable @MainActor
  class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
      var isPermissionGranted = false

      func requestPermission() async -> Bool { ... }
      func registerDeviceToken(_ token: Data) async { ... }
      func handleNotification(_ response: UNNotificationResponse) { ... }
  }
  ```
- [ ] `scentboxdApp.swift`:
  - [ ] `UIApplicationDelegateAdaptor` für Push Token Registration
  - [ ] `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`
- [ ] `Features/Profile/Views/NotificationSettingsView.swift`:
  - [ ] Toggle: "Neue Reviews zu meinen Düften"
  - [ ] Toggle: "Ähnliche Düfte"
  - [ ] Toggle: "Community-Updates"
  - [ ] Jeder Toggle → Supabase `notification_preferences` Update
- [ ] Deep Link Handling für Notification-Taps → Detail-View

#### Tests
- [ ] `NotificationManagerTests.swift`
- [ ] Integration Test: Review erstellen → Notification an Parfum-Owner

---

### 2.5 Dark/Light Mode Toggle
**Priorität:** Niedrig | **Aufwand:** 1-2 Tage | **User-Value:** Mittel

**Warum:** Manche User bevorzugen Light Mode. Aktuell ist nur Dark Mode.

- [ ] `App/ThemeManager.swift` erstellen:
  ```swift
  @Observable
  class ThemeManager {
      @AppStorage("colorScheme") var selectedScheme: String = "dark"

      var colorScheme: ColorScheme? {
          switch selectedScheme {
          case "light": return .light
          case "dark": return .dark
          default: return nil  // System
          }
      }
  }
  ```
- [ ] `DesignSystem.swift`:
  - [ ] Alle hardcoded Dark-Mode Farben durch `Color(light:dark:)` oder Asset-Catalog-Farben ersetzen
  - [ ] Backgrounds: Dark = `#341826` → Light = `#FFF5F9`
  - [ ] Text: Invertieren oder adaptiv
  - [ ] GlassPanel: Transparenz anpassen
- [ ] `SettingsView.swift`:
  - [ ] Neue Section "Erscheinungsbild":
    - [ ] Picker: "Dunkel" / "Hell" / "System"
    - [ ] Live-Preview (kleiner Mock-Screen)
- [ ] `scentboxdApp.swift`:
  - [ ] `.preferredColorScheme(themeManager.colorScheme)`
- [ ] Alle Views durchgehen:
  - [ ] `.background(Color.black)` → `.background(Color.appBackground)` etc.
  - [ ] Hardcoded Farben durch Design Tokens ersetzen
- [ ] Testen: Alle Screens in Light Mode Screenshots machen

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
- [ ] Apple Developer Portal: WeatherKit Capability aktivieren
- [ ] `Data/Services/WeatherService.swift`:
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
- [ ] Location-Permission: `NSLocationWhenInUseUsageDescription`

#### Empfehlungs-Logik
- [ ] `Features/DailyPick/Services/DailyPickService.swift`:
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
- [ ] Scoring-Algorithmus:
  ```
  Score =
    Noten-Passung (seasonal notes) × 0.3
    + Sillage-Passung (leicht im Büro, stark abends) × 0.2
    + Longevity-Passung (lang für Arbeit, mittel für casual) × 0.2
    + User-Rating × 0.2
    + Zufalls-Bonus (damit nicht immer dasselbe) × 0.1
  ```
- [ ] Seasonal Note-Mapping:
  - [ ] Sommer/Heiß: Citrus, Aquatic, Fresh, Green
  - [ ] Winter/Kalt: Oriental, Woody, Spicy, Gourmand
  - [ ] Frühling: Floral, Green, Fresh
  - [ ] Herbst: Woody, Spicy, Oriental

#### Views
- [ ] `Features/DailyPick/Views/DailyPickView.swift`:
  - [ ] **Hero-Card**: Empfohlenes Parfum mit großem Bild
  - [ ] Wetter-Widget: Temperatur + Icon
  - [ ] Occasion-Selector: Horizontale Chips (Arbeit, Date, Casual...)
  - [ ] "Warum dieser Duft?" Erklärung
  - [ ] "Anderer Vorschlag" Button
  - [ ] 3 Alternative Vorschläge darunter
- [ ] Widget (optional, Phase 2):
  - [ ] iOS Widget: Tagesempfehlung auf dem Homescreen
  - [ ] WidgetKit Integration

#### Navigation
- [ ] `RootTabView.swift`:
  - [ ] Home-Tab umbenennen oder neuer Tab "Heute" als erste Position
  - [ ] Alternativ: In Katalog als Top-Banner einbetten

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
      let longevityDistribution: [Int: Int]   // Bucket → Count
      let sillageDistribution: [Int: Int]
      let estimatedValue: Double?  // Optional: Geschätzter Sammlungswert
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
    - [ ] Gesamtzahl Parfums (großer Zahlenwert)
    - [ ] Verschiedene Marken
    - [ ] Durchschnittsbewertung
    - [ ] Geschriebene Reviews
  - [ ] **Top 5 Marken** (Balkendiagramm, Swift Charts):
    ```swift
    Chart(topBrands) { brand in
        BarMark(x: .value("Anzahl", brand.count), y: .value("Marke", brand.brand))
    }
    ```
  - [ ] **Top 10 Noten** (Bubble Chart oder Word Cloud)
  - [ ] **Konzentrations-Verteilung** (Donut Chart):
    - [ ] EDP vs EDT vs Parfum vs EDC
  - [ ] **Timeline** (Linien-Chart):
    - [ ] Monatliche Neuzugänge über die Zeit
  - [ ] **Performance-Verteilung**:
    - [ ] Longevity-Histogram
    - [ ] Sillage-Histogram
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
      let actionType: String     // "added_to_collection", "reviewed", "favorited"
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
  - [ ] Chronologischer Feed:
    - [ ] "[User] hat [Parfum] zur Sammlung hinzugefügt"
    - [ ] "[User] hat [Parfum] mit X Sternen bewertet"
    - [ ] "[User] hat [Parfum] als Favorit markiert"
  - [ ] Tap → Navigation zu Parfum oder Profil
  - [ ] Pull-to-Refresh
  - [ ] Infinite Scroll

#### Navigation
- [ ] `RootTabView.swift`:
  - [ ] "Community"-Tab mit ActivityFeedView als Root
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

---

## Empfohlene Reihenfolge

```
Woche 1:    0.7 (Accessibility Restarbeiten) + 2.1 (Social Profiles)
Woche 2:    2.2 (Scent Wheel) + 2.5 (Dark/Light Mode)
Woche 3-4:  2.3 (Barcode Scanner)
Woche 5:    3.3 (Collection Analytics)
Woche 6-8:  3.1 (ML Empfehlungen)
Woche 9-10: 3.2 (Daily Pick / Seasonal Planner)
Woche 11+:  3.4 (Social Graph) + 3.5 (Multi-Language)
```

---

## Notizen

- **Vor jedem Feature**: Branch erstellen (`feature/social-profiles`, `feature/barcode-scanner`, etc.)
- **Nach jedem Feature**: Tests schreiben, PR erstellen, auf `main` mergen
- **Supabase-Änderungen**: Immer zuerst in Staging-Projekt testen
- **SwiftData Migrationen**: Lightweight Migrations bevorzugen (neue Felder mit Defaults)
- **App Store**: Nach Phase 1 ist die App "feature-complete" genug für ein erstes Release
