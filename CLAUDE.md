# Cozumel Manager Project

## Overview
Native Mac Silicon app for managing premium vacation rentals in Cozumel.
Properties: Nah Ha 101, Casa Bohemia, Cool Caribbean Views.

## Tech Stack
- Frontend: SwiftUI (Native macOS, targets macOS 14+)
- Data: Local JSON → moving to Supabase (not yet wired)
- Logic: Revenue forecasting and manual property oversight
- Auto-update: Sparkle 2 (SPM, v2.9.3) — `SPUStandardUpdaterController` (not `SPUUpdaterController`)

## Commands
```bash
# Open project
open CozumelManager/CozumelManager.xcodeproj

# Build & run: Cmd+R in Xcode
# Archive for distribution: Product → Archive → Distribute App → Direct Distribution
```

## Directory Structure
```
appcast.xml                           # Sparkle update feed — add <item> per release, newest first
CozumelManager/
├── CozumelManager/
│   ├── CozumelManagerApp.swift       # App entry point, PropertyStore + SPUStandardUpdaterController
│   ├── Models/
│   │   ├── Property.swift            # Data model + monthlyRevenue computed property
│   │   └── PropertyModel.swift       # PropertyStore (ObservableObject, loads JSON)
│   ├── Views/
│   │   ├── MainDashboardView.swift   # Root view, NavigationSplitView
│   │   ├── SidebarView.swift         # Property list sidebar with add/delete toolbar
│   │   ├── PropertyInspectorView.swift  # Edit panel — details, availability, photos
│   │   ├── AddPropertySheet.swift    # Sheet for adding a new property
│   │   └── AddUserPlaceholderSheet.swift  # Stub — user management not yet implemented
│   ├── properties.json               # Local data source (3 properties)
│   └── CozumelManager.entitlements   # Sandbox entitlements — edit here to add capabilities
└── Config/
    ├── Secrets.xcconfig              # Git-ignored — Supabase keys go here
    └── Secrets.xcconfig.example      # Committed template showing required keys
```

## Architecture
- `PropertyStore` is created once in `CozumelManagerApp` and injected via `.environmentObject` — do not recreate it in views
- App uses `Window` scene (not `WindowGroup`) — intentionally single-window
- `Property.Hashable` uses `id` only — intentional, do not change to full-field synthesis
- `monthlyRevenue` returns `0` for `.inactive` and `.maintenance` properties — required for accurate `totalMonthlyRevenue`

## Sparkle 2 Auto-Update (IMPORTANT)
- Class is `SPUStandardUpdaterController` — NOT `SPUUpdaterController` (that class does not exist in Sparkle 2.9.3)
- `SUFeedURL` and `SUPublicEDKey` are injected into Info.plist via a PlistBuddy shell script build phase — Xcode 26's SwiftBuild drops third-party `INFOPLIST_KEY_*` entries silently, so the standard approach does not work
- `ENABLE_USER_SCRIPT_SANDBOXING = NO` in build settings — required for the PlistBuddy script to write to the app bundle at build time; does NOT affect the app's runtime sandbox
- Signing tools: `~/sparkle-tools/generate_keys` and `~/sparkle-tools/sign_update` (local only, not in repo)
- Private signing key is in Keychain under service `https://sparkle-project.org` — never commit it
- appcast.xml is hosted at `https://raw.githubusercontent.com/hahaluaha/Cozumel-Manager/master/appcast.xml` (master branch, repo is public)

## Secrets Management (Pre-Supabase — IMPORTANT)
- Never put API keys in source files or `properties.json`
- Keys flow: `Config/Secrets.xcconfig` → `Info.plist` preprocessor macro → `Bundle.main.object(forInfoDictionaryKey:)`
- `com.apple.security.network.client` is already in `CozumelManager.entitlements` (added for Sparkle) — Supabase will use the same entitlement
- When adding any new entitlement, add it to `CozumelManager.entitlements` — not build settings
- Use Supabase Swift SDK typed filter methods only — no string interpolation into queries

## Instructions
- Keep logic focused on luxury management
- Kelley handles staff manually — no auto-routing features
- No auto-booking, no guest messaging, no staff scheduling
