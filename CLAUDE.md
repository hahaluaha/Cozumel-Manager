# Cozumel Manager Project

## Overview
Native Mac Silicon app for managing premium vacation rentals in Cozumel.
Properties: Nah Ha 101, Casa Bohemia, Cool Caribbean Views.

## Tech Stack
- Frontend: SwiftUI (Native macOS, targets macOS 14+)
- Data: Local JSON → moving to Supabase (not yet wired)
- Logic: Revenue forecasting and manual property oversight

## Commands
```bash
# Open project
open CozumelManager/CozumelManager.xcodeproj

# Build & run: Cmd+R in Xcode
# Archive for distribution: Product → Archive → Distribute App → Direct Distribution
```

## Directory Structure
```
CozumelManager/
├── CozumelManager/
│   ├── CozumelManagerApp.swift       # App entry point, PropertyStore injected here
│   ├── Models/
│   │   ├── Property.swift            # Data model + monthlyRevenue computed property
│   │   └── PropertyModel.swift       # PropertyStore (ObservableObject, loads JSON)
│   ├── Views/
│   │   ├── MainDashboardView.swift   # Root view, NavigationSplitView
│   │   └── SidebarView.swift         # Property list sidebar
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

## Secrets Management (Pre-Supabase — IMPORTANT)
- Never put API keys in source files or `properties.json`
- Keys flow: `Config/Secrets.xcconfig` → `Info.plist` preprocessor macro → `Bundle.main.object(forInfoDictionaryKey:)`
- When adding `network.client` entitlement for Supabase, add it to `CozumelManager.entitlements` — not build settings
- Use Supabase Swift SDK typed filter methods only — no string interpolation into queries

## Instructions
- Keep logic focused on luxury management
- Kelley handles staff manually — no auto-routing features
- No auto-booking, no guest messaging, no staff scheduling
