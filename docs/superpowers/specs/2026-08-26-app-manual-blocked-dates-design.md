# Mac App Manual Blocked Dates — Design Spec

**Date:** 2026-08-26
**Status:** Approved, ready for implementation plan
**Repo:** `Cozumel_App_Final` (Mac app only — no `Cozumel-Website` changes)

## Overview

The Mac app already has an "Add Block" feature in `PropertyInspectorView`
(Availability section) that lets Fernando or Kelley block date ranges on a
rental property. It has never worked end-to-end: `WordPressSyncService`
never sent `unavailableDateRanges` to WordPress, so blocking a date in the
app has always been a no-op as far as the live site and Airbnb are
concerned. The only way to block a non-Airbnb date today is wp-admin's
`manual_blocked_dates` textarea (added in
[[ical_three_way_sync]]/2026-08-14-airbnb-calendar-sync-design.md) — a tool
Kelley does not use and the app exists specifically to keep her out of.

This surfaced from a real scenario: Kelley and Fernando are often in
different locations, and a manual/off-Airbnb booking (e.g. a cash deal, a
family friend) needs its dates blocked immediately, without depending on
Fernando being reachable or Kelley touching wp-admin.

**Key finding that shapes this design:** `manual_blocked_dates` is already
a normal, REST-writable `rental-property` post meta field (no
`auth_callback` lock, unlike `airbnb_blocked_dates`), and the existing
calendar-sync cron already merges it into both the outbound `.ics` Airbnb
imports and the `/wp-json/cozumel/v1/availability/<id>` endpoint the
public calendar widget reads. **No WordPress/theme changes are needed.**
This is a Mac-app-only change that plugs into infrastructure that already
works.

## Goals

- Kelley or Fernando can block a date range for a property directly in the
  app, with an optional short note (reason), and have it become visible to
  guests on the website's own availability calendar immediately upon sync.
- The same block should also reach Airbnb's calendar (subject to the
  existing hourly-cron + Airbnb-polling latency already accepted for the
  Airbnb→site direction).
- Adding or removing a block triggers a sync automatically — this is a
  double-booking-prevention feature, so waiting for a manual "Sync to
  Website" click defeats the purpose.
- A failed auto-sync (offline, missing credentials, API error) must be
  visibly surfaced, never silent — the block is still saved locally, but
  the user must know it has not reached the website yet.

## Non-Goals

- No changes to `Cozumel-Website` theme code, WP-CLI cron, or the REST
  endpoints — all reused as-is.
- No general "auto-sync everything" change. Every other field (rentals and
  for-sale) keeps the existing manual "Sync to Website" model. Auto-sync is
  scoped specifically to the add/remove-block action.
- No conflict detection/warning if a manual block overlaps an
  Airbnb-sourced block — the server-side merge is a simple union, an
  overlap is harmless redundancy, not an error.
- No mechanism to force an immediate cron run / immediate Airbnb-side
  republish. Airbnb-direction latency is unchanged from what
  2026-08-14-airbnb-calendar-sync-design.md already ships and accepts.

## Data Model Change

`DateRange` (`CozumelManager/Models/Property.swift`) gains one optional
field:

```swift
struct DateRange: Codable, Identifiable {
    var id: UUID
    var start: Date
    var end: Date
    var note: String?   // new — nil-default, old persisted data decodes unaffected
}
```

## UI Change

`PropertyInspectorView.swift`, Availability section — extends the existing
"Add Block" popover and list, no new screens:

- The "Add Block" popover gains one optional text field for a short note
  (e.g. "Family friend — cash booking", "Maintenance").
- Each row in the existing blocked-dates list shows the note beneath the
  date range when present.
- Deleting a block (existing trash-icon button) is unchanged except that it
  now also triggers auto-sync (see below).

## Sync Change

`WordPressSyncService.syncRentals` gains one meta key:

```swift
meta["manual_blocked_dates"] = jsonEncodedRanges(property.unavailableDateRanges)
// [{"start":"YYYY-MM-DD","end":"YYYY-MM-DD","note":"..."}]
```

This field is **exempt from the blank-guard** added in the
2026-08-26 sync-clobbering fix (commit `1d77e67`). Every other guarded
field treats a blank local value as "not managed by the app, don't touch
WordPress" — but for `manual_blocked_dates`, the app is the sole owner
once this ships. An empty array is a meaningful, real state ("no manual
blocks right now") and must actively overwrite/clear whatever is on
WordPress, not be omitted. This is intentional and asymmetric with the
rest of `syncRentals` — call this out explicitly in the implementation so
it isn't "fixed" to match the other fields by mistake later.

`note` travels in the JSON for the app's own display; the WordPress-side
merge logic (`cli-sync-calendars.php`, `rest-availability.php`) only reads
`start`/`end` and ignores unknown keys, so no server-side change is
required for the extra field to pass through harmlessly.

## Auto-Sync Trigger

Adding a block (the "Add" button in the popover) and removing a block (the
trash-icon button on an existing row) each call the existing sync path
immediately after `commit()` — the same `WordPressSyncService` flow the
toolbar's "Sync to Website" button already uses, just invoked
programmatically instead of waiting for the user.

## Error Handling

If the triggered sync fails (no `WordPressSyncCredentialsStore` value on
this Mac, no network, WordPress API error):

- The block change still saves locally — `store.update(draft)` already
  succeeded before the sync call, local data is never lost.
- Show a visible, non-blocking inline warning in the inspector (e.g. "Saved
  locally — not yet synced to the website. Try Sync to Website again once
  you're online.") rather than failing silently. Silent failure is
  unacceptable here specifically because the entire point of this feature
  is preventing a double-booking.

## Data Flow

1. Kelley (or Fernando) adds/removes a block in the app →
   `store.update(draft)` persists locally immediately.
2. App triggers sync for that property automatically.
3. `WordPressSyncService` PATCHes `rental-property/<id>` with the full
   current `manual_blocked_dates` JSON array (whole-array replace, same
   pattern `airbnb_blocked_dates` already uses on the inbound side).
4. **Website's own guest-facing calendar:** updates immediately —
   `rest-availability.php` reads `manual_blocked_dates` live from postmeta
   on each request, not from a cron-cached value.
5. **Airbnb's calendar:** updates on the existing hourly-cron cadence —
   next `wp cozumel sync-calendars` run merges the new manual ranges into
   the outbound `.ics`, then Airbnb applies its own polling delay before
   reflecting it in their UI. This latency already exists today for
   Airbnb-sourced blocks reaching the site; this change doesn't add a new
   weak point, just uses the same accepted path in the other direction.

## Testing Plan

- **Model:** `DateRange` with `note: nil` still decodes existing persisted
  JSON (regression test against current `properties.json` shape).
- **Sync payload:** unit test (extending
  `WordPressSyncServiceTests.swift`) — a property with N blocked ranges
  produces the correct `manual_blocked_dates` JSON string; a property with
  zero ranges still sends `"[]"` rather than omitting the key (proves the
  blank-guard exemption is correct and won't regress to the omit-if-empty
  behavior the rest of `syncRentals` uses).
- **Auto-sync trigger:** unit test that adding/removing a block invokes
  the sync call exactly once, without requiring a separate manual "Sync to
  Website" click.
- **Failure path:** unit test that a failed sync (mock client returns an
  error) still leaves the local block saved and surfaces the warning
  state, rather than silently discarding the change or crashing.
- **Manual end-to-end, once implemented:** add a block with a note in the
  app, confirm it appears within `rest-availability.php`'s response
  immediately, confirm it appears on the rental's public page calendar,
  and — after the next hourly cron run — confirm it appears in the
  generated outbound `.ics` file.

## Dependencies / Prerequisites

- Each Mac (Fernando's and Kelley's) needs valid WordPress sync
  credentials already saved via "Website Sync Settings…" (toolbar → Sync
  menu) — this is per-machine Keychain storage
  (`WordPressSyncCredentialsStore`, `ThisDeviceOnly`), not shared or
  synced between machines. Confirming Kelley's Mac has this configured is
  a prerequisite for her to use this feature, independent of any code
  change here.
- Requires a new app build + Sparkle release before Kelley's copy can use
  this — same as any other app change.

## Relationship to Other Work

Directly follows the 2026-08-26 sync-clobbering fix (commit `1d77e67`,
`WordPressSyncService.swift` blank/zero guards on `syncForSale`/
`syncRentals`). This spec's `manual_blocked_dates` field is the one
deliberate exception to that guard, so implementers should read that
commit's guard logic before touching `syncRentals` again.

Builds directly on 2026-08-14-airbnb-calendar-sync-design.md
([[ical_three_way_sync]]) — reuses its `manual_blocked_dates` field, its
buffer/merge logic, its outbound `.ics` pipeline, and its REST
availability endpoint without modification. That spec explicitly left "Mac
app changes" as future/out of scope and named this exact field as the
hook for it — this spec is that follow-up.
