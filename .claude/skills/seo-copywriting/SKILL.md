---
name: seo-copywriting
description: Write professional, engaging, SEO-ready copy for the Cozumel Manager companion website — property listing pages, blog posts, local guides, and marketing content. Use this whenever the user asks to write, draft, revise, or polish any website copy, property descriptions, blog articles, meta titles/descriptions, or marketing text for the Cozumel vacation rental business (Nah Ha Condominium 101, Cool Caribbean Views, Casa Bohemia), even if they don't say "SEO" or "copywriting" explicitly — e.g. "write the description for the Nah Ha page" or "draft a blog post about diving spots near Cozumel" should trigger this.
---

# SEO Copywriting for Cozumel Manager

Writing for a small owner-operated vacation rental business, not a big brand. The
copy needs to work two jobs at once: read as warm and human to a guest deciding
where to stay, and read as structured and keyword-relevant to a search engine
deciding whether to rank it. Neither job should be visible to the reader — good
SEO copy never *sounds* like SEO copy.

## Before writing anything

Check `docs/superpowers/specs/*website-copy-voice*` or project memory for the
current per-property tone split and pricing facts — these are business decisions,
not style choices, and get them wrong and the copy is unusable regardless of how
well-written it is. As of the last confirmed brief:

- **Nah Ha Condominium 101** is the one true luxury property — boutique/upscale
  language is appropriate here ("Cozumel living at its finest," dramatic views,
  refined finishes).
- **Cool Caribbean Views** and **Casa Bohemia** are medium-budget rentals — warm
  and inviting, but avoid luxury-coded words like "retreat" or "residence."
  Lead with value, comfort, and simplicity instead.
- **Pricing structure** (all three properties): stays of 7+ nights but under a
  month get 10% off the nightly rate; monthly stays use a separate flat rate with
  electricity billed separately based on guest consumption. If copy mentions
  pricing or length of stay, it must reflect this — don't simplify it away.

If either the tone split or pricing facts seem to have changed, ask before writing
rather than guessing — a beautifully-written paragraph in the wrong voice or with
stale pricing terms is worse than no paragraph.

## What makes copy "SEO-ready" here

This is a hyper-local business (one town, three properties) — the SEO opportunity
is local and long-tail, not competing for generic terms like "vacation rental."
Concretely:

1. **Say the specific thing, not the generic thing.** "Steps from the Cozumel
   cruise pier" beats "close to attractions." Named neighborhoods, named nearby
   landmarks (San Miguel, the malecón, specific dive shops/beach clubs), and
   named amenities all outrank vague superlatives in both search relevance and
   reader trust.
2. **Front-load the point.** Search engines and skimming readers both reward the
   first sentence carrying the actual answer (what/where/for whom), not a
   scene-setting preamble.
3. **Structure with real headings**, not bolded sentences pretending to be
   headings. A reader (and a search engine) should be able to skim just the H2s
   and understand the page.
4. **One clear next action.** Every page ends knowing what the reader should do
   next (inquire, check dates, read more) — don't let it trail off.
5. **Natural keyword presence, never stuffing.** If "Cozumel oceanfront
   condo" is a term worth ranking for, it should appear because it's the most
   natural way to describe the place — not repeated mechanically. If a keyword
   only fits by breaking the sentence, drop the keyword.

## Output structure for a property or landing page

Use this shape unless the user asks for something else:

```
**Meta Title:** (50–60 characters, includes property name + one distinguishing
detail — neighborhood, view, or standout amenity)

**Meta Description:** (140–155 characters, states what it is + who it's for +
a reason to click — not a summary of the summary)

# [H1 — Property name, closely matching the meta title]

[Opening paragraph — 2-3 sentences, front-loaded with the concrete answer:
what this place is, where, and its single strongest draw.]

## [H2 — thematic section, e.g. "The Space," "Location," "Amenities"]
[Body copy. Repeat H2 sections as needed — 3-5 total is typical for a property
page.]

## Booking & Rates
[Nightly rate framing + the 7-night and monthly pricing rules above, stated
plainly.]
```

For blog posts / local guides, drop the "Booking & Rates" section, keep the
meta title/description block, and use as many H2s as the topic naturally breaks
into (aim for skimmable, not padded to a word count).

## Examples

**Nah Ha (luxury), input:** "Write the opening paragraph for the Nah Ha listing
page."

**Output:**
> Perched above Cozumel's North Shore, Nah Ha Condominium 101 pairs
> floor-to-ceiling ocean views with the kind of quiet, refined comfort that
> makes a trip feel like an escape rather than a stay. This is Cozumel living
> at its finest — steps from the water, designed for travelers who want the
> island without compromise.

**Cool Caribbean Views (medium-budget), input:** "Write the opening paragraph
for the Cool Caribbean Views listing page."

**Output:**
> Cool Caribbean Views puts you right in the heart of downtown Cozumel — an
> easy walk to the malecón, the cruise pier, and San Miguel's best local spots.
> It's a comfortable, no-fuss home base for travelers who'd rather spend their
> budget on diving and dinner than on the room itself.

Notice what changed: "escape," "refined," "Cozumel living at its finest" for
Nah Ha vs. "comfortable," "no-fuss," "home base" for Cool Caribbean — same
underlying method (front-loaded, specific, one draw), different vocabulary
register.

## What to avoid

- Generic travel-blog filler ("nestled in the heart of," "a hidden gem," "the
  perfect getaway") — these add length without adding information or ranking
  value, and read as AI-generated boilerplate to a human reader.
- Keyword stuffing or unnatural repetition of place names.
- Overpromising amenities or views not confirmed in the property's actual
  details/photos — check `properties.json` or ask rather than inventing detail.
- Applying luxury language to the two medium-budget properties, or
  undersized/casual language to Nah Ha.
