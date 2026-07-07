# Booking Request & Approval Workflow

**Date:** 2026-07-07
**Status:** Approved (Kelley reviewed and approved the design)
**Scope:** Website request-to-book flow, WordPress data model, sync daemon extension, Mac app "Booking Requests" section, and WordPress-side Stripe invoicing

---

## Overview

Guests do not get instant-confirm checkout. They submit a **Request to Book** on a property page; Kelley reviews and approves or denies every request manually from a new section in the Mac app, which already owns the pricing logic needed to build an invoice. This replaces the instant-confirm model originally described in the companion-website roadmap's Plan C.

This design deliberately updates/supersedes CLAUDE.md's "no guest messaging" instruction and the companion-website spec's "guest messaging or automated responses" out-of-scope line — treat as an intentional, agreed exception (automated payment-link/status emails on the approval path only). Still no auto-booking — every request requires Kelley's manual approval, and no auto-routing or staff-scheduling features are added.

### Flow

1. Guest picks dates on a rental property page and submits a Request to Book form.
2. New WordPress `booking-request` custom post type stores the request. The Python sync daemon (Plan B, not yet built) polls WordPress for new requests, relays them to a local JSON file the Mac app watches, and fires an AppleScript-triggered iMessage alert to Kelley (heads-up only — she never approves/denies from Messages).
3. Kelley reviews and acts from a new "Booking Requests" section in the Mac app.
4. **Approve:** app auto-calculates an itemized invoice from existing pricing data (including Nah Ha 101's guest-tiered pricing), editable by Kelley. She sends it; the app writes the reviewed line items locally and the daemon relays them to WordPress on its next poll. Custom WordPress-side code creates the Stripe Payment Link and emails it to the guest automatically; the daemon relays the resulting link/status back down to the Mac app. This hop is asynchronous — see Stripe Link Creation below.
5. **Deny:** not automatic. The Mac app opens a blank, editable Mail.app draft addressed to the guest — no auto-suggested alternative dates/properties. Kelley writes the decline personally.
6. Once paid, dates block across website, Airbnb (existing iCal sync), and the Mac app.

### Pricing display

Kelley's site shows one single all-inclusive nightly price (Mexican IVA and Airbnb's host-side cut are already baked in). No itemized tax breakdown on the guest-facing side — matches her existing Lodgify site. The invoice Kelley builds internally in the Mac app *is* itemized (see Mac App UI below); only the guest-facing display stays as one number.

### Security decisions (settled, do not relitigate without new info)

- **Stripe secret key never embedded in the Mac app, and the Mac app holds no standing credential capable of triggering a Stripe charge/link.** Sparkle auto-update pulls from a public GitHub appcast, so the `.app` bundle is effectively public and reverse-engineerable — nothing in it should be able to reach Stripe. The Stripe API call happens entirely in custom WordPress-side code on the VPS, triggered only via the daemon's existing low-privilege WordPress Application Password (the same credential already used for property sync). The Mac app never talks to Stripe or a Stripe-adjacent endpoint directly. (Revised 2026-07-07 from an earlier draft that had the Mac app calling a separate authenticated VPS endpoint directly — Fernando flagged that a standing API key baked into the shipped binary was an unnecessary credential surface.)
- WordPress Application Password for the daemon: dedicated low-privilege WP user (not admin), `chmod 600` on the local config file, outside any cloud-synced folder, never in git.

---

## Data Model — `booking-request` WordPress CPT

Guest-submitted fields: full name, email, state, country, property, dates, guest count, notes/amenities-preference. **No phone number field** — explicit choice by Kelley and Fernando.

Internal tracking fields (flat post-meta on the same CPT — not a separate linked entity, since the relationship is 1:1):

- `status`: enum — `pending → approved → invoice_sending → invoiced → paid`, or `denied`. `invoice_sending` is the optimistic state set the moment Kelley clicks Send, before WordPress has confirmed the Stripe link was created. A hold sub-state is tracked alongside status (see Overlap Handling below) rather than as a separate top-level value.
- `invoice_amount`
- `invoice_line_items` (JSON — nightly rate × nights, guest-tier fees, any manual adjustments Kelley made)
- `stripe_payment_link`
- `stripe_payment_status`
- `invoice_error` — nullable string, set by WordPress-side code if Stripe link creation fails; the daemon relays it down and the Mac app surfaces it so Kelley can retry. Clears on the next successful send attempt. See Error Handling below.
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
- Daemon watches `booking-requests.json` for status changes (Kelley's approve/deny/invoice-send actions in the Mac app) and pushes them back to WordPress via REST API, including `invoice_line_items` when status is `invoice_sending`.
- WordPress-side custom code (hooked into the REST API update, not a plugin) reacts to a post entering `invoice_sending`: calls Stripe to create the Payment Link, writes `stripe_payment_link`/`stripe_payment_status` and flips `status` to `invoiced` (or, on failure, reverts `status` to `approved` and sets `invoice_error`), and emails the guest on success.
- On the next inbound poll, the daemon picks up whatever WordPress wrote (`invoiced` + link, or `approved` + error) and relays it back down into `booking-requests.json`, which the Mac app reflects. See Error Handling for the failure path.

**Deny path specifics:** the Mac app opens a pre-addressed, blank-body Mail.app draft for Kelley to write and send herself, entirely outside the daemon/WordPress pipeline. The Mac app still marks the request `denied` locally so the daemon syncs that status to WordPress and closes out the post, even though the actual email bypassed WordPress.

---

## Mac App — "Booking Requests" Section

**Navigation:** a new top-level section reached via the nav bar planned for Phase 1 of the roadmap (Properties and Booking Requests become sibling sections). This makes the nav-bar work a **prerequisite** for this feature, not parallel to it — sequence accordingly when writing the implementation plan.

**List view:** pending requests float to the top, oldest-pending first, each with a status badge. Approved/invoiced/paid/denied requests sink below, most recent first.

**Detail screen:** guest's submitted fields (name, email, state, country, property, dates, guest count, notes) plus a live availability check against the property's synced blocked dates. If the requested dates conflict with another approved/held/paid request, the screen shows a clear conflict warning before Kelley acts.

**Approve → invoice editor:** auto-fills itemized line items (nightly rate × nights, guest-tier fees via `Property.nightlyRate(forGuests:)`) into an editable table. Kelley can adjust quantities/amounts or add a line; the total recalculates live. Sending sets local status to `invoice_sending` and hands off to the daemon (see Sync Daemon Extension) — the row shows a "Sending…" indicator until a later poll confirms `invoiced` (with the payment link) or surfaces `invoice_error` for retry.

---

## Stripe Link Creation (WordPress-side)

Stripe Payment Link creation happens entirely in custom PHP on the WordPress site (child theme code, not a third-party plugin — consistent with the standing plugin-avoidance preference), not in the Mac app and not via a separate VPS endpoint.

- Trigger: a booking-request post's `status` transitioning to `invoice_sending` (written by the daemon via the WordPress Application Password it already holds).
- The Stripe secret key lives only in WordPress-side config (e.g. an environment variable or `wp-config.php` constant, outside version control) — never touches the Mac app, the daemon's local config, or git.
- On success: writes `stripe_payment_link` / `stripe_payment_status`, sets `status` to `invoiced`, emails the guest the payment link.
- On failure: sets `invoice_error` with a short message, reverts `status` to `approved` so Kelley can retry from the Mac app.

This removes the standing "create a Stripe link" credential that a separate Mac-app-authenticated endpoint would have required — the only credential capable of triggering Stripe is the daemon's existing low-privilege WordPress Application Password, which never ships inside the app bundle.

---

## Overlap Handling (Soft Hold)

Because approval isn't instant payment, two guests could request overlapping dates before either is resolved.

- When Kelley approves a request, those dates immediately get a **soft hold** (synced via the daemon), so any other pending request overlapping those dates shows a conflict warning on its detail screen.
- The hold auto-expires after **48 hours** if the invoice remains unpaid. On expiry: status reverts to `pending`, the hold releases, and the daemon fires a second iMessage alert to Kelley so she knows it lapsed. Nothing is auto-denied — consistent with deny never being automatic.

---

## Error Handling

- **Stripe link creation fails on the WordPress side** (Stripe API error, misconfiguration): WordPress sets `invoice_error` and reverts `status` to `approved`. The daemon relays this down on its next poll; the Mac app surfaces the error message on the request and lets Kelley retry (re-sending clears the error and re-triggers `invoice_sending`). No guest-facing side effect — no email goes out until a link actually exists.
- **Daemon can't reach WordPress** when relaying Kelley's approve/deny/send: the Mac app's local `booking-requests.json` is the source of truth and already reflects her decision the moment she acts (optimistic local update) — she is not blocked. The daemon keeps retrying the WordPress push on its normal 5-minute poll cycle until it succeeds. The guest email is simply delayed until WordPress is reachable again; no special "sync pending" UI. (A request can sit in `invoice_sending` for longer than usual under this condition — this is expected, not an error state, since there's no synchronous call to time out.)

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
