# Mac App → WordPress Sync (Plan B) — Design Spec
Date: 2026-07-27

## Overview
Add a one-way sync from the Mac app (`CozumelManager`, source of truth for property data) to the companion WordPress site (`cozumel-homes.local`, theme `wp-content/themes/cozumel-homes`). Today, properties created/edited in the Mac app must be re-entered by hand in wp-admin; `mac_id` post meta already exists on both `rental-property` and `forsale-property` specifically to support a future sync matching a WP post back to its Mac-app record, but no sync mechanism has been built yet.

This spec covers both rentals and the for-sale listing, triggered by a single manual "Sync to Website" button in the Mac app — no background daemon, no automatic-on-save behavior, no two-way sync.

## Sync Direction & Trigger
- **One-way**: Mac app → WordPress only. WordPress is never read back into the Mac app.
- **Manual trigger**: one global "Sync to Website" button (sidebar toolbar, alongside existing add/delete controls) syncs every rental and for-sale property in a single pass — not a per-property action.
- **Target**: `http://cozumel-homes.local` only, for now. The dev-only Application Passwords override (`inc/dev-application-passwords.php`) only activates for that exact host, so production sync is out of scope until Hostinger launch defines a real URL + HTTPS auth story.
- **HTTPS requirement for production**: local dev sync sends Basic Auth (the Application Password, base64-encoded, not encrypted) over plain HTTP — acceptable only because `cozumel-homes.local` is loopback traffic that never leaves this Mac. When sync is extended to the production Hostinger URL, it **must** run over HTTPS; plain-HTTP Basic Auth against a real public host would expose the Application Password on the wire. This requirement carries forward into whatever production-sync work follows this spec.

## New Component: `WordPressSyncService.swift`
A new service in the Mac app, added alongside the existing `PropertyStore`/`ForSaleModel`. Responsibilities:
1. Read the stored site URL, WP username, and Application Password from Keychain.
2. For each post type (`rental-property`, `forsale-property`), `GET` all posts (small counts, no pagination needed — 3 rentals + 1 for-sale today).
3. Match each Mac-app property to a WP post by comparing `Property.id` / `ForSaleProperty.id` against the post's `mac_id` meta.
4. Matched → `PATCH` the WP post's mapped fields (see Field Mapping below).
5. Unmatched → `POST` a new WP post of the correct type, status **draft**, with `mac_id` set to the app's id and the mapped fields populated.
6. Collect a per-property result (created / updated / failed + reason) and return it to the UI for display — one property's failure does not stop the rest.

Auth is HTTP Basic (`username:application_password`), the same mechanism already used for all manual REST calls against this site during this session (media uploads, gallery sync, coordinate updates).

## Credential Storage
A new "Website Sync" settings UI (site URL, WP username, Application Password fields) lets Fernando/Kelley paste an Application Password once. On save, it's written to macOS Keychain — never to `properties.json`, never hardcoded in source. This mirrors how Sparkle's signing key and other secrets are already kept out of the repo (see `CLAUDE.md`'s Secrets Management section).

## Field Mapping

### Rentals (`Property` → `rental-property`)
| Mac app field | WP field | Notes |
|---|---|---|
| `id` | `mac_id` | Match key |
| `name` | post title | |
| `neighborhood` | `neighborhood` meta | |
| `address` | `address` meta | |
| `baseRate` | `base_rate` meta | |
| `status` | `status` meta | String value written as-is (`active`/`inactive`/`maintenance`); WP post itself stays **published** regardless — see Status Mapping below |
| `maxGuests` | `max_guests` meta | |

Not synced (WP-only, set manually in wp-admin, unaffected by sync): `bedrooms`, `bathrooms`, `latitude`, `longitude`, `airbnb_ical_url`, `airbnb_listing_url`, `gallery_ids`. None of these have a source of truth in the Mac app's `Property` model today.

### For-sale (`ForSaleProperty` → `forsale-property`)
| Mac app field | WP field | Notes |
|---|---|---|
| `id` | `mac_id` | Match key |
| `name` | post title | |
| `description` | post content | |
| `askingPrice` | `asking_price` meta | |
| `listingURL` | `listing_url` meta | |
| `notes` | `notes` meta | |

Not synced (WP-only): `bedrooms`, `bathrooms`, `latitude`, `longitude`, `gallery_ids`. Same reasoning — no app-side source.

`monthlyPrice`, `baseGuests`, `extraGuestFee`, `unavailableDateRanges`, `photos`, `videoURL` (rentals) and `photos`, `videoURL` (for-sale) are also not synced this pass — see Out of Scope.

## New-Post Behavior
When a Mac-app property has no matching `mac_id` on the WordPress side, sync creates a new post of the correct type as a **draft** (never auto-published). A freshly created listing has no photos, no lat/long, and no Airbnb info yet — publishing it live immediately would show an incomplete page. Kelley/Fernando review and manually publish from wp-admin once it's ready.

## Status Mapping
A Mac-app property with `status: inactive` or `status: maintenance` still leaves its WordPress post **published**; only the `status` meta field updates. Sync does not unpublish/draft an existing live post — visibility logic (if ever needed) is a separate template-level concern, not something this sync mechanism controls. This avoids surprise 404s on any page or link already pointing at that property.

## Error Handling
Sync attempts every property in the pass regardless of individual failures (auth errors, network issues, one bad field). After the pass, the Mac app shows a per-property result list, e.g.:
```
Nah Ha 101: updated
Casa Bohemia: updated
Cool Caribbean Views: updated
New Listing: created as draft
Cozumel House for Sale: failed — 401 Unauthorized
```

## Verification
No existing automated test target covers WordPress integration. Verification is manual, following the same pattern already used ad hoc this session:
- Run sync against `cozumel-homes.local` with valid Keychain credentials; confirm each existing property's WP post fields update to match the Mac app.
- Add a new property in the Mac app with no corresponding WP post; run sync; confirm a new draft post is created with the correct `mac_id` and fields.
- Revoke/corrupt the stored Application Password; run sync; confirm the per-property result list reports failures without crashing or partially applying.
- Confirm an `inactive` property's WP post remains published after sync (only `status` meta changes).
- Confirm fields explicitly out of scope (bedrooms, lat/long, Airbnb URLs, photos) are untouched by a sync run that follows a manual wp-admin edit to those same fields.

## Out of Scope
- Two-way sync (WordPress → Mac app). Direction is one-way only for this pass.
- Photo/video upload to the WordPress media library — `gallery_ids` and featured images stay manually managed, same as today.
- Production sync (Hostinger URL, HTTPS Application Password auth) — deferred until Hostinger launch.
- Deleting a WordPress post when its Mac-app property is removed — sync only creates/updates, never deletes.
- `bedrooms`, `bathrooms`, `latitude`, `longitude`, `airbnb_ical_url`, `airbnb_listing_url` — no source of truth for these in the Mac app's current data model; stay manually managed in wp-admin as they are today.
- Automatic/scheduled sync — trigger is the manual button only.
