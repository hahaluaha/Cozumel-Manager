# Homepage Hero Redesign — Design Spec
Date: 2026-07-22

## Overview
Replace the current static homepage hero (`front-page.php`'s `.hero` section — plain heading, tagline, two buttons on a white background) with a "Tidal Reveal" hero: a full-bleed, slowly crossfading photo background with a liquid-glass CTA panel floating over it. This also introduces a new site-wide "trust" color palette (deep navy + turquoise + muted gold) that the current single-blue palette (`--color-ocean: #2a6fa8`) is replaced by, since the palette isn't hero-only — it recolors buttons, section bands, and (per the already-approved carousel spec) the photo carousel too.

Design was validated iteratively through a series of static HTML mockups (built with the actual Cool Caribbean Views, Nah Ha 101, and Casa Bohemia photos) reviewed directly by Fernando; the final approved version is referred to below as "v9." Two alternate directions (a static arched-photo triptych, and several earlier Tidal Reveal iterations with layout/opacity issues) were explored and rejected in favor of this one.

## Color Palette
New CSS custom properties in `theme.css`, replacing the current `:root` block:

```css
:root {
    --color-sand: #f5f0e8;        /* unchanged — page background */
    --color-navy-deep: #0a1226;   /* hero gradient start, darkest */
    --color-navy: #1c3260;        /* hero gradient mid, primary brand blue */
    --color-navy-light: #2d4a86;  /* hero gradient end */
    --color-turquoise: #2eb3c4;   /* water accent — wave divider, highlights */
    --color-turquoise-deep: #1c8fa6; /* wave divider gradient edges */
    --color-gold: #c9a08a;        /* primary CTA, warm accent */
    --color-text: #2c2c2c;        /* unchanged */
    --color-muted: #6b6b6b;       /* unchanged */
    --color-white: #ffffff;       /* unchanged */
    --font-primary: 'Georgia', serif;   /* unchanged — headline/eyebrow face */
    --font-sans: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; /* unchanged */
}
```

`--color-ocean` is retired. `.btn--primary` is currently used *only* in the hero (confirmed in `front-page.php` — every other CTA on the homepage, e.g. "View All Rentals", uses `.btn--outline`), so it repoints cleanly to `--color-gold`. `.btn--outline` (used everywhere else — property card links, section CTAs) repoints to `--color-navy` for its border/text color, keeping the rest of the site's buttons trustworthy-navy while gold stays reserved for the one hero moment, avoiding overuse. This is a **site-wide token swap**, not hero-scoped — `property-card`, section backgrounds, and (per the existing carousel spec/plan) `property-carousel__dot.is-active` etc. all inherit the new palette automatically since they reference the CSS variables rather than hardcoded hex.

## Hero Structure (`.hero` in `front-page.php`)

Replaces the current markup:
```html
<section class="hero">
    <h1 class="hero__title">Cozumel Homes</h1>
    <p class="hero__tagline">Premium vacation rentals and real estate in Cozumel, Mexico</p>
    <a href="/rentals/" class="btn btn--primary">View Rentals</a>
    <a href="/for-sale/" class="btn btn--outline">Properties for Sale</a>
</section>
```

With a full-bleed photo-crossfade hero containing a centered (offset left) glass CTA panel. Structure:

```html
<section class="hero hero--tidal">
    <div class="hero__slide"><img src="..." alt="Nah Ha 101 sunset pool"></div>
    <div class="hero__slide"><img src="..." alt="Cool Caribbean Views ocean view"></div>
    <div class="hero__slide"><img src="..." alt="Casa Bohemia snorkel masks"></div>
    <div class="hero__scrim"></div>

    <div class="hero__panel">
        <p class="hero__eyebrow">Cozumel, Mexico</p>
        <h1 class="hero__title">Your island story, <em>waiting</em></h1>
        <p class="hero__tagline">Premium vacation rentals and real estate, hand-managed by someone who actually lives here.</p>
        <div class="hero__ctas">
            <a href="/rentals/" class="btn btn--primary">View Rentals →</a>
            <a href="/for-sale/" class="btn btn--outline">Properties for Sale</a>
        </div>
    </div>

    <div class="hero__dots" aria-hidden="true">
        <div class="hero__dot"></div>
        <div class="hero__dot"></div>
        <div class="hero__dot"></div>
    </div>

    <svg class="hero__wave" viewBox="0 0 1200 60" preserveAspectRatio="none">
        <defs>
            <linearGradient id="hero-wave-grad" x1="0" y1="0" x2="1" y2="0">
                <stop offset="0%" stop-color="var(--color-turquoise-deep)"/>
                <stop offset="50%" stop-color="var(--color-turquoise)"/>
                <stop offset="100%" stop-color="var(--color-turquoise-deep)"/>
            </linearGradient>
        </defs>
        <path d="M0,30 C150,60 350,0 600,25 C850,50 1050,5 1200,30 L1200,60 L0,60 Z" fill="url(#hero-wave-grad)"/>
    </svg>
</section>
```

### Photo source
Three fixed hero photos, hand-picked (not the property's full `gallery_ids` — this is a curated brand moment, not a listing gallery): Nah Ha 101's sunset pool shot, Cool Caribbean Views' ocean view, Casa Bohemia's snorkel masks. Uploaded once to the WP media library and referenced by attachment ID/URL directly in `front-page.php` (or as a small hard-coded array at the top of the template) — no admin picker needed for 3 fixed, rarely-changing images. If Fernando wants these swappable later without a code change, that's a small follow-up (a `hero_photos` theme option), not part of this spec.

### Crossfade + Ken Burns motion
- Each slide is absolutely positioned, full-bleed (`object-fit: cover`), stacked.
- CSS `@keyframes` cycle: each slide fades in/holds/fades out across an 18s loop (3 slides × 6s each), staggered via `animation-delay`.
- Concurrent slow zoom (`scale(1.0)` → `scale(1.09)`) on each slide's `<img>`, synced to the same 18s cycle — the "Ken Burns" drift.
- `@media (prefers-reduced-motion: reduce)`: all animations disabled; first slide shown at full opacity, static.

### Liquid-glass CTA panel
- `background: rgba(24,78,120,0.2)` (translucent navy-blue, not opaque) + `backdrop-filter: blur(22px) saturate(1.5)` (with `-webkit-` prefix for Safari).
- `border-radius: 28px`; `border: 1px solid rgba(200,228,245,0.32)`.
- Specular sheen via a `::before` pseudo-element: a rotated radial-gradient white highlight, `pointer-events: none`, clipped by the panel's `overflow: hidden`.
- Inset highlight ring via `box-shadow`: `inset 0 1px 0 rgba(255,255,255,0.28), inset 0 0 40px rgba(120,180,215,0.08)`, plus a drop shadow (`0 24px 60px rgba(4,14,28,0.35)`) separating it from the photo behind.
- Positioned via flexbox centering on the `.hero` container (`display:flex; align-items:center; justify-content:center`) plus `transform: translateX(-110px)` — left-of-true-center so the photo's right side (where the most interesting detail tends to sit, per the reviewed photos) stays uncovered. On mobile (`max-width: 720px`), the transform is removed and the panel centers normally with tighter padding.
- Content (eyebrow, headline, tagline, buttons) is centered text-align within the panel.

### Eyebrow / headline typography
- Eyebrow ("Cozumel, Mexico"): `font-family: var(--font-primary)` (Georgia), italic, uppercase, `font-size: 1.05rem`, `letter-spacing: 0.08em`, color `#c3ddef` (light blue-tinted, not pure white — ties to the water theme).
- Headline: Georgia, `font-weight: 400`, `clamp(2.1rem, 3.4vw, 2.9rem)`, `text-wrap: balance`, with an `<em>` span (e.g. "waiting") styled in `--color-gold` for a single warm accent word.

### Progress dots
- Three vertical pill indicators, bottom-right of the hero, `aria-hidden="true"` (decorative — not a functional control in this spec; see Out of Scope).
- Each fills top-to-bottom via a `::after` pseudo-element animated in sync with its corresponding slide's 18s cycle, giving a "photo story" progress readout.

### Wave divider
- Full-width SVG at the hero's bottom edge (`position: absolute; bottom: -1px`), turquoise gradient fill (`--color-turquoise-deep` → `--color-turquoise` → `--color-turquoise-deep`), replacing the sand-colored version from earlier iterations per review feedback.

### Corners
- Outer hero container: `border-radius: 22px` (rounded, not sharp — matches the softer visual language introduced across this redesign).
- `overflow: hidden` on the hero container clips the slides/scrim to those rounded corners.

## Responsive Behavior
- Desktop: hero `min-height: 560px`, panel `max-width: 440px`, offset left via `translateX(-110px)`.
- Mobile (`max-width: 720px`): hero `min-height: 480px`, panel `margin: 0 16px`, `max-width: none`, `transform: none` (centers normally — the left-offset is a desktop-only refinement since there's no room to spare on narrow screens).

## Error Handling / Edge Cases
- Missing/failed photo load: browser's normal broken-image fallback — acceptable since these are 3 fixed, manually-verified uploads (not user-generated content), unlike the carousel's `gallery_ids` which does need defensive handling for deleted attachments.
- `prefers-reduced-motion: reduce`: hero freezes on the first photo (Nah Ha 101 sunset pool), no crossfade/Ken Burns/dot-fill animation.
- Narrow viewports: see Responsive Behavior above.

## Verification
No automated test suite in this theme (pure PHP/CSS/vanilla-JS) — verification is manual, matching the existing carousel spec's approach:
- Load the homepage; confirm all 3 photos cycle through the crossfade with visible (but slow/subtle) Ken Burns drift.
- Confirm the glass panel is legible against all 3 photos at every point in the cycle (text contrast, not just at the moment of screenshotting).
- Toggle "Reduce Motion" in macOS System Settings → Accessibility, reload, confirm the hero freezes on the first photo with no animation.
- Resize to mobile width; confirm the panel re-centers, the wave still renders correctly, and touch/scroll performance is smooth (backdrop-filter blur can be GPU-expensive — watch for jank on the browser used for verification).
- Confirm the two CTA buttons ("View Rentals", "Properties for Sale") link correctly and use the new palette.
- Spot-check the palette swap didn't break contrast/readability elsewhere on the homepage (property cards, section headings, testimonials) since `--color-ocean` is retired site-wide.

## Out of Scope
- **Coordinates/map for property pages.** The WP schema already has `latitude`/`longitude` fields (`inc/meta-fields.php`), but they are not populated — confirmed empty on the local dev site. `cozumelhomes.net` turned out to be the real production booking site (Lodgify-powered) with actual per-property listings — real coordinates were pulled from each listing's embedded `lodgify-model-json` script tag (not visible in rendered/markdown-converted pages, only in raw HTML) and confirmed against known addresses/landmarks for each property:
  - Cool Caribbean Views: `20.506762, -86.956383` (source: `cozumelhomes.net/en/761183/cozumels-cool-caribbean-views`)
  - Casa Bohemia: `20.502584, -86.9549` (source: `cozumelhomes.net/en/1374751/cozumels-casa-bohemia`)
  - Nah Ha 101: `20.53647, -86.937372` (source: `cozumelhomes.net/en/2858379/cozumels-nah-ha-condominium-101`)
  - The for-sale listing has no equivalent Lodgify page (it's not a bookable rental) — its coordinates are still unresolved and need to be sourced separately (geocoded from its address, or pulled from wherever it's listed) in a future session.
  Populating the WP `latitude`/`longitude` fields with the three rental values above, and building an actual map UI, remain a follow-up — not part of this spec.
- **8-second hero video.** Raised as a future idea; connects to the already-approved video-upload design/plan and the carousel's media-type-agnostic `gallery_ids`. Worth its own brainstorm later — not designed here.
- **Functional progress-dot navigation** (click a dot to jump to a slide). The dots here are decorative progress indicators only, matching the reviewed mockup; making them clickable/interactive is a small future enhancement if wanted.
- **Swappable hero photos via admin UI.** The 3 hero photos are hard-coded in the template for this spec; a theme-options picker is a follow-up if Fernando wants to change them without a code deploy.
- **Carousel implementation itself** — already fully specified/planned separately (`2026-07-21-property-photo-carousel-design.md` / `-plan.md`); this spec only ensures the new color tokens it will inherit are defined correctly.
