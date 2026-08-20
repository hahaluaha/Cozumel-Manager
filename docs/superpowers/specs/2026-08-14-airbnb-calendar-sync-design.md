# Airbnb Calendar Sync + Public Availability Calendar — Design Spec

**Date:** 2026-08-14
**Status:** Approved, ready for implementation plan
**Repo:** `Cozumel-Website` (theme code + VPS deployment); this spec lives in `Cozumel_App_Final`

## Overview

Kelley currently manages availability manually across her booking channels.
Without automated sync, a booking made on one channel (e.g. Airbnb) doesn't
block those dates anywhere else, risking double-bookings. This was originally
scoped as a three-way sync (Lodgify + Airbnb + Mac app), but two decisions
made during design collapsed the scope:

1. Kelley's Lodgify account has a direct, real-time connection to Airbnb
   already — Lodgify was never the actual source of truth, Airbnb is.
2. Kelley is canceling her Lodgify subscription on **2026-08-18**. Building
   an integration against a platform being canceled in 4 days would be
   throwaway work.

**This spec targets Airbnb directly, not Lodgify.** The Mac app is
explicitly out of scope for this project (see Out of Scope) — the original
three-way framing is superseded.

A second requirement surfaced during design and is now in scope: potential
guests need to **see** availability on the website itself (not just have it
enforced server-side), and every booking needs a **1-day cleaning buffer**
before the next check-in, enforced consistently everywhere availability is
computed or published.

## Goals

- Keep availability in sync between Airbnb and the website, one property at
  a time, for the 3 rental properties (Nah Ha 101, Cool Caribbean Views,
  Casa Bohemia). **The for-sale property is excluded** — it has no nightly
  availability concept.
- Show a real, visible availability calendar on each rental property's page.
- Enforce a 1-day cleaning buffer between any two bookings, reflected
  everywhere: the public calendar, future request validation, and what gets
  published back out to Airbnb.
- No new always-running service. Reuse the existing VPS, existing WordPress
  Application Password auth pattern, existing SMTP.

## Architecture

- **Sync engine:** a WP-CLI custom command (`wp cozumel sync-calendars`)
  added to the `cozumel-homes` theme (`inc/cli-sync-calendars.php`, loaded
  only when `WP_CLI` is defined). No Python, no separate daemon — consistent
  with how Plan B's property-data sync works (direct, synchronous, no
  background process).
- **Trigger:** a real system cron entry on the VPS (`crontab` for the
  `deploy` or `www-data` user — TBD at implementation time), **not**
  WordPress's pageview-triggered pseudo-cron (`wp-cron.php`), which is too
  unreliable for a low-traffic, request-only site that may go hours between
  visits.
- **Cadence:** hourly. Matches Airbnb's own stated import-refresh cycle
  (2–4 hours) closely enough that faster polling wouldn't gain anything —
  the bottleneck is Airbnb's refresh, not ours.

## Data Flow

### Inbound (Airbnb → WordPress), every run
1. Cron fires `wp cozumel sync-calendars`.
2. For each of the 3 rental posts, fetch its stored Airbnb iCal **export**
   URL (Airbnb: Listings → select listing → Availability → Calendar →
   Calendar sync → Export calendar), parse `VEVENT` blocks into date ranges.
3. Overwrite `airbnb_blocked_dates` post meta with the fresh JSON array
   (full replace, not a diff/merge — Airbnb's feed is the full source of
   truth for that leg).

### Buffer computation (shared logic, used by both outbound + public display)
1. Take the union of `airbnb_blocked_dates` + `manual_blocked_dates` (new
   meta field, Kelley/Fernando-edited in wp-admin) + (later) approved
   booking-request dates once that project exists.
2. Pad every resulting range by 1 day after checkout, producing the actual
   "unavailable" set used everywhere below.

### Outbound (WordPress → Airbnb), same run
1. Generate a standard `.ics` file per property from the buffered
   unavailable set above.
2. Write it to `wp-content/uploads/calendars/<property-slug>.ics`, publicly
   reachable.
3. Airbnb's own **Calendar sync → Import calendar** field (pasted once,
   manually, by Fernando, per listing) polls that URL on its own 2–4 hour
   cycle. Nothing pushed — Airbnb pulls.

This means the buffer day is enforced on Airbnb's side too — a guest
can't book the day immediately after one of our approved stays checks out,
even directly through Airbnb's own booking flow.

## Public Availability Calendar

- New **interactive** calendar widget on each rental property's single page
  (`single-rental-property.php`), placed directly above the existing
  "Request to Book" inquiry form.
- Fed by a new WP REST endpoint, e.g. `/wp-json/cozumel/v1/availability/<property_id>`,
  returning the same buffered unavailable-date set computed above.
- Rendered with plain JS (no framework — matches the site's existing
  no-unnecessary-dependencies approach), showing the next few months,
  visually distinguishing booked/buffer days from open ones.
- **Clickable, not click-to-book.** A guest selects their desired check-in
  and check-out dates on the calendar; those selections pre-fill the
  existing `checkin_date`/`checkout_date` fields on the inquiry form below
  it, instead of the guest typing dates blind into a plain date input.
  Unavailable/buffer days aren't selectable. The request-only booking model
  is unchanged — this only replaces manual date entry with a visual picker
  that already knows what's open; Kelley still approves every request
  manually, no payment or auto-confirm happens here.

## Data Model (new post meta, on `rental-property` posts)

| Meta key | Set by | Purpose |
|---|---|---|
| `airbnb_ical_url` | Fernando, one-time in wp-admin (Mac-app input left as an open future option — not built now, see Out of Scope) | Where we fetch bookings from |
| `airbnb_ical_import_url` | N/A (informational only — the actual paste happens in Airbnb's own dashboard) | Documents which of our generated `.ics` URLs was given to Airbnb |
| `airbnb_blocked_dates` | Sync cron (overwritten each run) | Raw parsed Airbnb bookings, JSON array of `{start, end}` |
| `manual_blocked_dates` | Kelley/Fernando, wp-admin | Manual holds (maintenance, personal use, etc.) |

## Error Handling

- **Fetch failure** (Airbnb URL times out / 404s): keep the last-known-good
  `airbnb_blocked_dates` value, log the failure, do not overwrite with
  empty/partial data. A transient outage must never silently clear real
  blocked dates.
- **Malformed iCal response:** same treatment — skip that property this
  run, log, continue to the next property. One property's bad feed must
  not abort the whole cron run.
- **Outbound `.ics` generation failure:** never write a broken/empty file;
  either regenerate successfully or leave the previous valid file in place.
- **Alerting:** cron failures email `fgmanta@gmail.com` only (Fernando),
  via the existing Google Workspace SMTP config (`COZUMEL_SMTP_USER`/
  `COZUMEL_SMTP_PASS` constants, see `[[inquiry_form_smtp_broken]]` memory).
  Kelley is never on this alert path — matches her preference to stay out
  of anything technical.

## Testing Plan

- **Parsing + buffer logic:** unit-test against fixture `.ics` files (fake
  Airbnb feed with known booked ranges) — verify parsed dates and buffer
  padding are correct, without touching the real Airbnb account.
- **Real Airbnb fetch:** once Fernando has the 3 properties' export URLs,
  run the sync once manually and cross-check parsed dates against what
  Airbnb's own host calendar shows.
- **Outbound `.ics`:** validate the generated file parses back correctly;
  after pasting the URL into Airbnb's import field, visually confirm in
  Airbnb's calendar UI that the dates show blocked (allow for Airbnb's own
  2–4hr refresh delay before checking).
- **Public calendar widget:** manual check on all 3 rental pages — booked,
  buffer, and open days render distinctly; cross-checked against Airbnb's
  calendar for the same property.
- **Cron reliability:** confirm the system cron entry fires on its own
  schedule (not just when run manually) by checking a timestamp/log after
  a real scheduled run.
- **Failure path:** simulate a broken Airbnb URL, confirm last-known-good
  data is preserved, Fernando gets the failure email, and the other 2
  properties still process normally.

## Out of Scope

- **Mac app changes.** Nothing in the Mac app reads or writes availability
  in this project. Deferred to the booking-request-workflow project, which
  already lists "calendar/availability tie-in" as an open item and will
  consume `airbnb_blocked_dates`/`manual_blocked_dates` once it exists.
  Specifically: `airbnb_ical_url` is wp-admin-only for now — adding
  a new property's Airbnb iCal URL from the Mac app itself (extending
  `WordPressSyncService`'s synced fields) is left as an **open option**,
  not built in this pass, since new-property setup is rare enough that
  wp-admin-only is sufficient today.
- **The for-sale property** — no nightly availability concept.
- **Lodgify integration** — superseded by targeting Airbnb directly, per
  the 2026-08-18 cancellation.
- **Instant/automatic booking** — the calendar is informational only; the
  request-approve flow is unchanged.

## Dependencies / Prerequisites

- Fernando needs each rental property's Airbnb iCal **export** URL
  (Airbnb: Listings → listing → Availability → Calendar → Calendar sync →
  Export calendar) to populate `airbnb_ical_url`.
- Fernando needs to manually paste each property's generated `.ics` URL
  (`wp-content/uploads/calendars/<slug>.ics`) into that same listing's
  **Import calendar** field in Airbnb — one-time setup per property, done
  after the sync code is deployed and generating valid files.
- Confirmed: Kelley's Airbnb account is active and Fernando can get
  credentials if needed for initial setup.

## Relationship to Other Work

This project is a prerequisite for the booking-request-workflow backend
(WordPress CPT + payment endpoint), which was also discussed this session:
Kelley will use **PayPal** (confirmed Business account) instead of Stripe
for the payment-link step, since she's already familiar with PayPal and it
fits the same "create payment request, get back a payable link" shape the
original design assumed for Stripe. That project is sequenced to start
after this one ships, and will get its own brainstorming session to update
the existing partial design (see `[[booking_request_workflow]]` memory) for
the PayPal swap and the calendar dependency this spec provides.
