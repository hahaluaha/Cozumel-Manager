# SEO Content Strategy — Competitive Positioning Update

## Context

Phase 2c (content & marketing) was blocked since 2026-07-08 on Kelley providing
real competitor names. She provided them on 2026-08-10: Cozumel Capital, Cozumel
Living, Enjoy Cozumel, Cozumel Villas, Book Cozumel, Cozumel Seaside Rentals
(large, ad-funded) and Fulvio and Sandra, Treetop Cozumel (smaller, strong).

We scanned three sites (Treetop Cozumel, A1 Vacation Homes, Fulvio and Sandra's
site); two others were unreachable by automated fetch (cozumelvillas.com sits
behind a Cloudflare CAPTCHA; the TripAdvisor destination page returned a 403).

## Findings

- **Content depth is the shared weak spot.** None of the three reachable sites
  sustains a blog, local guides, or FAQ content. A1 has one strong destination
  overview page but nothing ongoing; Treetop and Fulvio and Sandra have none.
- **Voice splits into two lanes that match the existing tier split:**
  corporate/aggregator (A1 — generic-aspirational: "charming island paradise")
  vs. personal/small-operator (Fulvio and Sandra — first-person, exclamation-
  heavy, authentic: "Sandra and I," "Mi casa es tu casa!"). Treetop sits between
  the two — polished but impersonal.
- **SEO fundamentals are inconsistent even among stronger players** — Treetop
  has weak heading structure and no visible keyword targeting; A1 has good
  heading hierarchy but its actual listings didn't render for review.
- **Nobody sustains local-guide/blog content.** This is the clearest opening,
  and it lines up with the org-SEO-over-ad-spend strategy already agreed with
  Kelley (see `project_roadmap` memory, Phase 2c).

## Decisions

1. **Update `seo-copywriting` SKILL.md** with a new "Competitive positioning"
   section (placed before "What to avoid"):
   - Lean into small-operator authenticity — a real personal voice, not
     aggregator-generic language — as the default register across all copy,
     within each property's existing tone split (Nah Ha luxury vs. the two
     medium-budget rentals).
   - Local-guide / blog content may be attributed to Fernando or Kelley by
     name as a local voice/byline (mirroring what makes Fulvio and Sandra's
     site work), when a personal byline fits the piece.
   - Treat blog/guide content as filling a gap competitors leave open, not as
     competing head-on with paid-ad reach.

2. **Create `docs/marketing/blog-topics.md`** — a living, checkable list of
   blog/local-guide topic ideas. Each entry: topic, which property tier it
   serves (or general/all), and a one-line rationale tied to a specific gap
   found in the scan. Seeded with 8-10 starting topics; not full drafts, just
   ready-to-write ideas.

## Out of scope

- No new copy is drafted in this pass (property pages, actual blog posts).
- cozumelvillas.com and TripAdvisor are not scanned in this pass — noted as
  blocked, revisit manually (screenshot/pasted text) if wanted later.
- No changes to WordPress, the Mac app, or any code.
