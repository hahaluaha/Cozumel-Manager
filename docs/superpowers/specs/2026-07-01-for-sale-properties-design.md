# For Sale Properties — Design Spec
Date: 2026-07-01

## Overview
Add a dedicated "For Sale" section to Cozumel Manager for tracking properties listed for sale. Separate from the rental properties — different data model, different inspector, same visual language. Kelley manages one property for sale currently; the section supports adding more over time.

## Approach
Option B: new `ForSaleProperty` model, new `ForSaleStore`, new sidebar section, new inspector view. The rental codebase is untouched.

## Data Model
**`CozumelManager/Models/ForSaleProperty.swift`** — model only:

```swift
struct ForSaleProperty: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var description: String
    var askingPrice: Double       // USD; formatted as currency in UI
    var listingURL: String        // external listing, opens in browser
    var photos: [String]          // file names, same pattern as Property.photos
    var notes: String
}
// Hashable uses id only — same convention as Property
```

**`CozumelManager/Models/ForSaleModel.swift`** — store:

`ForSaleStore: ObservableObject` loads from `forSaleProperties.json` (bundled in app), exposes `@Published var properties: [ForSaleProperty]`, and handles add/delete/save — mirroring `PropertyStore`.

Injected via `.environmentObject` in `CozumelManagerApp.swift` alongside `PropertyStore`.

### Seed Data
`forSaleProperties.json` is pre-populated with the Cozumel house:
- Name: to be set (e.g. "Cozumel House")
- Listing URL: `https://cozumelhomes.net/en/4134544/cozumel-house-for-sale1`
- Asking price, description, notes: left blank for Kelley to fill in

## Sidebar
`SidebarView` gets a second `Section` below rentals, labeled "For Sale":
- Each `ForSaleProperty` is a `NavigationLink` row showing `property.name`
- Toolbar `+` button in this section opens `AddForSalePropertySheet`
- Swipe/right-click delete removes from `ForSaleStore`
- Selecting a row loads `ForSaleInspectorView` in the detail column
- The two sections (rentals, for sale) are fully independent — their add/delete actions do not interfere

## Inspector View
New file: `CozumelManager/Views/ForSaleInspectorView.swift`

Layout mirrors `PropertyInspectorView`:
- **Name** — text field at top
- **Asking Price** — numeric field, displayed as formatted USD currency
- **Listing URL** — text field with adjacent "Open in Browser" button (`NSWorkspace.shared.open(url:)`)
- **Description** — multiline `TextEditor`
- **Notes** — multiline `TextEditor` below description
- **Photos** — same photo grid/picker pattern as rental inspector

No status field — presence in this section implies the property is for sale.

Changes bind directly to `ForSaleStore` (live binding, same pattern as rental inspector).

## Add Sheet
New file: `CozumelManager/Views/AddForSalePropertySheet.swift`

Minimal: name (required) and asking price (required) to create. All other fields editable in the inspector afterward.

## New Files Summary
| File | Purpose |
|---|---|
| `Models/ForSaleProperty.swift` | ForSaleProperty model |
| `Models/ForSaleModel.swift` | ForSaleStore (ObservableObject) |
| `Views/ForSaleInspectorView.swift` | Detail/edit panel |
| `Views/AddForSalePropertySheet.swift` | Add sheet |
| `forSaleProperties.json` | Bundled data, pre-seeded with Cozumel house |

## Modified Files
| File | Change |
|---|---|
| `CozumelManagerApp.swift` | Instantiate + inject `ForSaleStore` |
| `SidebarView.swift` | Add "For Sale" section |

## Out of Scope
- Agent/contact info
- Sale status (Active / Under Contract / Sold)
- Integration with rental revenue calculations
