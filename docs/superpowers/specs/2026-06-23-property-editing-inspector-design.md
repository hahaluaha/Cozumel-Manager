# Property Editing — Inspector Panel

**Date:** 2026-06-23
**Status:** Approved
**Scope:** Group 1 — Property management (prices, availability, photos, add property)

---

## Overview

Add inline property editing to Cozumel Manager via a native macOS inspector panel. Kelley can edit nightly rates, mark date ranges as unavailable, and manage photos for each property without leaving the main window. Changes persist to disk immediately.

---

## Data Model

### Changes to `Property`

- All stored fields change from `let` to `var` to support mutation
- Add `unavailableDateRanges: [DateRange]` — list of blocked date ranges (no type/reason label)
- Add `photos: [URL]` — local file URLs; will become remote URLs when Supabase is wired

### New type: `DateRange`

```swift
struct DateRange: Codable, Identifiable {
    let id: UUID
    var start: Date
    var end: Date
}
```

### Changes to `PropertyStore`

- `update(_ property: Property)` — replaces a property in the array by id, then saves
- `add(_ property: Property)` — appends a new property, then saves
- `saveToDisk()` — writes the full array to Application Support JSON file
- On first launch, copy the bundled `properties.json` to Application Support; read/write from there on all subsequent launches

---

## UI Layout

### Detail Panel (existing, left side)

- Retains current display: name, neighborhood, address, nightly rate, estimated monthly revenue
- Adds a toolbar button (pencil icon, label "Edit") that toggles the inspector open/closed

### Inspector Panel (new, right side)

Uses SwiftUI's `.inspector(isPresented:)` modifier (macOS 14+). Three collapsible sections:

**Details**
Editable fields for: name, neighborhood, address, nightly rate (numeric), status (Picker: active / inactive / maintenance).

**Availability**
List of blocked date ranges. Each row: "Feb 10 – Feb 17" + delete button.
"Add Block" button at bottom opens a popover with start and end DatePickers.
Add button in popover is disabled if end date ≤ start date.
Overlapping ranges are not validated — Kelley manages this manually.

**Photos**
3-column thumbnail grid. "+" button opens `NSOpenPanel` (image files only).
Picked files are copied into Application Support/Photos/<property-id>/ so paths remain valid if originals move.
Clicking a thumbnail shows a remove button overlay.
Missing files show a placeholder thumbnail — no crash.

---

## Adding a New Property

"+" button in the sidebar toolbar opens a creation sheet.
Required fields: name, address, neighborhood, nightly rate.
On "Create": property is added to the store, saved to disk, selected in the sidebar, and the inspector opens automatically.

---

## Data Flow

Inspector holds a `@State var draft: Property` — a local copy of the selected property.
Changes to any field call `store.update(draft)` and `store.saveToDisk()` immediately.
No pending/unsaved state. No explicit Save button for field edits.
Date range add/remove and photo add/remove are explicit tap actions.

**Persistence paths:**
```
properties.json:  ~/Library/Application Support/CozumelManager/properties.json
photos:           ~/Library/Application Support/CozumelManager/Photos/<property-id>/
```

---

## Error Handling

| Scenario | Behavior |
|---|---|
| End date ≤ start date | "Add Block" button disabled |
| Failed disk write | Error alert shown; in-memory state preserved for session |
| Photo file missing from disk | Placeholder thumbnail shown |
| Overlapping date blocks | Both stored and displayed; no conflict detection |

---

## Out of Scope

- Pushing photos to cozumelhomes.net or listing platforms (Group 6)
- User accounts and credentials (Group 4)
- Payment methods (Group 5)
- Auto-updates / Sparkle (Group 2)

---

## Testing

Manual testing via Xcode. No automated tests required for this feature.

Key paths to verify:
- Edit each field, quit and relaunch — changes persist
- Add and remove date blocks
- Add photos, move originals to trash — placeholder appears, no crash
- Add a new property end-to-end
- Inspector opens/closes via toolbar button
