# Homepage Hero Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current static homepage hero (plain heading + tagline + two buttons on a sand background) with the approved "Tidal Reveal" design — a full-bleed, slowly crossfading photo background with a liquid-glass CTA panel — and introduce the new site-wide trust color palette (deep navy + turquoise + muted gold) that palette replaces across the whole homepage, not just the hero.

**Architecture:** All changes are in the `Cozumel-Website` repo's `cozumel-homes` theme — no build tooling, plain PHP/CSS/vanilla JS (CSS-only animation, no JS needed for the crossfade/Ken Burns/dot-fill effects). Three curated hero photos are uploaded once to the WP media library via REST and hard-coded by URL into `front-page.php` (not the property `gallery_ids` mechanism — this is a fixed brand moment, not a per-property gallery). New CSS custom properties in `theme.css`'s `:root` replace `--color-ocean`, and every existing rule that referenced it is repointed so the palette change is site-wide.

**Tech Stack:** WordPress (PHP 8+), theme `cozumel-homes` (child of GeneratePress) in the `Cozumel-Website` repo, no build tooling — plain PHP/CSS, no new JS files needed (this hero's motion is pure CSS `@keyframes`, unlike the carousel's arrow/dot navigation which needed vanilla JS).

## Global Constraints

- **Repo:** All theme file changes happen in `~/Projects/Cozumel-Website` (git repo `Cozumel-Website`), symlinked into `~/Local Sites/cozumel-homes/app/public/wp-content/themes/cozumel-homes`. This plan file lives in `Cozumel_App_Final` as documentation only — commit theme changes in the `Cozumel-Website` repo, not this one.
- No third-party WordPress plugins or JS libraries — hand-written PHP/CSS only, per standing project preference. The crossfade/Ken Burns/dot-fill/wave effects are all achievable in pure CSS (`@keyframes`, `animation-delay`), so no new JS file is needed for this feature.
- `--color-ocean` is retired and every reference to it in `theme.css` must be repointed — this is a site-wide token swap, not hero-scoped (see Task 1).
- `.btn--primary` is currently used *only* in the hero (confirmed via grep — every other CTA on the homepage uses `.btn--outline`), so it becomes gold; `.btn--outline` (used everywhere else) becomes navy.
- `prefers-reduced-motion: reduce` must freeze the hero on its first photo with no animation — this is a hard requirement from the approved spec, not optional polish.
- REST API writes require a valid WordPress Application Password for user `akrati32` on `cozumel-homes.local` — the ones used during the carousel work were revoked afterward. Generate a fresh one before Task 2.
- No automated test suite exists in this theme (pure PHP/CSS, no build tooling) — verification is manual throughout, matching the existing carousel plan's approach.

---

### Task 1: New trust palette — CSS tokens + site-wide repoint

**Files:**
- Modify: `theme/cozumel-homes/assets/css/theme.css:1-9` (`:root` block)
- Modify: `theme/cozumel-homes/assets/css/theme.css:27` (`.btn--primary`)
- Modify: `theme/cozumel-homes/assets/css/theme.css:29` (`.btn--outline`)
- Modify: `theme/cozumel-homes/assets/css/theme.css:62` (`.property-card__rate`)
- Modify: `theme/cozumel-homes/assets/css/theme.css:68` (`.property-single__rate`)

**Interfaces:**
- Produces: CSS custom properties `--color-navy-deep`, `--color-navy`, `--color-navy-light`, `--color-turquoise`, `--color-turquoise-deep`, `--color-gold` on `:root` — consumed by Task 3's hero styles and already-live styles (`.btn--primary`, `.btn--outline`, `.property-card__rate`, `.property-single__rate`, and the existing `.property-carousel` rules which reference `var(--color-white)` and are unaffected).

This task ships and is verifiable entirely on its own — no hero changes yet — so a reviewer can confirm the palette swap didn't break anything before the hero rebuild starts.

---

- [ ] **Step 1: Replace the `:root` color tokens**

  In `theme/cozumel-homes/assets/css/theme.css`, replace lines 1-9:

  ```css
  :root {
      --color-sand: #f5f0e8;
      --color-ocean: #2a6fa8;
      --color-text: #2c2c2c;
      --color-muted: #6b6b6b;
      --color-white: #ffffff;
      --font-primary: 'Georgia', serif;
      --font-sans: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  }
  ```

  with:

  ```css
  :root {
      --color-sand: #f5f0e8;
      --color-navy-deep: #0a1226;
      --color-navy: #1c3260;
      --color-navy-light: #2d4a86;
      --color-turquoise: #2eb3c4;
      --color-turquoise-deep: #1c8fa6;
      --color-gold: #c9a08a;
      --color-text: #2c2c2c;
      --color-muted: #6b6b6b;
      --color-white: #ffffff;
      --font-primary: 'Georgia', serif;
      --font-sans: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  }
  ```

- [ ] **Step 2: Repoint `.btn--primary` and `.btn--outline`**

  In `theme/cozumel-homes/assets/css/theme.css`, replace:

  ```css
  .btn--primary { background: var(--color-ocean); color: var(--color-white); }
  .btn--airbnb { background: #ff5a5f; color: var(--color-white); }
  .btn--outline { border: 2px solid var(--color-ocean); color: var(--color-ocean); background: transparent; }
  ```

  with:

  ```css
  .btn--primary { background: var(--color-gold); color: #2a2016; }
  .btn--airbnb { background: #ff5a5f; color: var(--color-white); }
  .btn--outline { border: 2px solid var(--color-navy); color: var(--color-navy); background: transparent; }
  ```

- [ ] **Step 3: Repoint the two rate-color rules**

  In `theme/cozumel-homes/assets/css/theme.css`, change line 62:

  ```css
  .property-card__rate { font-weight: 700; font-size: 1.1rem; color: var(--color-ocean); margin: 0; }
  ```

  to:

  ```css
  .property-card__rate { font-weight: 700; font-size: 1.1rem; color: var(--color-navy); margin: 0; }
  ```

  And line 68:

  ```css
  .property-single__rate { font-size: 1.5rem; font-weight: 700; color: var(--color-ocean); }
  ```

  to:

  ```css
  .property-single__rate { font-size: 1.5rem; font-weight: 700; color: var(--color-navy); }
  ```

- [ ] **Step 4: Verify no remaining `--color-ocean` references**

  Run:
  ```bash
  cd ~/Projects/Cozumel-Website
  grep -rn "color-ocean" theme/cozumel-homes/
  ```
  Expected: no output (empty) — every reference has been repointed.

- [ ] **Step 5: Verify visually in the browser**

  Open `http://cozumel-homes.local/` and confirm:
  - "View All Rentals" / "View All For Sale" buttons (`.btn--outline`) now have navy borders/text instead of the old ocean-blue.
  - Rental card prices (`.property-card__rate`) render in navy.
  - Open a single rental page and confirm its price (`.property-single__rate`) is also navy.
  - The hero's own two buttons haven't visually changed yet (Task 3 rebuilds the hero itself) — at this point they'll just show the new gold/navy colors on the *old* hero layout, which is expected and temporary.

- [ ] **Step 6: Commit**

  ```bash
  cd ~/Projects/Cozumel-Website
  git add theme/cozumel-homes/assets/css/theme.css
  git commit -m "feat: replace ocean-blue palette with navy/turquoise/gold trust palette"
  ```

---

### Task 2: Upload the three curated hero photos

**Files:**
- None (one-time media upload via REST, no new theme files)

**Interfaces:**
- Produces: three WordPress media attachment URLs (from `source_url` in each REST response) — consumed directly by Task 3's `front-page.php` markup as hard-coded `<img src>` values. Record the three URLs somewhere (terminal output is fine) before starting Task 3.

---

- [ ] **Step 1: Generate a fresh Application Password**

  In wp-admin → Users → your profile (`akrati32`) → Application Passwords, create one named `cozumel-manager-hero` (the ones from the carousel work were revoked). Copy the generated password — you'll only see it once.

- [ ] **Step 2: Confirm the three source photos exist**

  Run:
  ```bash
  P="$HOME/Library/Containers/Team-Paraiso.CozumelManager/Data/Library/Application Support/CozumelManager/Photos"
  ls -la "$P/prop-003/resized-NahHa101sunsetpool.avif"
  ls -la "$P/prop-001/resized-Cool-Caribbean-ocean-view.avif"
  ls -la "$P/prop-002/resized-Casa Bohemia masks.avif"
  ```
  Expected: all three `ls -la` calls succeed (no "No such file" errors).

- [ ] **Step 3: Upload all three photos and capture their URLs**

  Run (replace `<APP_PASSWORD>` with the password from Step 1):
  ```bash
  CREDS="akrati32:<APP_PASSWORD>"
  BASE="http://cozumel-homes.local/wp-json/wp/v2"
  P="$HOME/Library/Containers/Team-Paraiso.CozumelManager/Data/Library/Application Support/CozumelManager/Photos"

  upload_hero_photo() {
    local file="$1" label="$2"
    resp=$(curl -s -u "$CREDS" -X POST "$BASE/media" \
      -H "Content-Disposition: attachment; filename=$(basename "$file")" \
      -H "Content-Type: image/avif" \
      --data-binary "@$file")
    url=$(echo "$resp" | python3 -c "import sys,json; print(json.load(sys.stdin,strict=False).get('source_url',''))")
    if [[ -z "$url" ]]; then
      echo "UPLOAD FAILED for $label: $resp"
    else
      echo "$label -> $url"
    fi
  }

  upload_hero_photo "$P/prop-003/resized-NahHa101sunsetpool.avif" "nahha-sunset-pool"
  upload_hero_photo "$P/prop-001/resized-Cool-Caribbean-ocean-view.avif" "coolcaribbean-ocean-view"
  upload_hero_photo "$P/prop-002/resized-Casa Bohemia masks.avif" "casabohemia-masks"
  ```

  Expected: three lines printed, each `<label> -> https://.../wp-content/uploads/....avif`. **Write down these three URLs** — Task 3 needs them.

- [ ] **Step 4: Revoke the Application Password**

  In wp-admin → Users → Profile → Application Passwords, revoke `cozumel-manager-hero` now that the upload is done.

(No commit — this task doesn't touch the git repo, only WordPress media.)

---

### Task 3: Hero markup + static structure (no motion yet)

**Files:**
- Modify: `theme/cozumel-homes/front-page.php:4-10` (the `<section class="hero">` block)
- Modify: `theme/cozumel-homes/assets/css/theme.css:73-79` (the `.hero` block) — replace entirely
- Modify: `theme/cozumel-homes/assets/css/theme.css:96-99` (the `@media (max-width: 640px)` block) — remove the now-obsolete `.hero__title` override

**Interfaces:**
- Consumes: `--color-navy-deep`, `--color-navy`, `--color-navy-light`, `--color-turquoise`, `--color-turquoise-deep`, `--color-gold` (Task 1); the three photo URLs (Task 2).
- Produces: static (non-animated) hero markup and layout — first slide shown, glass panel visible and correctly positioned, wave divider rendered. Task 4 adds the crossfade/Ken Burns motion on top of this without changing structure. Task 5 adds the dots and finalizes responsive behavior.

Building the static layout first (no animation) makes each visual bug (panel clipping, wrong colors, wrong shape) trivial to spot and fix before motion is layered on — mirrors how the mockups were iterated (static shape/color first, motion added once the layout was approved).

---

- [ ] **Step 1: Replace the hero markup in `front-page.php`**

  In `theme/cozumel-homes/front-page.php`, replace:

  ```php
      <!-- Hero -->
      <section class="hero">
          <h1 class="hero__title">Cozumel Homes</h1>
          <p class="hero__tagline">Premium vacation rentals and real estate in Cozumel, Mexico</p>
          <a href="/rentals/" class="btn btn--primary">View Rentals</a>
          &nbsp;
          <a href="/for-sale/" class="btn btn--outline">Properties for Sale</a>
      </section>
  ```

  with (substitute the three real media URLs captured in Task 2 for the three `src` placeholders below):

  ```php
      <!-- Hero -->
      <section class="hero">
          <div class="hero__slide"><img src="HERO_URL_NAHHA_SUNSET_POOL" alt="Nah Ha 101 sunset pool"></div>
          <div class="hero__slide"><img src="HERO_URL_COOLCARIBBEAN_OCEAN_VIEW" alt="Cool Caribbean Views ocean view"></div>
          <div class="hero__slide"><img src="HERO_URL_CASABOHEMIA_MASKS" alt="Casa Bohemia snorkel masks"></div>
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

          <svg class="hero__wave" viewBox="0 0 1200 60" preserveAspectRatio="none">
              <defs>
                  <linearGradient id="hero-wave-grad" x1="0" y1="0" x2="1" y2="0">
                      <stop offset="0%" stop-color="#1c8fa6"></stop>
                      <stop offset="50%" stop-color="#2eb3c4"></stop>
                      <stop offset="100%" stop-color="#1c8fa6"></stop>
                  </linearGradient>
              </defs>
              <path d="M0,30 C150,60 350,0 600,25 C850,50 1050,5 1200,30 L1200,60 L0,60 Z" fill="url(#hero-wave-grad)"></path>
          </svg>
      </section>
  ```

  (The `<div class="hero__dots">` block is intentionally deferred to Task 5, alongside the animation that drives it — adding an unanimated, unstyled dots block here would just be dead markup.)

- [ ] **Step 2: Replace the `.hero` CSS block with static (non-animated) styles**

  In `theme/cozumel-homes/assets/css/theme.css`, replace lines 73-79:

  ```css
  .hero {
      background: var(--color-sand);
      padding: 80px 24px;
      text-align: center;
  }
  .hero__title { font-family: var(--font-primary); font-size: 3rem; margin: 0 0 16px; }
  .hero__tagline { font-size: 1.3rem; color: var(--color-muted); margin: 0 0 32px; }
  ```

  with:

  ```css
  .hero {
      position: relative;
      border-radius: 22px;
      overflow: hidden;
      min-height: 560px;
      color: var(--color-sand);
      display: flex;
      align-items: center;
      justify-content: center;
      isolation: isolate;
      margin: 24px;
  }
  .hero__slide {
      position: absolute;
      inset: 0;
      opacity: 0;
  }
  .hero__slide:first-child { opacity: 1; }
  .hero__slide img {
      width: 100%; height: 100%; object-fit: cover;
      filter: saturate(1.08) contrast(1.03);
  }
  .hero__scrim {
      position: absolute; inset: 0;
      background: linear-gradient(0deg, var(--color-navy-deep) 0%, rgba(10,18,38,0.55) 32%, rgba(10,18,38,0.15) 55%, rgba(10,18,38,0.35) 100%);
      z-index: 1;
  }
  .hero__panel {
      position: relative;
      z-index: 2;
      max-width: 440px;
      margin: 0 24px;
      padding: 38px 40px;
      text-align: center;
      transform: translateX(-110px);
      background: rgba(24,78,120,0.2);
      backdrop-filter: blur(22px) saturate(1.5);
      -webkit-backdrop-filter: blur(22px) saturate(1.5);
      border-radius: 28px;
      border: 1px solid rgba(200,228,245,0.32);
      box-shadow:
          0 24px 60px rgba(4,14,28,0.35),
          inset 0 1px 0 rgba(255,255,255,0.28),
          inset 0 0 40px rgba(120,180,215,0.08);
      overflow: hidden;
  }
  .hero__panel::before {
      content: "";
      position: absolute;
      top: -40%; left: -20%;
      width: 70%; height: 90%;
      background: radial-gradient(ellipse at center, rgba(255,255,255,0.2) 0%, transparent 70%);
      transform: rotate(-15deg);
      pointer-events: none;
  }
  .hero__panel > * { position: relative; z-index: 1; }
  .hero__eyebrow {
      font-family: var(--font-primary);
      font-style: italic;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      font-size: 1.05rem;
      color: #c3ddef;
      margin: 0 0 18px;
  }
  .hero__title {
      font-family: var(--font-primary);
      font-weight: 400;
      font-size: clamp(2.1rem, 3.4vw, 2.9rem);
      line-height: 1.08;
      letter-spacing: -0.01em;
      text-wrap: balance;
      margin: 0 0 16px;
      color: #fdfaf4;
  }
  .hero__title em { font-style: italic; color: var(--color-gold); }
  .hero__tagline {
      font-size: 1.02rem;
      line-height: 1.6;
      color: rgba(245,240,232,0.85);
      margin: 0 auto 28px;
  }
  .hero__ctas { display: flex; gap: 12px; justify-content: center; }
  .hero__wave {
      position: absolute;
      left: 0; right: 0; bottom: -1px;
      z-index: 2;
      width: 100%;
      height: 48px;
      line-height: 0;
  }
  ```

- [ ] **Step 3: Remove the now-obsolete `.hero__title` mobile override**

  In `theme/cozumel-homes/assets/css/theme.css`, the `@media (max-width: 640px)` block currently reads:

  ```css
  @media (max-width: 640px) {
      .hero__title { font-size: 2rem; }
      .properties-grid { grid-template-columns: 1fr; }
  }
  ```

  Replace with (drop the `.hero__title` line — the new `clamp()` in the base rule already handles this responsively):

  ```css
  @media (max-width: 640px) {
      .properties-grid { grid-template-columns: 1fr; }
  }
  ```

- [ ] **Step 4: Verify visually in the browser**

  Open `http://cozumel-homes.local/` and confirm:
  - The hero shows the Nah Ha 101 sunset pool photo full-bleed (first slide, since no motion/opacity-cycling exists yet — the other two slides are present in the DOM but invisible at `opacity: 0`).
  - The glass panel is visible, legible, positioned left-of-center, with rounded corners and a visible blur/translucency effect over the photo.
  - The turquoise wave divider renders at the bottom edge of the hero.
  - The outer hero has visibly rounded corners (~22px).
  - "View Rentals →" button is gold/pill-shaped; "Properties for Sale" is a navy-outlined pill.
  - Resize to a narrow width and confirm nothing overflows horizontally (full responsive polish is Task 5 — at this point just confirm no broken layout).

- [ ] **Step 5: Commit**

  ```bash
  cd ~/Projects/Cozumel-Website
  git add theme/cozumel-homes/front-page.php theme/cozumel-homes/assets/css/theme.css
  git commit -m "feat: rebuild homepage hero with Tidal Reveal structure (static, no motion yet)"
  ```

---

### Task 4: Crossfade + Ken Burns motion, with reduced-motion support

**Files:**
- Modify: `theme/cozumel-homes/assets/css/theme.css` (append new rules after the `.hero__wave` rule added in Task 3)

**Interfaces:**
- Consumes: `.hero__slide` / `.hero__slide img` structure from Task 3.
- Produces: the 18-second crossfade + Ken Burns cycle; `prefers-reduced-motion` override. No new classes — this task only adds `@keyframes` and `animation` properties to the existing `.hero__slide` selectors, and the `:nth-child` delay rules that stagger them.

---

- [ ] **Step 1: Add the crossfade + Ken Burns animation rules**

  In `theme/cozumel-homes/assets/css/theme.css`, find the `.hero__slide` and `.hero__slide img` rules added in Task 3:

  ```css
  .hero__slide {
      position: absolute;
      inset: 0;
      opacity: 0;
  }
  .hero__slide:first-child { opacity: 1; }
  .hero__slide img {
      width: 100%; height: 100%; object-fit: cover;
      filter: saturate(1.08) contrast(1.03);
  }
  ```

  Replace with (this removes the static `opacity: 0` / `:first-child { opacity: 1 }` override in favor of the animation driving opacity instead):

  ```css
  .hero__slide {
      position: absolute;
      inset: 0;
      opacity: 0;
      animation: hero-cycle 18s infinite;
  }
  .hero__slide img {
      width: 100%; height: 100%; object-fit: cover;
      filter: saturate(1.08) contrast(1.03);
      animation: hero-kenburns 18s infinite;
  }
  .hero__slide:nth-child(1) { animation-delay: 0s; }
  .hero__slide:nth-child(2) { animation-delay: 6s; }
  .hero__slide:nth-child(3) { animation-delay: 12s; }
  .hero__slide:nth-child(1) img { animation-delay: 0s; }
  .hero__slide:nth-child(2) img { animation-delay: 6s; }
  .hero__slide:nth-child(3) img { animation-delay: 12s; }

  @keyframes hero-cycle {
      0%   { opacity: 0; }
      3%   { opacity: 1; }
      30%  { opacity: 1; }
      36%  { opacity: 0; }
      100% { opacity: 0; }
  }
  @keyframes hero-kenburns {
      0%   { transform: scale(1.0); }
      33%  { transform: scale(1.09); }
      100% { transform: scale(1.09); }
  }
  ```

- [ ] **Step 2: Add the reduced-motion override**

  In `theme/cozumel-homes/assets/css/theme.css`, append immediately after the `@keyframes hero-kenburns` block from Step 1:

  ```css
  @media (prefers-reduced-motion: reduce) {
      .hero__slide, .hero__slide img { animation: none; }
      .hero__slide:first-child { opacity: 1; }
  }
  ```

- [ ] **Step 3: Verify the crossfade cycle in the browser**

  Open `http://cozumel-homes.local/` and watch the hero for at least 20 seconds. Confirm:
  - The sunset pool photo fades out and the ocean view photo fades in around the 6-second mark, then the snorkel masks photo around 12 seconds, then it loops back to the sunset pool.
  - Each photo has a subtle, slow zoom-in (Ken Burns) while it's visible — not a jarring or fast zoom.
  - The glass panel text stays legible throughout the cycle, not just at one frame.

- [ ] **Step 4: Verify reduced-motion behavior**

  On macOS: System Settings → Accessibility → Display → turn on "Reduce Motion". Reload `http://cozumel-homes.local/`. Confirm:
  - The hero shows only the first photo (Nah Ha 101 sunset pool), completely static — no crossfade, no zoom.

  Turn "Reduce Motion" back off afterward if you don't want it left on system-wide.

- [ ] **Step 5: Commit**

  ```bash
  cd ~/Projects/Cozumel-Website
  git add theme/cozumel-homes/assets/css/theme.css
  git commit -m "feat: add hero photo crossfade, Ken Burns drift, and reduced-motion support"
  ```

---

### Task 5: Progress dots, mobile responsive rules, final verification

**Files:**
- Modify: `theme/cozumel-homes/front-page.php` (add the `<div class="hero__dots">` block, deferred from Task 3)
- Modify: `theme/cozumel-homes/assets/css/theme.css` (append dot styles + `@media (max-width: 720px)` block)

**Interfaces:**
- Consumes: the 18s animation timing established in Task 4 (`hero-cycle` delays) — the dot-fill animation must use the same 6s-per-slide timing so the dots stay in sync with the photo cycle.
- Produces: nothing consumed by later tasks — this is the last task in the plan.

---

- [ ] **Step 1: Add the dots markup**

  In `theme/cozumel-homes/front-page.php`, inside the `<section class="hero">` block, add the dots div right after `<div class="hero__panel">...</div>` and before `<svg class="hero__wave" ...>`:

  ```php
          <div class="hero__dots" aria-hidden="true">
              <div class="hero__dot"></div>
              <div class="hero__dot"></div>
              <div class="hero__dot"></div>
          </div>

  ```

  (`aria-hidden="true"` because these are decorative progress indicators only, per the approved spec — not interactive controls.)

- [ ] **Step 2: Add the dot styles**

  In `theme/cozumel-homes/assets/css/theme.css`, append after the `@media (prefers-reduced-motion: reduce)` block added in Task 4:

  ```css
  .hero__dots {
      position: absolute;
      right: 28px;
      bottom: 28px;
      z-index: 2;
      display: flex;
      flex-direction: column;
      gap: 8px;
  }
  .hero__dot {
      width: 6px; height: 24px;
      border-radius: 3px;
      background: rgba(245,240,232,0.3);
      overflow: hidden;
      position: relative;
  }
  .hero__dot::after {
      content: "";
      position: absolute; left: 0; top: 0; width: 100%; height: 0%;
      background: var(--color-gold);
      animation: hero-dot-fill 18s infinite;
  }
  .hero__dot:nth-child(1)::after { animation-delay: 0s; }
  .hero__dot:nth-child(2)::after { animation-delay: 6s; }
  .hero__dot:nth-child(3)::after { animation-delay: 12s; }
  @keyframes hero-dot-fill {
      0%    { height: 0%; }
      33.3% { height: 100%; }
      100%  { height: 100%; }
  }
  @media (prefers-reduced-motion: reduce) {
      .hero__dot::after { animation: none; }
      .hero__dot:first-child::after { height: 100%; }
  }
  ```

- [ ] **Step 3: Add the mobile responsive block**

  In `theme/cozumel-homes/assets/css/theme.css`, append after the dot styles from Step 2:

  ```css
  @media (max-width: 720px) {
      .hero { min-height: 480px; margin: 16px; }
      .hero__panel { margin: 0 16px; padding: 28px; max-width: none; transform: none; }
  }
  ```

- [ ] **Step 4: Verify the dots sync with the photo cycle**

  Open `http://cozumel-homes.local/` and watch the hero for a full 18-second cycle. Confirm:
  - The first (top) dot fills top-to-bottom while the sunset pool photo is showing.
  - The second dot fills while the ocean view photo is showing.
  - The third dot fills while the snorkel masks photo is showing.
  - The cycle loops cleanly (first dot starts refilling from empty right as the sunset pool photo reappears).

- [ ] **Step 5: Verify mobile layout**

  Resize the browser to a narrow width (< 720px) or use devtools device emulation. Confirm:
  - The panel re-centers (no longer offset left) and fits within the viewport with margin on both sides.
  - No horizontal scrollbar appears on the page.
  - The wave divider still renders correctly at the bottom edge.
  - Text in the panel remains legible and doesn't overflow its container.

- [ ] **Step 6: Full regression pass**

  With reduced-motion off, load the homepage fresh and confirm end-to-end:
  - Hero crossfades and zooms correctly (Task 4 behavior still intact).
  - Dots animate in sync (Step 4 above).
  - Both hero CTA buttons link correctly (`/rentals/`, `/for-sale/`) and use the new palette.
  - Below the hero, the rest of the homepage (About Kelley, Vacation Rentals grid, For Sale grid, Testimonials, Inquiry form) is visually unaffected — only the hero and the sitewide button/rate colors (Task 1) should look different from before this plan.

- [ ] **Step 7: Commit**

  ```bash
  cd ~/Projects/Cozumel-Website
  git add theme/cozumel-homes/front-page.php theme/cozumel-homes/assets/css/theme.css
  git commit -m "feat: add hero progress dots and mobile responsive layout"
  ```
