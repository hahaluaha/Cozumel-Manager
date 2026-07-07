# Booking Request & Approval Workflow

**Date:** 2026-07-07
**Status:** Approved (Kelley reviewed and approved the design)
**Scope:** Website request-to-book flow, WordPress data model, sync daemon extension, Mac app "Booking Requests" section, and server-side Stripe invoicing endpoint

---

## Overview

Guests do not get instant-confirm checkout. They submit a **Request to Book** on a property page; Kelley reviews and approves or denies every request manually from a new section in the Mac app, which already owns the pricing logic needed to build an invoice. This replaces the instant-confirm model originally described in the companion-website roadmap's Plan C.

This design deliberately updates/supersedes CLAUDE.md's "no guest messaging" instruction and the companion-website spec's "guest messaging or automated responses" out-of-scope line — treat as an intentional, agreed exception (automated payment-link/status emails on the approval path only). Still no auto-booking — every request requires Kelley's manual approval, and no auto-routing or staff-scheduling features are added.

### Flow

1. Guest picks dates on a rental property page and submits a Request to Book form.
2. New WordPress `booking-request` custom post type stores the request. The Python sync daemon (Plan B, not yet built) polls WordPress for new requests, relays them to a local JSON file the Mac app watches, and fires an AppleScript-triggered iMessage alert to Kelley (heads-up only — she never approves/denies from Messages).
3. Kelley reviews and acts from a new "Booking Requests" section in the Mac app.
4. **Approve:** app auto-calculates an itemized invoice from existing pricing data (including Nah Ha 101's guest-tiered pricing), editable by Kelley. She sends it; the app calls a small server-side endpoint on the future Hostinger VPS to create a Stripe Payment Link. The daemon relays the link back to WordPress, which emails it to the guest automatically.
5. **Deny:** not automatic. The Mac app opens a blank, editable Mail.app draft addressed to the guest — no auto-suggested alternative dates/properties. Kelley writes the decline personally.
6. Once paid, dates block across website, Airbnb (existing iCal sync), and the Mac app.

### Pricing display

Kelley's site shows one single all-inclusive nightly price (Mexican IVA and Airbnb's host-side cut are already baked in). No itemized tax breakdown on the guest-facing side — matches her existing Lodgify site. The invoice Kelley builds internally in the Mac app *is* itemized (see Mac App UI below); only the guest-facing display stays as one number.

### Security decisions (settled, do not relitigate without new info)

- **Stripe secret key never embedded in the Mac app.** Sparkle auto-update pulls from a public GitHub appcast, so the `.app` bundle is effectively public and reverse-engineerable. The actual Stripe API call happens server-side, on the VPS endpoint; the Mac app only POSTs reviewed line-item data over HTTPS and gets back a payment link URL.
- WordPress Application Password for the daemon: dedicated low-privilege WP user (not admin), `chmod 600` on the local config file, outside any cloud-synced folder, never in git.

---

## Data Model — `booking-request` WordPress CPT

Guest-submitted fields: full name, email, state, country, property, dates, guest count, notes/amenities-preference. **No phone number field** — explicit choice by Kelley and Fernando.

Internal tracking fields (flat post-meta on the same CPT — not a separate linked entity, since the relationship is 1:1):

- `status`: enum — `pending → approved → invoiced → paid`, or `denied`. A hold sub-state is tracked alongside status (see Overlap Handling below) rather than as a separate top-level value.
- `invoice_amount`
- `invoice_line_items` (JSON — nightly rate × nights, guest-tier fees, any manual adjustments Kelley made)
- `stripe_payment_link`
- `stripe_payment_status`
- `hold_expires_at` — timestamp set when a request enters `approved`; the daemon compares this against the current time each poll cycle and reverts `status` to `pending` (clearing this field) once it's passed and payment hasn't landed. See Overlap Handling below.

No guest-facing status page or login. The guest's only signal is email: a "request received" confirmation on submit, then either the payment link email (approved) or Kelley's manual decline email (denied).

---

## Sync Daemon Extension

Builds on the existing Plan B daemon (Python 3 + `watchdog`, runs as a macOS launchd service on Kelley's Mac). That daemon currently only pushes outbound (Mac → WordPress) for properties/for-sale listings; booking requests need bidirectional sync.

**Inbound (WordPress → Mac), polling:**
- Every 5 minutes, poll WordPress for new `pending` booking-request posts.
- Write the full set of requests to a local `booking-requests.json` (single file, array of requests — same pattern as the existing `properties.json`, not one-file-per-request).
- On any new pending request, fire an AppleScript-triggered iMessage to Kelley: a minimal heads-up only — `"New booking request: [Property] – [dates] – [guest name]. Check the app."` No links, no action buttons; Messages is never an action channel.

**Mac app file watching:**
- Watches `booking-requests.json` via `DispatchSource.makeFileSystemObjectSource`, reloading on write. No internal polling timer in the app.

**Outbound (Mac → WordPress), on local change:**
- Daemon watches `booking-requests.json` for status changes (Kelley's approve/deny/invoice actions in the Mac app) and pushes them back to WordPress via REST API.
- WordPress fires the guest email on that update (payment link on `invoiced`, nothing automated on `denied` — see below).

**Deny path specifics:** the Mac app opens a pre-addressed, blank-body Mail.app draft for Kelley to write and send herself, entirely outside the daemon/WordPress pipeline. The Mac app still marks the request `denied` locally so the daemon syncs that status to WordPress and closes out the post, even though the actual email bypassed WordPress.

---

## Mac App — "Booking Requests" Section

**Navigation:** a new top-level section reached via the nav bar planned for Phase 1 of the roadmap (Properties and Booking Requests become sibling sections). This makes the nav-bar work a **prerequisite** for this feature, not parallel to it — sequence accordingly when writing the implementation plan.

**List view:** pending requests float to the top, oldest-pending first, each with a status badge. Approved/invoiced/paid/denied requests sink below, most recent first.

**Detail screen:** guest's submitted fields (name, email, state, country, property, dates, guest count, notes) plus a live availability check against the property's synced blocked dates. If the requested dates conflict with another approved/held/paid request, the screen shows a clear conflict warning before Kelley acts.

**Approve → invoice editor:** auto-fills itemized line items (nightly rate × nights, guest-tier fees via `Property.nightlyRate(forGuests:)`) into an editable table. Kelley can adjust quantities/amounts or add a line; the total recalculates live. She sends from here, which triggers the VPS endpoint call.

---

## Server-Side Stripe Endpoint

A small authenticated endpoint on the future Hostinger VPS. The Mac app POSTs reviewed line-item data over HTTPS; the endpoint creates the actual Stripe Payment Link (Stripe secret key lives only here, never in the app) and returns the link URL.

**Auth:** static API key, following the existing secrets pattern — lives in `Config/Secrets.xcconfig` → Info.plist → sent as an HTTP header. This is technically extractable from the shipped binary (same caveat as the Stripe-key-never-in-app decision), but this is a low-value target: worst case of a leaked key is someone generating spurious Stripe payment links, not a real financial exposure. Consistent with how other secrets already flow through this app.

---

## Overlap Handling (Soft Hold)

Because approval isn't instant payment, two guests could request overlapping dates before either is resolved.

- When Kelley approves a request, those dates immediately get a **soft hold** (synced via the daemon), so any other pending request overlapping those dates shows a conflict warning on its detail screen.
- The hold auto-expires after **48 hours** if the invoice remains unpaid. On expiry: status reverts to `pending`, the hold releases, and the daemon fires a second iMessage alert to Kelley so she knows it lapsed. Nothing is auto-denied — consistent with deny never being automatic.

---

## Error Handling

- **VPS/Stripe endpoint call fails** (network error, VPS down, Stripe API error) when Kelley sends an invoice: app shows a clear error alert, the invoice stays editable/unsent, status stays `approved` (not `invoiced`). No partial state, no guest-facing side effect. Kelley just retries.
- **Daemon can't reach WordPress** when relaying Kelley's approve/deny: the Mac app's local `booking-requests.json` is the source of truth and already reflects her decision the moment she acts (optimistic local update) — she is not blocked. The daemon keeps retrying the WordPress push on its normal 5-minute poll cycle until it succeeds. The guest email is simply delayed until WordPress is reachable again; no special "sync pending" UI.

---

## Testing

- Unit tests for the invoice line-item calculation (reusing `Property.nightlyRate(forGuests:)`) and status-transition logic.
- Manual end-to-end walkthrough on local WordPress + Stripe test-mode keys before going live: submit a test request → confirm the daemon picks it up and the iMessage fires → approve in the app → confirm WordPress updates → confirm the test payment link works → confirm paid status flows back through the daemon to the app. Switch to live Stripe keys only after this passes.

---

## Out of Scope

- **Custom availability calendar / Airbnb iCal two-way sync.** The companion-website spec originally planned this via the MotoPress Hotel Booking plugin. Per Fernando's standing preference to avoid WordPress plugins where feasible (bloat/vulnerability risk, learned from a prior 10-year experience running a dive/snorkel business site), this needs a custom-built replacement — its own design session, separate from this spec. This spec depends on it only at the interface level: an availability data source keyed by property, returning blocked-date ranges, consumed by (a) the guest-facing Request to Book date picker and (b) the Mac app's live conflict check on the detail screen.
- Guest-facing status lookup/login.
- Auto-suggesting alternative dates/properties on denial.
- Any auto-booking, auto-routing, guest messaging beyond the approval-path emails explicitly designed here, or staff scheduling (per CLAUDE.md).
- Reporting/analytics on response times (a simple status enum was chosen over status + timestamps).
