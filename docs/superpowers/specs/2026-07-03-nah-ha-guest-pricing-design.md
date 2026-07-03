# Nah Ha 101 — Guest-Tiered Pricing

**Date:** 2026-07-03
**Status:** Approved
**Scope:** Guest-count pricing reference for Cozumel's Nah Ha Condominium 101 only

---

## Overview

Nah Ha 101 prices differently than the other two properties: $325/night covers up to 2 guests, and each additional guest (3rd through 6th) adds $25/night. Add editable fields for this so Kelley can look up the correct nightly quote in the app, and update the property's nightly rate to reflect the 2-guest base price.

This is reference pricing only — the app has no booking or guest-count tracking, so nothing recalculates automatically against a live reservation.

---

## Data Model

### Changes to `Property`

Add three optional fields, following the existing `monthlyPrice` optional pattern (decoded with `try?` so properties without these keys — i.e. every property except Nah Ha 101 — decode cleanly to `nil`):

```swift
var baseGuests: Int?       // guests included in baseRate
var maxGuests: Int?        // upper bound on guest-tier pricing
var extraGuestFee: Double? // added per night per guest beyond baseGuests
```

CodingKeys: `base_guests`, `max_guests`, `extra_guest_fee`.

### `baseRate` semantics for Nah Ha 101

`baseRate` changes from 425 to 325 — it now represents the 2-guest nightly rate. It continues to drive the dashboard "$/night" display and `monthlyRevenue` (`baseRate × 22`, unless `monthlyPrice` override is set) exactly as it does today. No changes needed to `monthlyRevenue` or dashboard code.

### New computed helper

```swift
func nightlyRate(forGuests guests: Int) -> Double {
    guard let baseGuests, let extraGuestFee, guests > baseGuests else { return baseRate }
    let extra = min(guests, maxGuests ?? guests) - baseGuests
    return baseRate + Double(extra) * extraGuestFee
}
```

Used only to compute the summary line in the inspector (see below). Not wired into revenue forecasting.

---

## UI Layout

### Inspector — new "Guest Pricing" section

In `PropertyInspectorView`, add a `Section("Guest Pricing")` that renders **only when `draft.id == "prop-003"`** (Nah Ha 101's id — checked by id, not name, since name is editable via the Details section and would make a name-based check unstable).

Fields, following the existing `LabeledContent` + `TextField` + `.onSubmit { commit() }` pattern:

- **Base Guests** — Int TextField, bound via a `baseGuestsBinding` (nil ↔ 0, same nil-coalescing pattern as `monthlyPriceBinding`)
- **Max Guests** — Int TextField, same binding pattern
- **Extra Guest Fee** — currency TextField, same binding pattern

Plus a read-only derived summary `Text`, computed from `draft`:

> "Up to 2 guests: $325/night. 3–6 guests: +$25/guest (up to $450/night at 6)."

The existing "Nightly Rate" field in the Details section continues to edit `baseRate` — no duplicate field for the 2-guest rate.

---

## Data Flow

No changes to `PropertyStore.update`/`saveToDisk` — the new fields ride along with the existing `Property` struct through the same commit path already used by every other field in the inspector.

---

## Seed Data

Update `properties.json` for `prop-003`:

```json
"base_rate": 325.0,
"base_guests": 2,
"max_guests": 6,
"extra_guest_fee": 25.0
```

---

## Migration Caveat

Kelley's already-installed build has its own `properties.json` inside the sandbox container (`~/Library/Containers/Team-Paraiso.CozumelManager/Data/Library/Application Support/CozumelManager/properties.json`). `PropertyStore` only copies the bundled seed file on first launch, when no file exists yet — it will **not** overwrite her existing file. After this update ships, she'll need to manually update Nah Ha 101's Nightly Rate to 325 and fill in the three new guest-pricing fields once, in the app. No automatic migration is planned; consistent with the app having no existing migration system.

---

## Out of Scope

- Guest-count tracking tied to actual bookings/reservations (app has no booking system — see CLAUDE.md: no auto-booking)
- Applying guest-tier pricing logic to `monthlyRevenue` or any forecast calculation
- Extending guest-tiered pricing to other properties (fields exist generally on the model, but UI is hard-restricted to Nah Ha 101's id)

---

## Testing

Manual testing via Xcode. No automated tests required.

Key paths to verify:
- Guest Pricing section appears only for Nah Ha 101, not the other two properties
- Edit Base Guests, Max Guests, Extra Guest Fee — quit and relaunch, changes persist
- Summary line updates correctly as fields change
- Nightly Rate field still edits `baseRate` and reflects on the dashboard
- Existing properties (prop-001, prop-002) decode fine with the new fields absent from their JSON
