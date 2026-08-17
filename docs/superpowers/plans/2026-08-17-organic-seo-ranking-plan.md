# Organic SEO Ranking Plan Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give cozumelhomes.net the free/organic technical, local, and content
signals it currently lacks (no analytics, no structured data, no Google
Business Profile) so it can compete for broad Cozumel rental search terms,
sequenced foundation → citations → content per the approved design.

**Architecture:** Two new pure-PHP `inc/` files in the WordPress theme
(`seo-technical.php` for the sitemap/analytics basics, `seo-schema.php` for
JSON-LD structured data), each with standalone `php tests/test-*.php`
assertion scripts matching the project's existing convention (no
PHPUnit/Composer). Everything schema/analytics-related hooks into WordPress's
existing `wp_head`/`robots_txt` filters — no template files are modified.
Google Business Profile, Search Console, TripAdvisor, and directory work are
operational tasks with no code — tracked as plan steps so nothing gets lost,
not implemented as software.

**Tech Stack:** PHP (WordPress theme, GeneratePress child theme, no new
dependencies), plain `php` assertion scripts for pure-logic tasks (same
convention as `tests/test-ical-*.php`).

**Spec:** `docs/superpowers/specs/2026-08-17-organic-seo-ranking-plan-design.md`

## Global Constraints

- Organic/free tactics only — no paid ads, no link-buying, no PBNs (spec:
  "What's explicitly out of scope").
- No plugins — custom PHP in the theme, matching the rest of the codebase.
- No new claims beyond what's verifiable — the Airbnb cancellation-policy
  content in Task 15 states Airbnb's platform policy mechanics only, framed
  as a unilateral decision hosts never consented to, not an "everyone's
  leaving Airbnb" claim (see `feedback_honest_copy` memory).
- Google Business Profile requires Kelley's business address/service area,
  phone, and hours before it can be created (Task 7) — she does NOT need to
  share her Workspace password; she adds the executor as a Manager on the
  profile after it exists.
- The "book direct" piece (Task 15) needs Kelley's explicit sign-off before
  drafting, since it names a real platform practice more pointedly than the
  site's other content.
- Production deploys are manual `scp`/`ssh` (see `Cozumel-Website/CLAUDE.md`
  "Production Deployment" section) — committing to the local repo does NOT
  auto-deploy.

---

### Task 1: robots.txt Sitemap Directive

**Files:**
- Create: `theme/cozumel-homes/inc/seo-technical.php`
- Modify: `theme/cozumel-homes/functions.php`
- Create: `tests/test-seo-technical.php`

**Interfaces:**
- Produces: `cozumel_robots_txt_add_sitemap(string $output): string` — pure
  function, appends a `Sitemap:` line to WordPress's existing virtual
  robots.txt output if not already present. Used directly by later steps in
  this task via the `robots_txt` filter hook.

- [ ] **Step 1: Write the failing test**

Create `tests/test-seo-technical.php`:

```php
<?php
require_once __DIR__ . '/test-helpers.php';
require_once __DIR__ . '/../theme/cozumel-homes/inc/seo-technical.php';

// Appends the sitemap line to existing robots.txt output
$base = "User-agent: *\nDisallow: /wp-admin/\nAllow: /wp-admin/admin-ajax.php\n";
$result = cozumel_robots_txt_add_sitemap($base);
assert_equal(
    strpos($result, "Sitemap: https://cozumelhomes.net/wp-sitemap.xml") !== false,
    true,
    'appends sitemap directive'
);
assert_equal(
    strpos($result, "Disallow: /wp-admin/") !== false,
    true,
    'preserves existing robots.txt content'
);

// Does not duplicate the line if called twice
$twice = cozumel_robots_txt_add_sitemap($result);
assert_equal(
    substr_count($twice, 'Sitemap: https://cozumelhomes.net/wp-sitemap.xml'),
    1,
    'does not duplicate the sitemap directive'
);

test_summary_and_exit();
```

- [ ] **Step 2: Run test to verify it fails**

Run: `php tests/test-seo-technical.php`
Expected: Fatal error — `cozumel_robots_txt_add_sitemap()` not defined (the file doesn't exist yet).

- [ ] **Step 3: Write minimal implementation**

Create `theme/cozumel-homes/inc/seo-technical.php`:

```php
<?php
// Technical SEO basics: robots.txt sitemap directive + GA4 tag. Pure
// functions here are directly testable via `php tests/test-*.php`; the
// add_filter/add_action wiring at the bottom is WordPress glue only.

function cozumel_robots_txt_add_sitemap(string $output): string {
    $sitemap_line = 'Sitemap: https://cozumelhomes.net/wp-sitemap.xml';
    if (strpos($output, $sitemap_line) !== false) {
        return $output;
    }
    return rtrim($output) . "\n" . $sitemap_line . "\n";
}

add_filter('robots_txt', 'cozumel_robots_txt_add_sitemap', 10, 1);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `php tests/test-seo-technical.php`
Expected: All 3 assertions PASS, exit code 0.

- [ ] **Step 5: Require the new file**

In `theme/cozumel-homes/functions.php`, add near the other requires:

```php
require_once get_stylesheet_directory() . '/inc/seo-technical.php';
```

- [ ] **Step 6: Verify locally**

Start local dev, then: `curl -s "https://cozumel-homes.local/robots.txt" -k`
Expected: output includes `Sitemap: https://cozumelhomes.net/wp-sitemap.xml`
on its own line (note: the sitemap URL is hardcoded to production —
intentional, since that's the URL Google will actually crawl).

- [ ] **Step 7: Commit**

```bash
cd /Users/fernandogonzalez/Projects/Cozumel-Website
git add theme/cozumel-homes/inc/seo-technical.php theme/cozumel-homes/functions.php tests/test-seo-technical.php
git commit -m "feat: add robots.txt sitemap directive"
```

---

### Task 2: GA4 Tracking Snippet

**Files:**
- Modify: `theme/cozumel-homes/inc/seo-technical.php`
- Modify: `tests/test-seo-technical.php`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: `cozumel_ga4_script_tag(string $measurement_id): string` — pure
  function, returns the complete GA4 `gtag.js` script tag HTML for a given
  measurement ID. Hooked to `wp_head` on every page.

- [ ] **Step 1: This step requires Fernando — create the GA4 property**

In Google Analytics (analytics.google.com), create a GA4 property for
cozumelhomes.net (can use the same Google account planned for Search
Console in Task 6 — doesn't need to be Kelley's Workspace account). Copy the
Measurement ID (format `G-XXXXXXXXXX`) for Step 3.

- [ ] **Step 2: Write the failing test**

Append to `tests/test-seo-technical.php` (before `test_summary_and_exit();`):

```php
// GA4 script tag
$tag = cozumel_ga4_script_tag('G-TEST12345');
assert_equal(strpos($tag, "gtag/js?id=G-TEST12345") !== false, true, 'loads gtag.js with the measurement ID');
assert_equal(strpos($tag, "gtag('config', 'G-TEST12345')") !== false, true, 'configures gtag with the measurement ID');
assert_equal(strpos($tag, '<script') !== false, true, 'wraps output in a script tag');
```

- [ ] **Step 3: Run test to verify it fails**

Run: `php tests/test-seo-technical.php`
Expected: Fatal error — `cozumel_ga4_script_tag()` not defined.

- [ ] **Step 4: Write minimal implementation**

Append to `theme/cozumel-homes/inc/seo-technical.php` (before the
`add_filter('robots_txt', ...)` line stays where it is; add this above it):

```php
function cozumel_ga4_script_tag(string $measurement_id): string {
    $id = esc_js($measurement_id);
    return <<<HTML
<script async src="https://www.googletagmanager.com/gtag/js?id={$id}"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', '{$id}');
</script>
HTML;
}

// Real measurement ID from Step 1 — replace G-XXXXXXXXXX before deploying.
define('COZUMEL_GA4_MEASUREMENT_ID', 'G-XXXXXXXXXX');

add_action('wp_head', function () {
    echo cozumel_ga4_script_tag(COZUMEL_GA4_MEASUREMENT_ID);
});
```

- [ ] **Step 5: Replace the placeholder measurement ID**

Edit the `define('COZUMEL_GA4_MEASUREMENT_ID', ...)` line to use the real ID
copied in Step 1.

- [ ] **Step 6: Run test to verify it passes**

Run: `php tests/test-seo-technical.php`
Expected: All 6 assertions PASS, exit code 0 (the test uses a fixture ID,
unaffected by the real constant).

- [ ] **Step 7: Verify locally**

Start local dev, view page source on the homepage, confirm the
`googletagmanager.com/gtag/js?id=G-...` script tag is present with the real
measurement ID.

- [ ] **Step 8: Commit**

```bash
git add theme/cozumel-homes/inc/seo-technical.php tests/test-seo-technical.php
git commit -m "feat: add GA4 tracking snippet"
```

---

### Task 3: LodgingBusiness JSON-LD Schema for Rental Properties

**Files:**
- Create: `theme/cozumel-homes/inc/seo-schema.php`
- Modify: `theme/cozumel-homes/functions.php`
- Create: `tests/test-seo-schema.php`

**Interfaces:**
- Consumes: `rental-property` post meta (`address`, `neighborhood`,
  `base_rate`, `max_guests`) and `gallery_ids` meta, all already registered
  in `inc/meta-fields.php`.
- Produces: `cozumel_lodging_business_schema(int $post_id): array` — returns
  a JSON-LD-ready associative array for a single rental property. Used by
  Task 5's `wp_head` output; later tasks (4, 13) add sibling functions in
  the same file but don't call this one.

- [ ] **Step 1: Write the failing test**

Create `tests/test-seo-schema.php`:

```php
<?php
require_once __DIR__ . '/test-helpers.php';

// Stub the WordPress functions this pure logic depends on, so the test runs
// with plain `php` and no WordPress bootstrap — same approach the calendar
// sync tests use by keeping WP glue out of the pure functions entirely.
function get_post_meta($post_id, $key, $single = false) {
    global $__test_post_meta;
    return $__test_post_meta[$post_id][$key] ?? '';
}
function get_the_title($post_id) {
    global $__test_post_titles;
    return $__test_post_titles[$post_id] ?? '';
}
function get_permalink($post_id) {
    return "https://cozumelhomes.net/rentals/test-property-{$post_id}/";
}
function wp_get_attachment_image_url($attachment_id, $size) {
    return "https://cozumelhomes.net/wp-content/uploads/img-{$attachment_id}.jpg";
}

require_once __DIR__ . '/../theme/cozumel-homes/inc/seo-schema.php';

global $__test_post_meta, $__test_post_titles;
$__test_post_titles[42] = "Cozumel's Nah Ha Condominium 101";
$__test_post_meta[42] = [
    'address'      => 'North Shore Highway Km 3.3',
    'neighborhood' => 'North Shore',
    'base_rate'    => '325',
    'max_guests'   => '6',
    'gallery_ids'  => [101, 102],
];

$schema = cozumel_lodging_business_schema(42);

assert_equal($schema['@context'], 'https://schema.org', 'sets schema.org context');
assert_equal($schema['@type'], 'LodgingBusiness', 'sets LodgingBusiness type');
assert_equal($schema['name'], "Cozumel's Nah Ha Condominium 101", 'uses the post title as name');
assert_equal($schema['url'], 'https://cozumelhomes.net/rentals/test-property-42/', 'uses the permalink as url');
assert_equal($schema['address']['@type'], 'PostalAddress', 'nests a PostalAddress');
assert_equal($schema['address']['streetAddress'], 'North Shore Highway Km 3.3', 'uses the address meta field');
assert_equal($schema['address']['addressLocality'], 'Cozumel', 'hardcodes Cozumel as the locality');
assert_equal($schema['address']['addressRegion'], 'Quintana Roo', 'hardcodes Quintana Roo as the region');
assert_equal($schema['address']['addressCountry'], 'MX', 'hardcodes MX as the country');
assert_equal($schema['priceRange'], '$325', 'formats base_rate as a price range string');
assert_equal(count($schema['image']), 2, 'includes one image URL per gallery_ids entry');
assert_equal($schema['image'][0], 'https://cozumelhomes.net/wp-content/uploads/img-101.jpg', 'first image URL');

// Missing gallery_ids doesn't crash — empty image array instead
$__test_post_meta[43] = ['address' => 'Test St', 'neighborhood' => 'Downtown', 'base_rate' => '180', 'max_guests' => '4'];
$__test_post_titles[43] = 'Test Property No Photos';
$no_photos = cozumel_lodging_business_schema(43);
assert_equal($no_photos['image'], [], 'empty gallery_ids produces an empty image array, not a crash');

test_summary_and_exit();
```

- [ ] **Step 2: Run test to verify it fails**

Run: `php tests/test-seo-schema.php`
Expected: Fatal error — `cozumel_lodging_business_schema()` not defined (the file doesn't exist yet).

- [ ] **Step 3: Write minimal implementation**

Create `theme/cozumel-homes/inc/seo-schema.php`:

```php
<?php
// JSON-LD structured data generators. Pure functions — no WordPress calls
// beyond get_post_meta/get_the_title/get_permalink/wp_get_attachment_image_url,
// which the test file stubs directly so these run under plain `php`.

function cozumel_lodging_business_schema(int $post_id): array {
    $address = get_post_meta($post_id, 'address', true);
    $base_rate = get_post_meta($post_id, 'base_rate', true);
    $gallery_ids = get_post_meta($post_id, 'gallery_ids', true);
    if (!is_array($gallery_ids)) {
        $gallery_ids = [];
    }

    $images = array_map(
        fn($id) => wp_get_attachment_image_url($id, 'large'),
        $gallery_ids
    );

    return [
        '@context' => 'https://schema.org',
        '@type'    => 'LodgingBusiness',
        'name'     => get_the_title($post_id),
        'url'      => get_permalink($post_id),
        'address'  => [
            '@type'           => 'PostalAddress',
            'streetAddress'   => $address,
            'addressLocality' => 'Cozumel',
            'addressRegion'   => 'Quintana Roo',
            'addressCountry'  => 'MX',
        ],
        'priceRange' => $base_rate !== '' ? '$' . $base_rate : '',
        'image'      => $images,
    ];
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `php tests/test-seo-schema.php`
Expected: All 13 assertions PASS, exit code 0.

- [ ] **Step 5: Require the new file**

In `theme/cozumel-homes/functions.php`, add near the other requires:

```php
require_once get_stylesheet_directory() . '/inc/seo-schema.php';
```

(Output wiring to `wp_head` happens in Task 5, once Task 4's sibling
function also exists — keeps the `wp_head` hook in one place instead of
scattering `add_action` calls across tasks.)

- [ ] **Step 6: Commit**

```bash
git add theme/cozumel-homes/inc/seo-schema.php theme/cozumel-homes/functions.php tests/test-seo-schema.php
git commit -m "feat: add LodgingBusiness JSON-LD schema generator"
```

---

### Task 4: LocalBusiness JSON-LD Schema (Site-Wide)

**Files:**
- Modify: `theme/cozumel-homes/inc/seo-schema.php`
- Modify: `tests/test-seo-schema.php`

**Interfaces:**
- Consumes: nothing (static business identity data — no post meta).
- Produces: `cozumel_local_business_schema(): array` — returns a JSON-LD
  associative array describing the overall business, output on every page
  via Task 5.

- [ ] **Step 1: Write the failing test**

Append to `tests/test-seo-schema.php` (before `test_summary_and_exit();`):

```php
// Site-wide LocalBusiness schema
$business = cozumel_local_business_schema();
assert_equal($business['@context'], 'https://schema.org', 'sets schema.org context');
assert_equal($business['@type'], 'LocalBusiness', 'sets LocalBusiness type');
assert_equal($business['name'], 'Cozumel Homes', 'sets the business name');
assert_equal($business['url'], 'https://cozumelhomes.net', 'sets the site URL');
assert_equal($business['address']['addressLocality'], 'Cozumel', 'nests Cozumel as the locality');
assert_equal($business['address']['addressCountry'], 'MX', 'nests MX as the country');
```

- [ ] **Step 2: Run test to verify it fails**

Run: `php tests/test-seo-schema.php`
Expected: Fatal error — `cozumel_local_business_schema()` not defined.

- [ ] **Step 3: Write minimal implementation**

Append to `theme/cozumel-homes/inc/seo-schema.php`:

```php
function cozumel_local_business_schema(): array {
    return [
        '@context' => 'https://schema.org',
        '@type'    => 'LocalBusiness',
        'name'     => 'Cozumel Homes',
        'url'      => 'https://cozumelhomes.net',
        'address'  => [
            '@type'           => 'PostalAddress',
            'addressLocality' => 'Cozumel',
            'addressRegion'   => 'Quintana Roo',
            'addressCountry'  => 'MX',
        ],
    ];
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `php tests/test-seo-schema.php`
Expected: All 19 assertions PASS, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add theme/cozumel-homes/inc/seo-schema.php tests/test-seo-schema.php
git commit -m "feat: add site-wide LocalBusiness JSON-LD schema generator"
```

---

### Task 5: Wire Schema Output into wp_head + Deploy Phase 1

**Files:**
- Modify: `theme/cozumel-homes/inc/seo-schema.php`

**Interfaces:**
- Consumes: `cozumel_lodging_business_schema()` (Task 3) and
  `cozumel_local_business_schema()` (Task 4).
- Produces: nothing consumed by later tasks — this is the output wiring
  that makes Tasks 3-4 actually render on pages.

- [ ] **Step 1: Add the wp_head hook**

Append to `theme/cozumel-homes/inc/seo-schema.php`:

```php
add_action('wp_head', function () {
    if (is_singular('rental-property')) {
        $schema = cozumel_lodging_business_schema(get_the_ID());
        echo '<script type="application/ld+json">' . wp_json_encode($schema) . '</script>' . "\n";
    }

    $business_schema = cozumel_local_business_schema();
    echo '<script type="application/ld+json">' . wp_json_encode($business_schema) . '</script>' . "\n";
});
```

- [ ] **Step 2: Verify locally**

Start local dev, view page source on a rental property page, confirm two
`<script type="application/ld+json">` tags are present — one
`LodgingBusiness`, one `LocalBusiness`. View source on the homepage, confirm
only the `LocalBusiness` tag is present (no `LodgingBusiness` — not a
singular rental page).

- [ ] **Step 3: Validate the JSON-LD**

Copy one property page's `LodgingBusiness` JSON-LD block into Google's Rich
Results Test (https://search.google.com/test/rich-results), paste the raw
JSON. Expected: no errors (warnings about missing optional fields like
`review` are fine — not required for this task).

- [ ] **Step 4: Commit**

```bash
git add theme/cozumel-homes/inc/seo-schema.php
git commit -m "feat: output LodgingBusiness and LocalBusiness JSON-LD via wp_head"
```

- [ ] **Step 5: Push and deploy Phase 1 to production**

```bash
git push origin master
```

Following `Cozumel-Website/CLAUDE.md`'s deploy process, `scp` + `ssh`-copy:
`inc/seo-technical.php`, `inc/seo-schema.php`, `functions.php`. Run `php -l`
on each after copying, per the established pattern.

- [ ] **Step 6: Confirm on production**

```bash
curl -s "https://cozumelhomes.net/robots.txt" | grep Sitemap
curl -s "https://cozumelhomes.net/rentals/cozumels-nah-ha-condominium-101/" | grep -c "application/ld+json"
```
Expected: sitemap line present; at least 2 JSON-LD script tags found.

---

### Task 6: Google Search Console Verification (operational)

**Files:** none (external configuration, no code)

**Interfaces:** none — this task doesn't produce anything later tasks
consume programmatically; it produces a Search Console property that Task 15
references manually.

- [ ] **Step 1: This step requires Fernando — verify the property**

At https://search.google.com/search-console, add cozumelhomes.net as a
property. Use the domain-level verification method (DNS TXT record) since
DNS is already managed for the VPS setup — add the TXT record Google
provides to the domain's DNS.

- [ ] **Step 2: Confirm verification**

In Search Console, confirm the property shows "Ownership verified."

- [ ] **Step 3: Submit the sitemap**

In Search Console → Sitemaps, submit `wp-sitemap.xml`. Expected: status
"Success" within a few minutes to a few hours (Google fetches
asynchronously — this step doesn't need to be re-checked immediately).

No commit for this task — external configuration, not versioned code.

---

### Task 7: Google Business Profile (operational, partially blocked on Kelley)

**Files:** none (external configuration, no code)

**Interfaces:** none — final piece of Phase 1's local-signal work; Task 12
(NAP consistency) reads the address/phone published here.

- [ ] **Step 1: This step requires Kelley — confirm publishable details**

Before creating the listing, confirm with Kelley: the address or service
area she's comfortable publishing (a home-service-area radius is an option
if she doesn't want a public street address), the phone number to list, and
business hours (or "by appointment"/24-7 if that fits a rental business
better than fixed hours).

- [ ] **Step 2: This step requires Fernando — create the profile**

At https://business.google.com, create a Business Profile for "Cozumel
Homes" using the details from Step 1. Category: "Vacation home rental
agency" (or closest match available). Add the site URL
(https://cozumelhomes.net), and the same phone number that appears in the
site footer (checked in Task 12).

- [ ] **Step 3: Verify the profile**

Complete Google's verification flow (typically a postcard, phone, or email
verification depending on what Google offers for this business category).
This can take days for postcard verification — not something to block the
rest of the plan on.

- [ ] **Step 4: This step requires Kelley — grant manager access**

Once verified, from Business Profile settings → "Managers," Kelley invites
Fernando's Google account as a Manager. This does NOT require sharing her
Workspace password — it's a standard collaborator invite, same as adding
someone to a shared Google Doc.

No commit for this task — external configuration, not versioned code.

---

### Task 8: Page Speed Spot-Check (operational)

**Files:** potentially modify whatever the audit finds — see Step 2.

**Interfaces:** none.

- [ ] **Step 1: Run PageSpeed Insights**

At https://pagespeed.web.dev, run both mobile and desktop reports for
`https://cozumelhomes.net` (homepage) and one rental property page (e.g.
`https://cozumelhomes.net/rentals/cozumels-nah-ha-condominium-101/`). Record
the four scores and the top 3 "Opportunities" listed for each.

- [ ] **Step 2: Fix only clearly-cheap findings**

If the report flags something concrete and low-risk — e.g. an `<img>`
missing explicit `width`/`height` attributes, or a script that could load
with `defer` — fix it directly in the relevant template file. If the
findings are structural (e.g. "reduce unused JavaScript" pointing at a
third-party embed) or ambiguous, do NOT attempt a fix in this task — record
it as a follow-up note instead. This task closes obvious gaps only; it is
not a performance redesign.

- [ ] **Step 3: Re-run and record the delta**

Re-run PageSpeed Insights on any page that was changed. Note the before/after
scores in the commit message (if a fix was made) or in a follow-up note (if
not).

- [ ] **Step 4: Commit (only if a fix was made)**

```bash
git add <changed files>
git commit -m "perf: <specific fix>, PageSpeed <before> -> <after>"
```

---

### Task 9: TripAdvisor Listing Audit (operational)

**Files:** none.

**Interfaces:** produces a written finding Task 12 depends on (whether NAP
data exists on TripAdvisor to check for consistency).

- [ ] **Step 1: Search for existing listings**

Search TripAdvisor for each of the 3 properties by name ("Cozumel's Nah Ha
Condominium 101", "Cozumel's Cool Caribbean Views", "Cozumel's Casa
Bohemia"). Note whether a listing already exists (possibly from the prior
Lodgify-era setup) versus needs creating from scratch.

- [ ] **Step 2: Claim or create**

For each property: if a listing exists, claim it as the owner/manager. If
none exists, create one via TripAdvisor's free listing flow, using the same
name/address/description data as the corresponding site page.

- [ ] **Step 3: Record the published NAP data**

Write down the exact Name/Address/Phone as it now appears on each
TripAdvisor listing — Task 12 compares this against the site footer and
Google Business Profile.

No commit for this task — external configuration, not versioned code.

---

### Task 10: Local Directory Research (operational)

**Files:** none.

**Interfaces:** none.

- [ ] **Step 1: Identify candidate directories**

Research whether Quintana Roo or Cozumel municipal tourism boards offer free
business listings (many state/municipal tourism sites in Mexico do). Also
check general free vacation-rental directories that don't require a paid
tier.

- [ ] **Step 2: Submit to any that qualify**

For each directory that (a) is free and (b) is a legitimate, indexed site
(not a spam link farm — check it has real organic traffic/content, not just
a list of outbound links), submit a listing using consistent NAP data.

- [ ] **Step 3: Record what was submitted**

Keep a simple list (property name, directory name, URL, date submitted) for
future reference — this doesn't need to live in the repo, a note is enough.

No commit for this task — external configuration, not versioned code.

---

### Task 11: Partner Cross-Link Outreach (operational, code deferred)

**Files:** none in this task.

**Interfaces:** none — if outreach succeeds, the resulting link is a
one-line addition to `footer.php` at that time, not scoped here since the
partner names/URLs aren't known yet.

- [ ] **Step 1: Identify candidate partners**

With Kelley, list any dive shops, tour operators, or restaurants she
regularly recommends to guests that have their own websites.

- [ ] **Step 2: Reach out**

For each candidate, propose a reciprocal link: her site links their
business (as a genuine recommendation, matching what she already tells
guests informally), they link her rentals. This is a real value-add
recommendation, not a link scheme — only pursue it where the recommendation
would be made anyway.

- [ ] **Step 3: If a partner agrees, add the link**

This is a one-line addition to the existing links pattern in
`theme/cozumel-homes/footer.php` (`esc_url()` wrapped anchor tag, matching
whatever pattern already exists there for other outbound links). Small
enough not to warrant its own TDD task — do it inline when a partner
actually confirms, then commit with a message naming the partner.

No commit for this task on its own — external outreach, not code.

---

### Task 12: NAP Consistency Audit (operational)

**Files:** possibly `theme/cozumel-homes/footer.php` if a mismatch is found.

**Interfaces:** Consumes: Business Profile phone/address from Task 7,
TripAdvisor NAP from Task 9.

- [ ] **Step 1: Compare NAP across all three sources**

List Name/Address/Phone exactly as published on: the site footer, the
Google Business Profile (Task 7), and TripAdvisor (Task 9). Flag any
mismatch (even minor formatting differences like "St." vs "Street" can hurt
local ranking).

- [ ] **Step 2: Fix the site footer if it's the odd one out**

If the site footer's NAP data doesn't match Task 7/9, update
`theme/cozumel-homes/footer.php` to match. If Google Business Profile or
TripAdvisor is wrong instead, fix it there directly (external, no code).

- [ ] **Step 3: Commit (only if footer.php changed)**

```bash
git add theme/cozumel-homes/footer.php
git commit -m "fix: align footer NAP data with Google Business Profile / TripAdvisor"
```

---

### Task 13: Article JSON-LD Schema for Blog Posts

**Files:**
- Modify: `theme/cozumel-homes/inc/seo-schema.php`
- Modify: `tests/test-seo-schema.php`

**Interfaces:**
- Consumes: standard WordPress `post` fields (title, date, author) — no
  custom post meta.
- Produces: `cozumel_article_schema(int $post_id): array` — output wired
  into the same `wp_head` hook from Task 5.

- [ ] **Step 1: Write the failing test**

Append to `tests/test-seo-schema.php` (before `test_summary_and_exit();`),
and add these stubs near the top of the file alongside the existing ones
(after the `get_permalink` stub):

```php
function get_the_date($format, $post_id) {
    return '2026-08-16';
}
function get_the_author_meta($field, $user_id = null) {
    return 'Kelley';
}
```

Then the test itself:

```php
// Article schema for blog posts
$__test_post_titles[44] = 'Meet Your Host: Kelley';
$article = cozumel_article_schema(44);
assert_equal($article['@context'], 'https://schema.org', 'sets schema.org context');
assert_equal($article['@type'], 'Article', 'sets Article type');
assert_equal($article['headline'], 'Meet Your Host: Kelley', 'uses the post title as headline');
assert_equal($article['datePublished'], '2026-08-16', 'uses get_the_date as datePublished');
assert_equal($article['author']['@type'], 'Person', 'nests a Person author');
assert_equal($article['author']['name'], 'Kelley', 'uses get_the_author_meta as author name');
```

- [ ] **Step 2: Run test to verify it fails**

Run: `php tests/test-seo-schema.php`
Expected: Fatal error — `cozumel_article_schema()` not defined.

- [ ] **Step 3: Write minimal implementation**

Append to `theme/cozumel-homes/inc/seo-schema.php`:

```php
function cozumel_article_schema(int $post_id): array {
    return [
        '@context'      => 'https://schema.org',
        '@type'         => 'Article',
        'headline'      => get_the_title($post_id),
        'datePublished' => get_the_date('Y-m-d', $post_id),
        'author'        => [
            '@type' => 'Person',
            'name'  => get_the_author_meta('display_name'),
        ],
    ];
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `php tests/test-seo-schema.php`
Expected: All 25 assertions PASS, exit code 0.

- [ ] **Step 5: Wire into wp_head**

In `theme/cozumel-homes/inc/seo-schema.php`, modify the `wp_head` callback
added in Task 5 to add an `is_single()` branch (standard WordPress `post`
type — blog posts use the default type, not a custom one):

```php
add_action('wp_head', function () {
    if (is_singular('rental-property')) {
        $schema = cozumel_lodging_business_schema(get_the_ID());
        echo '<script type="application/ld+json">' . wp_json_encode($schema) . '</script>' . "\n";
    }

    if (is_single() && get_post_type() === 'post') {
        $article_schema = cozumel_article_schema(get_the_ID());
        echo '<script type="application/ld+json">' . wp_json_encode($article_schema) . '</script>' . "\n";
    }

    $business_schema = cozumel_local_business_schema();
    echo '<script type="application/ld+json">' . wp_json_encode($business_schema) . '</script>' . "\n";
});
```

- [ ] **Step 6: Verify locally**

View page source on the "Meet Your Hosts" post, confirm an `Article`
JSON-LD block is present alongside the `LocalBusiness` block (and no
`LodgingBusiness` block, since a blog post isn't a rental property page).

- [ ] **Step 7: Commit and deploy**

```bash
git add theme/cozumel-homes/inc/seo-schema.php tests/test-seo-schema.php
git commit -m "feat: add Article JSON-LD schema for blog posts"
git push origin master
```

Deploy `inc/seo-schema.php` to production following the established
`scp`/`ssh` process, run `php -l` after copying.

---

### Task 14: Search Console URL Inspection Workflow (operational)

**Files:** none — this is a repeatable process to follow for every future
post, not a one-time task.

**Interfaces:** Consumes: the Search Console property from Task 6.

- [ ] **Step 1: Document the workflow**

For every new blog post published from here forward: after publishing, open
Search Console → URL Inspection, paste the post's URL, click "Request
Indexing." This is free and speeds up how quickly Google crawls new content
instead of waiting for the next scheduled crawl.

- [ ] **Step 2: Apply it to the most recent post now**

Run this workflow once now for the existing "Meet Your Hosts" post, as a
concrete first pass rather than only a written instruction for the future.

No commit for this task — process documentation lives in this plan, not in
the repo.

---

### Task 15: "Book Direct" Content Piece (blocked on Kelley sign-off)

**Files:** none in this task — drafting happens in a follow-up pass once
unblocked, using the `seo-copywriting` skill.

**Interfaces:** Consumes: `cozumel_article_schema()` from Task 13 (the
published piece gets the same Article schema automatically, no extra work).

- [ ] **Step 1: This step requires Kelley — confirm sign-off**

Before drafting anything, confirm with Kelley that she's comfortable with a
piece naming Airbnb's cancellation-policy mechanics specifically: guests can
cancel weeks or months out with no percentage penalty, a policy Airbnb set
unilaterally and hosts never consented to, with hosts absorbing the
resulting revenue loss. Confirm the framing (Airbnb's decision, not a claim
about renter behavior or "everyone leaving Airbnb") reads right to her
before it becomes public-facing copy.

- [ ] **Step 2: Draft using the seo-copywriting skill**

Once confirmed, invoke the `seo-copywriting` skill to draft the piece,
tying it to Kelley's since-1997 longevity claim (already approved in
`2026-08-10-seo-content-strategy-design.md`) as the "why book direct with an
established host" close.

- [ ] **Step 3: Publish and run Task 14's indexing workflow**

Publish as a standard `post` (so Task 13's Article schema applies
automatically), then immediately run the Search Console URL Inspection /
Request Indexing workflow from Task 14.

- [ ] **Step 4: Commit (if any code/content lives in the repo)**

Only applies if the post content is drafted as a versioned file rather than
directly in wp-admin — follow whatever pattern the "Meet Your Hosts" post
used, since that's the established precedent for this site's blog content.
