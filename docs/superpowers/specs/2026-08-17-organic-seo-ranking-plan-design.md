# Organic SEO Ranking Plan — Foundation, Citations, Content

## Context

Kelley wants cozumelhomes.net ranking on Google's first 3 pages for broad
terms like "Cozumel vacation rental" / "Cozumel condo rental," moving toward
page 1 over time. No ad budget right now — she's run Facebook ads before but
not currently, and it's slow season approaching. This plan is organic-only.

This is the technical/local/backlink layer. It complements, not replaces,
`2026-08-10-seo-content-strategy-design.md` (voice/positioning) and
`docs/marketing/blog-topics.md` (topic backlog) — both already exist and stay
as-is.

**Reality check on the goal:** broad terms are dominated by Airbnb, VRBO,
TripAdvisor, and several established Cozumel rental agencies (cozycozy,
a1vacationhomes, enjoycozumel, yourcozumel, luxurycozumel, Cozumel Seaside
Retreats). cozumelhomes.net already ranks #3 for its own brand name, which is
a reasonable trust signal for a domain this young, but broad-term page-1
ranking against platforms with millions of backlinks is a long game — likely
6-12+ months of sustained work, not weeks. This plan optimizes for the
fastest realistic path (local/citation signals a platform can't claim), not
a shortcut past that timeline.

**Current state (verified 2026-08-17):**
- No Google Search Console or Analytics tag present on the live site —
  ranking progress currently isn't measurable at all.
- `wp-sitemap.xml` exists (WordPress core default) but isn't referenced in
  `robots.txt`.
- No Google Business Profile or Facebook page surfaced in search for
  "Cozumel Homes" / cozumelhomes.net.
- No structured data (schema.org) on rental/for-sale property pages.

**The Airbnb angle:** Airbnb's cancellation policy lets guests cancel weeks
or months out with no percentage penalty, which lands the revenue loss on
small hosts like Kelley, not on Airbnb. This is a real, verifiable grievance
among hosts (not a claim we're inventing), and it's the honest basis for a
"why book direct" content angle later in this plan — per `feedback_honest_copy`,
we state it as what it is (Airbnb's platform policy shifts cancellation risk
onto small hosts) rather than as an unverifiable "everyone's switching" claim.

## Approach

Three phases, sequenced (approved by Fernando 2026-08-17):

1. **Foundation** — free, one-time technical/local setup. Nothing else in
   this plan is measurable or fully effective without this.
2. **Citations** — free local/directory signals a platform account can't
   claim on Kelley's behalf; these compound alongside Phase 3.
3. **Content cadence** — sustained blog/guide publishing at a realistic pace,
   drawing on the existing blog-topics backlog and competitive-positioning
   voice guide.

Phases 2 and 3 run in parallel once Phase 1 lands; Phase 1 is a hard
prerequisite because it's the only phase that produces the data (Search
Console) needed to tell whether 2 and 3 are working.

## Phase 1: Foundation (technical + local, one-time)

- **Google Search Console**: verify cozumelhomes.net (DNS TXT record or HTML
  file, whichever is less friction given VPS/DNS access already in place),
  submit `wp-sitemap.xml`.
- **Google Analytics 4**: add tracking (GA4 tag via `functions.php`
  `wp_head` hook — no plugin, matches the project's no-plugin preference).
- **`robots.txt`**: add `Sitemap: https://cozumelhomes.net/wp-sitemap.xml`.
- **Structured data**: add `LodgingBusiness`/`VacationRental` JSON-LD schema
  to each rental property page (name, address, price range, image, review
  rating if any exist) and `LocalBusiness` schema site-wide. Custom PHP in
  the theme, no plugin — same pattern as the rest of the site.
- **Google Business Profile**: create and verify a free listing for Kelley's
  rental business. This is the single highest-leverage free action available
  — it's how a small host shows up in Google's local map pack for "Cozumel
  vacation rental" searches, which Airbnb/VRBO listings can't occupy on her
  behalf. Requires Kelley: a business address/service area she's comfortable
  publishing, and phone/hours she wants listed. **Blocked on Kelley input —
  flag this as the one item in Phase 1 that needs her, everything else is
  Fernando/Claude-executable.**
- **Page speed / Core Web Vitals spot-check**: quick pass (PageSpeed
  Insights) on the homepage and one rental page; fix anything cheap (image
  sizing, render-blocking scripts) found in the process. Not a redesign —
  just closing obvious gaps since site speed is a ranking factor.

## Phase 2: Citations (free backlinks/local authority)

- **TripAdvisor**: claim/create listings for the 3 rental properties if not
  already present (search turned up a TripAdvisor page for the Nah Ha
  building generally, not confirmed for unit 101 specifically — needs a
  direct check).
- **Local directories**: Cozumel tourism-board or municipal tourism sites,
  if any accept free listings; Mexico/Quintana Roo tourism directories.
- **Dive shop / partner cross-links**: Kelley's mentioned advising guests on
  dive/snorkel operators — if any of those businesses have websites, a
  reciprocal link (her site links their tours, they link her rentals) is a
  free, relevant backlink and a real value-add for guests, not a link-scheme.
- **NAP consistency**: once Google Business Profile exists (Phase 1), make
  sure Name/Address/Phone matches exactly across it, TripAdvisor, and the
  site footer — inconsistency actively hurts local ranking.

This phase needs a manual audit pass to see what already exists before
creating anything new — no point duplicating an old Lodgify-era TripAdvisor
listing, for example.

## Phase 3: Content cadence

- Draw from the existing `docs/marketing/blog-topics.md` backlog and
  `seo-copywriting` skill's competitive-positioning voice guide — no new
  topic research needed to start.
- **Pace**: looking at the last 30 days of site work (43 commits total,
  spanning calendar sync, SMTP fixes, hero videos, and one blog post), a
  realistic sustained cadence is roughly one substantial content piece every
  1-2 weeks, not weekly — content competes with the rest of the app/website
  backlog. Plan around that, not an unsustainable promise.
- **"Book direct" piece**: one specific post/page addressing Airbnb's
  no-penalty late-cancellation policy and what it costs small hosts,
  framed honestly (this is Airbnb's actual stated cancellation policy
  mechanics, not a claim about "everyone leaving Airbnb") as a reason to
  book directly with an established, known host. Ties into Kelley's
  since-1997 longevity claim already approved in the competitive-positioning
  doc.
- Each new post should include the JSON-LD `Article` schema (Phase 1
  establishes the pattern) and get manually submitted to Search Console's
  URL inspection for faster indexing — free, no plugin needed.

## What's explicitly out of scope

- No paid ads (Facebook or Google) — confirmed budget is zero right now.
- No link-buying, PBNs, or any backlink tactic that risks a Google penalty.
- No promise of a specific ranking timeline — broad-term competition against
  platform sites is inherently slow; this plan reports progress via Search
  Console data (once it exists) rather than a date commitment.
- Not re-litigating voice/positioning — that's the existing 2026-08-10 doc.

## Open items needing Kelley

- Google Business Profile: business address/service area to publish, phone,
  hours.
- Confirm she's OK with the "book direct" / Airbnb cancellation-policy piece
  before it's drafted — it names a real platform practice and should have
  her sign-off given it's more pointed than the site's other content.
