# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

ScentBox (scentboxd) — iOS fragrance cataloging app ("Letterboxd for Parfüms"). Built with SwiftUI + Supabase. UI language is German.

Xcode project: `scentboxd/scentboxd.xcodeproj`

## Setup

Copy `Config.xcconfig.example` to `Config.xcconfig` and fill in your Supabase credentials:

```
SUPABASE_URL = https://YOUR_PROJECT_REF.supabase.co
SUPABASE_KEY = YOUR_SUPABASE_ANON_KEY
```

`Config.xcconfig` is git-ignored.

## Build & Test

Build and run via Xcode (open `scentboxd/scentboxd.xcodeproj`).

Run all tests:
```bash
xcodebuild test -project scentboxd/scentboxd.xcodeproj -scheme scentboxd -destination 'platform=iOS Simulator,name=iPhone 16'
```

Run a single test class:
```bash
xcodebuild test -project scentboxd/scentboxd.xcodeproj -scheme scentboxd -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:scentboxdTests/PerfumeDetailViewModelTests
```

Lint (SwiftLint config is `.swiftlint.yml` — file length warning at 500 lines, `force_unwrapping` is opt-in enabled):
```bash
swiftlint lint scentboxd/
```

## Architecture

Clean Architecture + MVVM with four source layers:

**`Domain/Entities/`** — Pure Swift models decorated with `@Model` for SwiftData: `Perfume`, `Brand`, `Note`, `Review`, `UserPersonalData` (mapped to `UserPerfumeStatus`).

**`Data/`**
- `Models/` — DTOs (Codable structs) used for Supabase responses; converted to domain entities before reaching the UI.
- `Persistence/` — Protocol-based data sources (`PerfumeRepository`, `ReviewDataSourceProtocol`, `UserPerfumeDataSourceProtocol`, `PublicProfileDataSourceProtocol`, `CuratedListDataSourceProtocol`) with remote implementations backed by Supabase. `PerfumeCacheService` provides a SwiftData-backed local cache with a 5-minute TTL. `ReviewSyncService` and `UserPerfumeSyncService` handle deferred writes when offline.
- `Networking/` — `NetworkError` (typed errors, German user messages), `NetworkMonitor` (NWPathMonitor), `NetworkRetry` (exponential backoff via `withRetry()`), `CertificatePinning`, `AppLogger`.

**`Features/`** — MVVM feature modules. Each has `Views/`, `ViewModels/`, and optionally `Services/` and `Components/`. Current features: `Auth`, `Compare`, `Favorites`, `Lists`, `Owned`, `PerfumeDetail`, `PerfumeList`, `Profile`, `Reviews`, `Social`.

**`UI/`** — Shared components (`UI/Components/`), navigation entry points (`ContentView`, `RootTabView`), and the design system (`UI/Theme/DesignSystem.swift`).

**`App/`** — App entry (`scentboxdApp.swift`), `DependencyContainer`, `AuthManager`, `ThemeManager`, `NotificationManager`, `DeepLinkHandler`, `AppConfig`.

## Key Patterns

### Dependency Injection
`DependencyContainer` is a `@MainActor final class` that wires all dependencies together. It is injected into the SwiftUI environment as `\.dependencies` and accessed in views via `@Environment(\.dependencies)`. It exposes factory methods (e.g. `makePerfumeDetailViewModel(perfume:)`) rather than being used as a service locator directly from view code.

### Observable State
Uses the `@Observable` macro (Swift 5.9+), not `ObservableObject`/`@Published`. Global singletons (`AuthManager`, `NotificationManager`, `ThemeManager`, `DeepLinkHandler`, `CompareSelectionManager`) are passed down as environment objects.

### Offline-First Data Flow
1. `PerfumeCacheService` loads from SwiftData immediately (cache-first).
2. If TTL expired or cache empty, `PerfumeRemoteDataSource` fetches from Supabase.
3. Remote results are upserted into SwiftData using UUID predicates to prevent duplicates.
4. `NetworkMonitor.shared` gates remote calls; offline state is surfaced to the user.

### Error Handling
All errors flow through `NetworkError`. Call `NetworkError.handle(_:logger:context:)` to log and get a German user-facing string. Never show raw Swift errors to the user.

### Testing
Tests are in `scentboxd/scentboxdTests/`. Protocols enable mock injection — see `MockPerfumeRepository`, `MockReviewDataSource`, `MockUserPerfumeDataSource`. Use `TestFactory` helpers (`TestFactory.makePerfume()`, `TestFactory.makeModelContainer()`) to build test fixtures. All test classes are `@MainActor`.

### Design System
Use `DesignSystem.Colors` for all colors. Adaptive tokens (`appBackground`, `appSurface`, `appText`, `appTextSecondary`) respond to dark/light mode — prefer these over hardcoded hex values. The primary accent is `DesignSystem.Colors.primary` (`#C20A66` magenta). `ThemeManager` stores the user's scheme preference in `UserDefaults` and is applied via `.preferredColorScheme(themeManager.colorScheme)` at the root.

### Deep Links
URL scheme: `scentboxd://`. Handled by `DeepLinkHandler`; routes are `perfume/<UUID>`, `tab/<name>`, and `compare/<UUID>,<UUID>`. Deep links from push notification taps are forwarded via `NotificationCenter` with name `.notificationDeepLink`.

### SwiftData Schema Changes
When the SwiftData schema changes, the existing store is deleted and rebuilt from Supabase on next sync. This is handled automatically in `scentboxdApp.init()` — do not use migration plans unless a lightweight migration is strictly necessary.

## Supabase / Backend

Database migrations live in `supabase/migrations/`. Edge functions live in `supabase/functions/`. Always test Supabase schema changes in a staging project before applying to production.

Push notification edge function (`send-notification`) requires these secrets set in the Supabase dashboard: `APNS_TEAM_ID`, `APNS_KEY_ID`, `APNS_PRIVATE_KEY`, `APNS_BUNDLE_ID`, `APNS_PRODUCTION`.
