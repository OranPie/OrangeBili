# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OrangeBili is a multi-platform Bilibili lightweight client built with SwiftUI. watchOS is the primary platform, with iOS Companion and tvOS support. The project uses MVVM + Service Layer architecture with Combine for reactive state management.

Languages: Swift 5.9+, localized in English and Simplified Chinese.

## Build Commands

All builds use Xcode project (`OrangeBili.xcodeproj`). The shared framework resolves automatically as a local SPM package.

```bash
# watchOS (primary platform) — ARCHS=arm64 required, FFmpeg libs are arm64-only
xcodebuild -project "OrangeBili.xcodeproj" \
  -scheme "OrangeBili Watch App" \
  -configuration Debug -sdk watchsimulator \
  -destination "generic/platform=watchOS Simulator" \
  -derivedDataPath "./DerivedData" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build

# iOS Companion
xcodebuild -project "OrangeBili.xcodeproj" \
  -scheme "OrangeBili" \
  -configuration Debug -sdk iphonesimulator \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath "./DerivedData" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build

# tvOS
xcodebuild -project "OrangeBili.xcodeproj" \
  -scheme "OrangeBiliTV" \
  -configuration Debug -sdk appletvsimulator \
  -destination "generic/platform=tvOS Simulator" \
  -derivedDataPath "./DerivedData" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

Schemes: `OrangeBili`, `OrangeBili Watch App`, `OrangeBiliTV`, `OrangeBiliCore`, `OrangeBiliUI`.

No test targets exist currently.

## Architecture

### Shared Package (`OrangeBiliShared/`)

All core logic and UI lives in a local Swift Package with two targets:

- **OrangeBiliCore** — API client, models, ViewModels, services, storage, utilities
- **OrangeBiliUI** — SwiftUI views and components (depends on OrangeBiliCore)

Platform apps (`OrangeBili Watch App/`, `OrangeBili/`, `OrangeBiliTV/`) are thin shells that import these libraries.

### Key Layers (in `OrangeBiliShared/Sources/OrangeBiliCore/`)

- **Services/**: `BiliAPIBackend` (main API facade, `@MainActor ObservableObject`), `BiliService` (protocol-based service), `NetworkClient` (HTTP with retry + offline cache + WBI signing), `BiliAuthStore` (auth state), `BiliQRLoginService`, `DanmakuService`, `OfflineDownloadManager`
- **ViewModels/**: Home, Search, VideoDetail, Player, Comments, Danmaku, History, Uploader — all `@MainActor ObservableObject`
- **Models/**: `BiliModels.swift` (API response types), `DanmakuModels.swift`
- **Storage/**: `HistoryStore`, `FavoritesStore`, `UploaderVisitStore`, `ImageCacheStore` — local persistence via FileManager/UserDefaults
- **Utils/**: `RenderSettings` (persistent UI scaling + danmaku prefs), `L10n` (localization), `Formatting`, `PlatformInfo`

### Cross-Device Sync (watchOS ↔ iOS)

- watchOS: `WatchCompanionSyncer` monitors stores with 1-second debounce → `CompanionBridge` sends via WatchConnectivity
- iOS: `CompanionConnectivityManager` receives and merges into local stores
- Dual channel: prefers `sendMessage` (reachable), falls back to `updateApplicationContext`
- Commands: `syncHistory`, `syncFavorites`, `syncAccount`, `requestAuthState`

### Platform Differences

- tvOS uses 1.05x text scale; watchOS uses 0.9x (configured in `RenderSettings`)
- tvOS detail page uses single-row horizontal scrolling for tags to avoid focus issues
- No external dependencies — pure Foundation + SwiftUI + WatchConnectivity

## Localization

String files at `OrangeBiliShared/Sources/OrangeBiliCore/Resources/{en,zh-Hans}.lproj/Localizable.strings`. Access via `L10n` helper.

## Known Gotchas

- watchOS `Int` is 32-bit — never force-cast `Int64`/`Double` to `Int`; use safe bounded conversion (see `BiliAuthStore`)
- CoreSimulator log noise during builds is normal if build succeeds
- Bilibili API uses WBI signing (`WBISigner`) — signature params change periodically
- See `docs/TROUBLESHOOTING.md` for sync and crash debugging
