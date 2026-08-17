# Airbnb Calendar Sync + Public Availability Calendar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep Airbnb availability in sync with the website (both directions) for the 3 rental properties, enforce a 1-day cleaning buffer everywhere, and show guests a clickable availability calendar that feeds the existing "Request to Book" form.

**Architecture:** Pure, framework-free PHP functions do the iCal parsing/buffering/generation (no WordPress dependency, directly testable via plain `php` scripts). A WP-CLI command wraps them with WordPress I/O (fetch, read/write post meta, write the outbound `.ics` file) and is triggered by a real system cron job on the VPS — no daemon, no new runtime. A REST endpoint exposes computed availability to a small vanilla-JS calendar widget on each rental page.

**Tech Stack:** PHP (WordPress theme, no new dependencies), WP-CLI, vanilla JS, plain cron. No PHPUnit/Composer introduced — this repo has no existing test framework, so pure-logic tasks below use small standalone `php` assertion scripts (a project convention established in this plan, not an existing one) instead of adding new tooling.

**Spec:** `docs/superpowers/specs/2026-08-14-airbnb-calendar-sync-design.md`

## Global Constraints

- Targets **Airbnb directly**, not Lodgify (Lodgify is being canceled 2026-08-18).
- Applies to the 3 rental properties only (`rental-property` post type) — the for-sale property is excluded.
- 1-day cleaning buffer must be enforced consistently: public calendar, and the outbound `.ics` sent to Airbnb.
- No new always-running service (no Python daemon) — WP-CLI + system cron only.
- Cron failure alerts go to `fgmanta@gmail.com` only, via the existing `phpmailer_init` SMTP hook (see `[[inquiry_form_smtp_broken]]` memory) — never to Kelley.
- Calendar is clickable (selects dates into the existing inquiry form) but not click-to-book — no payment, no auto-confirm.
- Reuse the existing `airbnb_ical_url` / `airbnb_listing_url` post meta fields already registered in `inc/meta-fields.php` (were previously unused placeholders) — do not invent new field names for these.
- Production deploys are manual `scp`/`ssh` (see `Cozumel-Website/CLAUDE.md` "Production Deployment" section) — local dev's theme dir is a symlink into the repo, committing does NOT auto-deploy.

---

### Task 1: iCal VEVENT Parser (pure PHP)

**Files:**
- Create: `theme/cozumel-homes/inc/ical-sync.php`
- Create: `tests/test-helpers.php`
- Create: `tests/test-ical-parser.php`

**Interfaces:**
- Produces: `cozumel_ical_parse_vevents(string $ics_text): array` — returns an array of associative arrays `['start' => 'Y-m-d', 'end' => 'Y-m-d']`, one per `VEVENT` block found. `end` is the `DTEND` value as-is (exclusive checkout date, per iCal convention — this is what later tasks assume).

- [ ] **Step 1: Write the test helper**

Create `tests/test-helpers.php`:

```php
<?php
$GLOBALS['__test_failures'] = 0;

function assert_equal($actual, $expected, string $message): void {
    if ($actual === $expected) {
        echo "PASS: {$message}\n";
    } else {
        echo "FAIL: {$message}\n";
        echo "  expected: " . var_export($expected, true) . "\n";
        echo "  actual:   " . var_export($actual, true) . "\n";
        $GLOBALS['__test_failures']++;
    }
}

function test_summary_and_exit(): void {
    if ($GLOBALS['__test_failures'] > 0) {
        echo "\n{$GLOBALS['__test_failures']} failure(s)\n";
        exit(1);
    }
    echo "\nAll tests passed\n";
    exit(0);
}
```

- [ ] **Step 2: Write the failing test**

Create `tests/test-ical-parser.php`:

```php
<?php
require_once __DIR__ . '/test-helpers.php';
require_once __DIR__ . '/../theme/cozumel-homes/inc/ical-sync.php';

// Two-event fixture, CRLF line endings (real Airbnb feeds use CRLF)
$fixture = "BEGIN:VCALENDAR\r\n" .
    "VERSION:2.0\r\n" .
    "BEGIN:VEVENT\r\n" .
    "UID:1@airbnb.com\r\n" .
    "DTSTART;VALUE=DATE:20260901\r\n" .
    "DTEND;VALUE=DATE:20260905\r\n" .
    "SUMMARY:Reserved\r\n" .
    "END:VEVENT\r\n" .
    "BEGIN:VEVENT\r\n" .
    "UID:2@airbnb.com\r\n" .
    "DTSTART;VALUE=DATE:20260920\r\n" .
    "DTEND;VALUE=DATE:20260922\r\n" .
    "SUMMARY:Reserved\r\n" .
    "END:VEVENT\r\n" .
    "END:VCALENDAR\r\n";

$result = cozumel_ical_parse_vevents($fixture);

assert_equal(count($result), 2, 'parses two VEVENT blocks');
assert_equal($result[0]['start'], '2026-09-01', 'first event start date');
assert_equal($result[0]['end'], '2026-09-05', 'first event end date');
assert_equal($result[1]['start'], '2026-09-20', 'second event start date');
assert_equal($result[1]['end'], '2026-09-22', 'second event end date');

// Empty feed
assert_equal(cozumel_ical_parse_vevents("BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n"), [], 'empty feed returns empty array');

test_summary_and_exit();
```

- [ ] **Step 3: Run test to verify it fails**

Run: `php tests/test-ical-parser.php`
Expected: Fatal error — `cozumel_ical_parse_vevents()` not defined (the file doesn't exist yet).

- [ ] **Step 4: Write minimal implementation**

Create `theme/cozumel-homes/inc/ical-sync.php`:

```php
<?php
// Pure, framework-free iCal helpers — no WordPress functions used here so
// these are directly testable via `php tests/test-*.php`, no WP bootstrap
// needed. WordPress-facing glue lives in inc/cli-sync-calendars.php.

function cozumel_ical_parse_vevents(string $ics_text): array {
    $events = [];
    $blocks = preg_split('/BEGIN:VEVENT\r?\n/', $ics_text);
    array_shift($blocks); // drop everything before the first VEVENT

    foreach ($blocks as $block) {
        $end_pos = strpos($block, 'END:VEVENT');
        if ($end_pos === false) continue;
        $body = substr($block, 0, $end_pos);

        if (!preg_match('/DTSTART[^:]*:(\d{8})/', $body, $start_match)) continue;
        if (!preg_match('/DTEND[^:]*:(\d{8})/', $body, $end_match)) continue;

        $events[] = [
            'start' => cozumel_ical_date_to_iso($start_match[1]),
            'end'   => cozumel_ical_date_to_iso($end_match[1]),
        ];
    }

    return $events;
}

function cozumel_ical_date_to_iso(string $yyyymmdd): string {
    return substr($yyyymmdd, 0, 4) . '-' . substr($yyyymmdd, 4, 2) . '-' . substr($yyyymmdd, 6, 2);
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `php tests/test-ical-parser.php`
Expected: All 6 assertions PASS, exit code 0.

- [ ] **Step 6: Commit**

```bash
cd /Users/fernandogonzalez/Projects/Cozumel-Website
git add theme/cozumel-homes/inc/ical-sync.php tests/test-helpers.php tests/test-ical-parser.php
git commit -m "feat: add pure PHP iCal VEVENT parser with standalone tests"
```

---

### Task 2: Cleaning Buffer Logic (pure PHP)

**Files:**
- Modify: `theme/cozumel-homes/inc/ical-sync.php`
- Create: `tests/test-ical-buffer.php`

**Interfaces:**
- Consumes: date-range arrays in the `['start' => 'Y-m-d', 'end' => 'Y-m-d']` shape produced by Task 1.
- Produces: `cozumel_ical_apply_buffer(array $ranges, int $buffer_days): array` — returns a new array of `['start' => 'Y-m-d', 'end' => 'Y-m-d']` ranges, each `end` pushed forward by `$buffer_days`. Does not merge overlapping ranges (not needed — overlapping/adjacent buffered ranges are harmless for both the public display and the outbound `.ics`, and merging adds complexity with no behavioral benefit).

- [ ] **Step 1: Write the failing test**

Create `tests/test-ical-buffer.php`:

```php
<?php
require_once __DIR__ . '/test-helpers.php';
require_once __DIR__ . '/../theme/cozumel-homes/inc/ical-sync.php';

$ranges = [
    ['start' => '2026-09-01', 'end' => '2026-09-05'],
    ['start' => '2026-09-20', 'end' => '2026-09-22'],
];

$buffered = cozumel_ical_apply_buffer($ranges, 1);

assert_equal(count($buffered), 2, 'same number of ranges out as in');
assert_equal($buffered[0]['start'], '2026-09-01', 'start date unchanged');
assert_equal($buffered[0]['end'], '2026-09-06', 'end date pushed forward by 1 day');
assert_equal($buffered[1]['end'], '2026-09-23', 'second range end date pushed forward by 1 day');

// Zero buffer is a no-op
$unbuffered = cozumel_ical_apply_buffer($ranges, 0);
assert_equal($unbuffered[0]['end'], '2026-09-05', 'zero buffer leaves end date unchanged');

// Month-boundary case
$boundary = cozumel_ical_apply_buffer([['start' => '2026-09-01', 'end' => '2026-09-30']], 1);
assert_equal($boundary[0]['end'], '2026-10-01', 'buffer correctly rolls over a month boundary');

// Empty input
assert_equal(cozumel_ical_apply_buffer([], 1), [], 'empty input returns empty output');

test_summary_and_exit();
```

- [ ] **Step 2: Run test to verify it fails**

Run: `php tests/test-ical-buffer.php`
Expected: Fatal error — `cozumel_ical_apply_buffer()` not defined.

- [ ] **Step 3: Write minimal implementation**

Append to `theme/cozumel-homes/inc/ical-sync.php`:

```php
function cozumel_ical_apply_buffer(array $ranges, int $buffer_days): array {
    $buffered = [];
    foreach ($ranges as $range) {
        $end = new DateTime($range['end']);
        $end->modify("+{$buffer_days} day" . ($buffer_days === 1 ? '' : 's'));
        $buffered[] = [
            'start' => $range['start'],
            'end'   => $end->format('Y-m-d'),
        ];
    }
    return $buffered;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `php tests/test-ical-buffer.php`
Expected: All 6 assertions PASS, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add theme/cozumel-homes/inc/ical-sync.php tests/test-ical-buffer.php
git commit -m "feat: add cleaning-buffer padding logic with standalone tests"
```

---

### Task 3: Outbound .ics Generator (pure PHP)

**Files:**
- Modify: `theme/cozumel-homes/inc/ical-sync.php`
- Create: `tests/test-ical-generator.php`

**Interfaces:**
- Consumes: buffered date-range arrays from Task 2's output shape.
- Produces: `cozumel_ical_generate(array $ranges, string $calendar_name): string` — returns complete `.ics` file text (CRLF line endings, one `VEVENT` per range, `DTSTART`/`DTEND` as `VALUE=DATE`).

- [ ] **Step 1: Write the failing test**

Create `tests/test-ical-generator.php`:

```php
<?php
require_once __DIR__ . '/test-helpers.php';
require_once __DIR__ . '/../theme/cozumel-homes/inc/ical-sync.php';

$ranges = [
    ['start' => '2026-09-01', 'end' => '2026-09-06'],
];

$ics = cozumel_ical_generate($ranges, 'Cozumel Cool Caribbean Views');

assert_equal(strpos($ics, "BEGIN:VCALENDAR\r\n") === 0, true, 'starts with BEGIN:VCALENDAR');
assert_equal(strpos($ics, "END:VCALENDAR\r\n") !== false, true, 'contains END:VCALENDAR');
assert_equal(strpos($ics, "BEGIN:VEVENT\r\n") !== false, true, 'contains a VEVENT');
assert_equal(strpos($ics, "DTSTART;VALUE=DATE:20260901\r\n") !== false, true, 'DTSTART formatted correctly');
assert_equal(strpos($ics, "DTEND;VALUE=DATE:20260906\r\n") !== false, true, 'DTEND formatted correctly');
assert_equal(strpos($ics, "X-WR-CALNAME:Cozumel Cool Caribbean Views\r\n") !== false, true, 'calendar name included');

// Round-trip: what we generate, our own parser can read back
$roundtrip = cozumel_ical_parse_vevents($ics);
assert_equal($roundtrip[0]['start'], '2026-09-01', 'round-trip start matches');
assert_equal($roundtrip[0]['end'], '2026-09-06', 'round-trip end matches');

// Empty ranges still produce a valid (empty) calendar
$empty_ics = cozumel_ical_generate([], 'Empty Property');
assert_equal(strpos($empty_ics, "BEGIN:VCALENDAR\r\n") === 0, true, 'empty ranges still produce valid VCALENDAR wrapper');

test_summary_and_exit();
```

- [ ] **Step 2: Run test to verify it fails**

Run: `php tests/test-ical-generator.php`
Expected: Fatal error — `cozumel_ical_generate()` not defined.

- [ ] **Step 3: Write minimal implementation**

Append to `theme/cozumel-homes/inc/ical-sync.php`:

```php
function cozumel_ical_generate(array $ranges, string $calendar_name): string {
    $lines = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "PRODID:-//Cozumel Homes//Availability Sync//EN",
        "X-WR-CALNAME:{$calendar_name}",
    ];

    foreach ($ranges as $i => $range) {
        $start = str_replace('-', '', $range['start']);
        $end   = str_replace('-', '', $range['end']);
        $lines[] = "BEGIN:VEVENT";
        $lines[] = "UID:cozumel-{$i}-{$start}@cozumelhomes.net";
        $lines[] = "DTSTART;VALUE=DATE:{$start}";
        $lines[] = "DTEND;VALUE=DATE:{$end}";
        $lines[] = "SUMMARY:Unavailable";
        $lines[] = "END:VEVENT";
    }

    $lines[] = "END:VCALENDAR";

    return implode("\r\n", $lines) . "\r\n";
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `php tests/test-ical-generator.php`
Expected: All 9 assertions PASS, exit code 0.

- [ ] **Step 5: Run all three test scripts together as a sanity check**

Run: `php tests/test-ical-parser.php && php tests/test-ical-buffer.php && php tests/test-ical-generator.php`
Expected: All three exit 0.

- [ ] **Step 6: Commit**

```bash
git add theme/cozumel-homes/inc/ical-sync.php tests/test-ical-generator.php
git commit -m "feat: add outbound .ics generator with standalone tests"
```

---

### Task 4: New Post Meta Fields

**Files:**
- Modify: `theme/cozumel-homes/inc/meta-fields.php`

**Interfaces:**
- Produces: two new `rental-property` post meta keys available via `get_post_meta()`/REST for later tasks — `manual_blocked_dates` (string, JSON-encoded array of `['start','end']`, admin-editable) and `airbnb_blocked_dates` (string, JSON-encoded array of `['start','end']`, sync-managed only, not shown in the admin UI — same pattern as the existing `mac_id` "managed by sync" field).

- [ ] **Step 1: Register the two new meta keys**

In `theme/cozumel-homes/inc/meta-fields.php`, modify the `$rental_fields` array (around line 4-8):

```php
    $rental_fields = [
        'mac_id', 'neighborhood', 'address', 'base_rate', 'status',
        'max_guests', 'bedrooms', 'bathrooms',
        'latitude', 'longitude', 'airbnb_ical_url', 'airbnb_listing_url',
        'manual_blocked_dates', 'airbnb_blocked_dates',
    ];
```

- [ ] **Step 2: Add the manual-holds field to the admin meta box**

In `cozumel_rental_meta_box_html()` (around line 70-84), add after the `airbnb_listing_url` line:

```php
    cozumel_meta_field('airbnb_listing_url',  'Airbnb Listing URL', $post->ID);
    $manual_blocked = esc_textarea(get_post_meta($post->ID, 'manual_blocked_dates', true));
    echo "<p><label style='font-weight:600'>Manual Holds (JSON array of {\"start\":\"YYYY-MM-DD\",\"end\":\"YYYY-MM-DD\"}, e.g. maintenance/personal use)</label><br>";
    echo "<textarea name='manual_blocked_dates' style='width:100%;height:60px;margin-top:4px' placeholder='[]'>{$manual_blocked}</textarea></p>";
    $airbnb_blocked = get_post_meta($post->ID, 'airbnb_blocked_dates', true);
    echo "<p style='color:#6b6b6b;font-size:0.85rem'>Airbnb-synced blocked dates (managed by the sync cron — do not edit): " . esc_html($airbnb_blocked ?: '(none yet — sync has not run)') . "</p>";
```

- [ ] **Step 3: Save the new manual-holds field on post save**

In `cozumel_save_meta()` (around line 124-151), add `'manual_blocked_dates'` to the `$all_fields` array and give it JSON-aware sanitization instead of plain text sanitization. Replace the function body's field loop:

```php
    $all_fields = [
        'mac_id', 'neighborhood', 'address', 'base_rate', 'status',
        'max_guests', 'bedrooms', 'bathrooms',
        'latitude', 'longitude', 'airbnb_ical_url', 'airbnb_listing_url',
        'asking_price', 'listing_url', 'notes',
    ];
    foreach ($all_fields as $field) {
        if (array_key_exists($field, $_POST)) {
            $value = ($field === 'notes')
                ? sanitize_textarea_field($_POST[$field])
                : sanitize_text_field($_POST[$field]);
            update_post_meta($post_id, $field, $value);
        }
    }

    if (array_key_exists('manual_blocked_dates', $_POST)) {
        $raw = wp_unslash($_POST['manual_blocked_dates']);
        $decoded = json_decode($raw, true);
        // Only save if it's valid JSON representing an array — an admin
        // typo shouldn't silently corrupt the stored value into garbage.
        if (is_array($decoded)) {
            update_post_meta($post_id, 'manual_blocked_dates', wp_json_encode($decoded));
        }
    }
```

Note `airbnb_blocked_dates` is deliberately NOT in this save handler — it's written only by the sync cron (Task 5), never by the admin form, matching the "do not edit" label from Step 2.

- [ ] **Step 4: Manually verify in wp-admin (local dev)**

Open `https://cozumel-homes.local/wp-admin/post.php?post=24&action=edit` (Cool Caribbean Views, adjust ID/URL for your local dev), confirm the "Manual Holds" textarea and the "(none yet — sync has not run)" line both render under Property Details. Type `[{"start":"2026-09-01","end":"2026-09-03"}]` into Manual Holds, click Update, reload the page, confirm the value persisted.

- [ ] **Step 5: Commit**

```bash
git add theme/cozumel-homes/inc/meta-fields.php
git commit -m "feat: add manual_blocked_dates and airbnb_blocked_dates post meta"
```

---

### Task 5: WP-CLI Sync Command

**Files:**
- Create: `theme/cozumel-homes/inc/cli-sync-calendars.php`
- Modify: `theme/cozumel-homes/functions.php`

**Interfaces:**
- Consumes: `cozumel_ical_parse_vevents()`, `cozumel_ical_apply_buffer()`, `cozumel_ical_generate()` from Task 1-3; `manual_blocked_dates`/`airbnb_blocked_dates`/`airbnb_ical_url` post meta from Task 4.
- Produces: registers `wp cozumel sync-calendars` as a WP-CLI command; writes `wp-content/uploads/calendars/<property-slug>.ics` per rental property; sends failure emails via `wp_mail()`.

- [ ] **Step 1: Write the command file**

Create `theme/cozumel-homes/inc/cli-sync-calendars.php`:

```php
<?php
if (!defined('WP_CLI') || !WP_CLI) {
    return;
}

require_once __DIR__ . '/ical-sync.php';

class Cozumel_Sync_Calendars_Command {
    /**
     * Fetch each rental property's Airbnb iCal feed, store blocked dates,
     * and republish the outbound .ics with the cleaning buffer applied.
     */
    public function __invoke($args, $assoc_args) {
        $buffer_days = 1;
        $properties = get_posts([
            'post_type'      => 'rental-property',
            'posts_per_page' => -1,
            'post_status'    => 'publish',
        ]);

        $failures = [];

        foreach ($properties as $property) {
            $result = $this->sync_one($property, $buffer_days);
            if ($result !== true) {
                $failures[] = "{$property->post_title}: {$result}";
            }
        }

        if (!empty($failures)) {
            $this->email_failures($failures);
            WP_CLI::warning('Completed with ' . count($failures) . ' failure(s): ' . implode('; ', $failures));
        } else {
            WP_CLI::success('Synced ' . count($properties) . ' propert' . (count($properties) === 1 ? 'y' : 'ies') . '.');
        }
    }

    /**
     * @return true|string true on success, error description on failure
     */
    private function sync_one($property, int $buffer_days) {
        $airbnb_url = get_post_meta($property->ID, 'airbnb_ical_url', true);
        if (empty($airbnb_url)) {
            return 'no airbnb_ical_url set, skipped';
        }

        $response = wp_remote_get($airbnb_url, ['timeout' => 20]);
        if (is_wp_error($response)) {
            return 'fetch failed: ' . $response->get_error_message();
        }
        if (wp_remote_retrieve_response_code($response) !== 200) {
            return 'fetch returned HTTP ' . wp_remote_retrieve_response_code($response);
        }

        $body = wp_remote_retrieve_body($response);
        $airbnb_ranges = cozumel_ical_parse_vevents($body);
        if (empty($airbnb_ranges) && strpos($body, 'BEGIN:VCALENDAR') === false) {
            // Not even a valid calendar response — don't overwrite good data
            // with garbage from a malformed/non-iCal response body.
            return 'response was not a valid iCal feed';
        }

        // Inbound: overwrite with fresh data — Airbnb's feed is the full
        // source of truth for this leg, on success only.
        update_post_meta($property->ID, 'airbnb_blocked_dates', wp_json_encode($airbnb_ranges));

        // Outbound: combine Airbnb + manual holds, apply the buffer, publish.
        $manual_raw = get_post_meta($property->ID, 'manual_blocked_dates', true);
        $manual_ranges = json_decode($manual_raw ?: '[]', true);
        if (!is_array($manual_ranges)) {
            $manual_ranges = [];
        }

        $combined = array_merge($airbnb_ranges, $manual_ranges);
        $buffered = cozumel_ical_apply_buffer($combined, $buffer_days);
        $ics = cozumel_ical_generate($buffered, $property->post_title);

        $write_result = $this->write_ics_file($property->post_name, $ics);
        if ($write_result !== true) {
            return $write_result;
        }

        return true;
    }

    /**
     * @return true|string true on success, error description on failure
     */
    private function write_ics_file(string $slug, string $ics_content) {
        $upload_dir = wp_upload_dir();
        $calendars_dir = trailingslashit($upload_dir['basedir']) . 'calendars';

        if (!file_exists($calendars_dir)) {
            if (!wp_mkdir_p($calendars_dir)) {
                return "could not create {$calendars_dir}";
            }
        }

        $path = trailingslashit($calendars_dir) . "{$slug}.ics";
        $tmp_path = "{$path}.tmp";

        // Write to a temp file then rename — an interrupted write must
        // never leave a truncated/empty .ics that would clear Airbnb's
        // import on its next poll.
        if (file_put_contents($tmp_path, $ics_content) === false) {
            return "could not write {$tmp_path}";
        }
        if (!rename($tmp_path, $path)) {
            @unlink($tmp_path);
            return "could not finalize {$path}";
        }

        return true;
    }

    private function email_failures(array $failures): void {
        $to = 'fgmanta@gmail.com';
        $subject = 'Cozumel Homes: calendar sync failure';
        $body = "The calendar sync cron hit " . count($failures) . " failure(s):\n\n"
            . implode("\n", $failures)
            . "\n\nLast-known-good data was preserved for any failed property.";
        wp_mail($to, $subject, $body);
    }
}

WP_CLI::add_command('cozumel sync-calendars', 'Cozumel_Sync_Calendars_Command');
```

- [ ] **Step 2: Require the new file**

In `theme/cozumel-homes/functions.php`, add near the other `require_once` lines (after the `dev-application-passwords.php` line):

```php
require_once get_stylesheet_directory() . '/inc/cli-sync-calendars.php';
```

- [ ] **Step 3: Verify the command registers (local dev)**

Run (from the Local by Flywheel Site Shell for `cozumel-homes`):
```bash
wp cli has-command 'cozumel sync-calendars'
```
Expected: exits 0 (command found), no error output.

- [ ] **Step 4: Verify failure path with a deliberately broken URL**

In local dev wp-admin, temporarily set Cool Caribbean Views' `airbnb_ical_url` field to `https://example.com/does-not-exist.ics`, then run:
```bash
wp cozumel sync-calendars
```
Expected: WP-CLI prints a warning mentioning "fetch returned HTTP 404" (or similar) for that property, and `airbnb_blocked_dates` for that property is unchanged from before the run (check via `wp post meta get 24 airbnb_blocked_dates`). Restore the correct/blank URL afterward.

- [ ] **Step 5: Verify success path with a fixture calendar**

Temporarily set the same property's `airbnb_ical_url` to a URL serving the same fixture text used in Task 1's test (host it anywhere reachable, e.g. a GitHub Gist raw URL, or a temp file served via `python3 -m http.server` if testing locally against the VPS isn't possible yet). Run `wp cozumel sync-calendars` again, then confirm:
```bash
wp post meta get 24 airbnb_blocked_dates
cat "$(wp eval 'echo wp_upload_dir()["basedir"];')/calendars/cozumels-cool-caribbean-views.ics"
```
Expected: `airbnb_blocked_dates` shows the parsed JSON; the `.ics` file exists and contains a `VEVENT` with the buffered (1-day-later) `DTEND`.

- [ ] **Step 6: Commit**

```bash
git add theme/cozumel-homes/inc/cli-sync-calendars.php theme/cozumel-homes/functions.php
git commit -m "feat: add wp-cli calendar sync command with failure-preserving error handling"
```

---

### Task 6: System Cron Installation (VPS, operational)

**Files:** none (server configuration, no code)

**Interfaces:** none — this task wires the already-built command (Task 5) to a schedule; nothing later depends on new code here.

- [ ] **Step 1: Deploy Tasks 1-5's files to production first**

Follow the deploy process documented in `Cozumel-Website/CLAUDE.md` "Production Deployment" — `scp` each of `inc/ical-sync.php`, `inc/cli-sync-calendars.php`, `inc/meta-fields.php`, `functions.php` to the VPS, then `php -l` each one. This task cannot proceed until the command exists on production, since cron runs against production, not local dev.

- [ ] **Step 2: Confirm the command runs on production**

```bash
ssh -i ~/.ssh/id_ed25519_cozumel_vps deploy@2.25.104.105 \
  "cd /var/www/cozumelhomes.net/htdocs && sudo -u www-data wp cozumel sync-calendars"
```
Expected: prints a success or warning summary (warnings are fine if `airbnb_ical_url` isn't populated for real properties yet — that's Task 9's job; "no airbnb_ical_url set, skipped" per property is the expected message right now).

- [ ] **Step 3: Add the cron entry**

```bash
ssh -i ~/.ssh/id_ed25519_cozumel_vps deploy@2.25.104.105 \
  "(sudo -u www-data crontab -l 2>/dev/null; echo '0 * * * * cd /var/www/cozumelhomes.net/htdocs && wp cozumel sync-calendars >> /var/log/cozumel-calendar-sync.log 2>&1') | sudo -u www-data crontab -"
```

This runs hourly, on the hour, as the `www-data` user (matching the file ownership used everywhere else on this site), logging output to `/var/log/cozumel-calendar-sync.log`.

- [ ] **Step 4: Confirm the log file is writable by www-data**

```bash
ssh -i ~/.ssh/id_ed25519_cozumel_vps deploy@2.25.104.105 \
  "sudo touch /var/log/cozumel-calendar-sync.log && sudo chown www-data:www-data /var/log/cozumel-calendar-sync.log"
```

- [ ] **Step 5: Verify the cron entry is installed**

```bash
ssh -i ~/.ssh/id_ed25519_cozumel_vps deploy@2.25.104.105 "sudo -u www-data crontab -l"
```
Expected: shows the line added in Step 3.

- [ ] **Step 6: Verify it actually fires on schedule (not just manually)**

This step requires waiting for the next hour boundary — not something to rush. After the top of the next hour passes:
```bash
ssh -i ~/.ssh/id_ed25519_cozumel_vps deploy@2.25.104.105 "sudo tail -20 /var/log/cozumel-calendar-sync.log"
```
Expected: a fresh log entry with a timestamp matching the hour boundary, containing the same success/warning summary seen in Step 2.

No commit for this task — it's server configuration, not versioned code.

---

### Task 7: Public Availability REST Endpoint

**Files:**
- Create: `theme/cozumel-homes/inc/rest-availability.php`
- Modify: `theme/cozumel-homes/functions.php`

**Interfaces:**
- Consumes: `cozumel_ical_apply_buffer()` from Task 2; `airbnb_blocked_dates`/`manual_blocked_dates` post meta from Task 4/5.
- Produces: `GET /wp-json/cozumel/v1/availability/<property_id>` → JSON array of `{"start":"Y-m-d","end":"Y-m-d"}` objects (buffered, already unavailable) for Task 8's JS to consume.

- [ ] **Step 1: Write the endpoint**

Create `theme/cozumel-homes/inc/rest-availability.php`:

```php
<?php
add_action('rest_api_init', function () {
    register_rest_route('cozumel/v1', '/availability/(?P<id>\d+)', [
        'methods'             => 'GET',
        'callback'            => 'cozumel_get_availability',
        'permission_callback' => '__return_true',
        'args'                => [
            'id' => ['validate_callback' => function ($param) {
                return is_numeric($param);
            }],
        ],
    ]);
});

function cozumel_get_availability(WP_REST_Request $request): WP_REST_Response {
    $property_id = (int) $request['id'];

    if (get_post_type($property_id) !== 'rental-property') {
        return new WP_REST_Response(['error' => 'not a rental property'], 404);
    }

    $airbnb_raw = get_post_meta($property_id, 'airbnb_blocked_dates', true);
    $airbnb_ranges = json_decode($airbnb_raw ?: '[]', true);
    if (!is_array($airbnb_ranges)) {
        $airbnb_ranges = [];
    }

    $manual_raw = get_post_meta($property_id, 'manual_blocked_dates', true);
    $manual_ranges = json_decode($manual_raw ?: '[]', true);
    if (!is_array($manual_ranges)) {
        $manual_ranges = [];
    }

    $combined = array_merge($airbnb_ranges, $manual_ranges);
    $buffered = cozumel_ical_apply_buffer($combined, 1);

    $response = new WP_REST_Response($buffered, 200);
    $response->header('Cache-Control', 'public, max-age=1800');
    return $response;
}
```

- [ ] **Step 2: Require the new file**

In `theme/cozumel-homes/functions.php`, add near the other requires:

```php
require_once get_stylesheet_directory() . '/inc/ical-sync.php';
require_once get_stylesheet_directory() . '/inc/rest-availability.php';
```

(`ical-sync.php` needs an explicit require here too — Task 5's `cli-sync-calendars.php` only loads it when `WP_CLI` is defined, but this REST endpoint needs `cozumel_ical_apply_buffer()` on every normal web request too.)

- [ ] **Step 3: Verify locally**

Start local dev, then:
```bash
curl -s "https://cozumel-homes.local/wp-json/cozumel/v1/availability/24" -k
```
Expected: `200` with a JSON array (empty `[]` is fine if no dates are blocked yet for that property).

- [ ] **Step 4: Verify the 404 path**

```bash
curl -s -o /dev/null -w "%{http_code}\n" "https://cozumel-homes.local/wp-json/cozumel/v1/availability/999999" -k
```
Expected: `404`.

- [ ] **Step 5: Commit**

```bash
git add theme/cozumel-homes/inc/rest-availability.php theme/cozumel-homes/functions.php
git commit -m "feat: add public availability REST endpoint"
```

---

### Task 8: Interactive Calendar Widget (JS + CSS + template wiring)

**Files:**
- Create: `theme/cozumel-homes/assets/js/availability-calendar.js`
- Modify: `theme/cozumel-homes/assets/css/theme.css`
- Modify: `theme/cozumel-homes/single-rental-property.php`
- Modify: `theme/cozumel-homes/functions.php`

**Interfaces:**
- Consumes: `GET /wp-json/cozumel/v1/availability/<id>` from Task 7; existing inquiry form fields `[name="checkin_date"]`/`[name="checkout_date"]` from `inc/inquiry-form.php` (unmodified — selected via attribute selector, no ID needed).
- Produces: nothing consumed by later tasks — this is the final user-facing piece.

- [ ] **Step 1: Write the calendar widget JS**

Create `theme/cozumel-homes/assets/js/availability-calendar.js`:

```javascript
(function () {
    'use strict';

    function pad(n) { return n < 10 ? '0' + n : '' + n; }
    function toISO(date) { return date.getFullYear() + '-' + pad(date.getMonth() + 1) + '-' + pad(date.getDate()); }

    function buildUnavailableSet(ranges) {
        var set = new Set();
        ranges.forEach(function (range) {
            var cur = new Date(range.start + 'T00:00:00');
            var end = new Date(range.end + 'T00:00:00');
            while (cur < end) {
                set.add(toISO(cur));
                cur.setDate(cur.getDate() + 1);
            }
        });
        return set;
    }

    function renderMonth(container, year, month, unavailableSet, selection, onPick) {
        var monthNames = ['January','February','March','April','May','June','July','August','September','October','November','December'];
        var first = new Date(year, month, 1);
        var daysInMonth = new Date(year, month + 1, 0).getDate();
        var startWeekday = first.getDay();

        var html = '<div class="availability-calendar__month">';
        html += '<h4>' + monthNames[month] + ' ' + year + '</h4>';
        html += '<div class="availability-calendar__grid">';
        for (var i = 0; i < startWeekday; i++) {
            html += '<span class="availability-calendar__day availability-calendar__day--empty"></span>';
        }
        var today = new Date();
        today.setHours(0, 0, 0, 0);
        for (var d = 1; d <= daysInMonth; d++) {
            var date = new Date(year, month, d);
            var iso = toISO(date);
            var isPast = date < today;
            var isUnavailable = unavailableSet.has(iso);
            var classes = ['availability-calendar__day'];
            if (isPast || isUnavailable) classes.push('availability-calendar__day--unavailable');
            else classes.push('availability-calendar__day--available');
            if (selection.start === iso || selection.end === iso) classes.push('availability-calendar__day--selected');
            html += '<button type="button" class="' + classes.join(' ') + '" data-date="' + iso + '"' + (isPast || isUnavailable ? ' disabled' : '') + '>' + d + '</button>';
        }
        html += '</div></div>';
        container.innerHTML += html;
    }

    function init(root) {
        var propertyId = root.getAttribute('data-property-id');
        var apiUrl = root.getAttribute('data-api-url');
        var checkinInput = document.querySelector('[name="checkin_date"]');
        var checkoutInput = document.querySelector('[name="checkout_date"]');
        var selection = { start: null, end: null };

        fetch(apiUrl)
            .then(function (res) { return res.json(); })
            .then(function (ranges) {
                var unavailableSet = buildUnavailableSet(ranges);
                var now = new Date();
                var grid = document.createElement('div');
                grid.className = 'availability-calendar';
                root.appendChild(grid);

                function redraw() {
                    grid.innerHTML = '';
                    renderMonth(grid, now.getFullYear(), now.getMonth(), unavailableSet, selection, handlePick);
                    var next = new Date(now.getFullYear(), now.getMonth() + 1, 1);
                    renderMonth(grid, next.getFullYear(), next.getMonth(), unavailableSet, selection, handlePick);
                }

                function handlePick(iso) {
                    if (!selection.start || (selection.start && selection.end)) {
                        selection = { start: iso, end: null };
                    } else if (iso > selection.start) {
                        selection.end = iso;
                    } else {
                        selection = { start: iso, end: null };
                    }
                    if (checkinInput) checkinInput.value = selection.start || '';
                    if (checkoutInput) checkoutInput.value = selection.end || '';
                    redraw();
                }

                grid.addEventListener('click', function (e) {
                    var btn = e.target.closest('.availability-calendar__day--available, .availability-calendar__day--selected');
                    if (btn) handlePick(btn.getAttribute('data-date'));
                });

                redraw();
            });
    }

    document.addEventListener('DOMContentLoaded', function () {
        var roots = document.querySelectorAll('[data-cozumel-availability-calendar]');
        roots.forEach(init);
    });
})();
```

- [ ] **Step 2: Add calendar styles**

In `theme/cozumel-homes/assets/css/theme.css`, add after the existing `.property-single__booking` rule:

```css
.availability-calendar { display: flex; gap: 24px; flex-wrap: wrap; margin: 16px 0 24px; }
.availability-calendar__month h4 { margin: 0 0 8px; font-size: 1rem; }
.availability-calendar__grid { display: grid; grid-template-columns: repeat(7, 32px); gap: 4px; }
.availability-calendar__day { width: 32px; height: 32px; border: none; border-radius: 4px; font-size: 0.85rem; cursor: pointer; }
.availability-calendar__day--empty { background: transparent; cursor: default; }
.availability-calendar__day--available { background: #e8f5f2; color: var(--color-navy); }
.availability-calendar__day--available:hover { background: #cdeae4; }
.availability-calendar__day--unavailable { background: #f2f2f2; color: #bbb; cursor: not-allowed; }
.availability-calendar__day--selected { background: var(--color-turquoise, #2eb3c4); color: #fff; }
```

If `--color-navy`/`--color-turquoise` aren't the exact custom property names already defined elsewhere in `theme.css`, check the file's `:root` block first and match the existing token names rather than introducing new ones.

- [ ] **Step 3: Wire the widget into the property page**

In `theme/cozumel-homes/single-rental-property.php`, replace the placeholder comment block (around line 41-46):

```php
            <div class="property-single__booking">
                <div data-cozumel-availability-calendar
                     data-property-id="<?php echo esc_attr(get_the_ID()); ?>"
                     data-api-url="<?php echo esc_url(rest_url('cozumel/v1/availability/' . get_the_ID())); ?>">
                </div>
                <?php if ($airbnb_url): ?>
                    <a href="<?php echo esc_url($airbnb_url); ?>" class="btn btn--airbnb" target="_blank" rel="noopener noreferrer">Book on Airbnb</a>
                <?php endif; ?>
            </div>
```

- [ ] **Step 4: Enqueue the script on rental property pages only**

In `theme/cozumel-homes/functions.php`, inside `cozumel_enqueue_styles()`, extend the existing `is_singular([...])` block that currently enqueues `cozumel-carousel`:

```php
    if (is_singular(['rental-property', 'forsale-property'])) {
        wp_enqueue_script(
            'cozumel-carousel',
            get_stylesheet_directory_uri() . '/assets/js/carousel.js',
            [],
            '1.0.0',
            true
        );
    }

    if (is_singular('rental-property')) {
        wp_enqueue_script(
            'cozumel-availability-calendar',
            get_stylesheet_directory_uri() . '/assets/js/availability-calendar.js',
            [],
            '1.0.0',
            true
        );
    }
```

- [ ] **Step 5: Manually verify in a browser (local dev)**

Open a rental property page in local dev (e.g. Cool Caribbean Views). Confirm: two month grids render side-by-side above the "Book on Airbnb" button; clicking an available day highlights it; clicking a second later day sets both `checkin_date` and `checkout_date` on the inquiry form below (open browser devtools, confirm those input values updated); days already blocked (test by adding a `manual_blocked_dates` entry via Task 4's admin field first) render greyed-out and unclickable.

- [ ] **Step 6: Commit**

```bash
git add theme/cozumel-homes/assets/js/availability-calendar.js theme/cozumel-homes/assets/css/theme.css theme/cozumel-homes/single-rental-property.php theme/cozumel-homes/functions.php
git commit -m "feat: add interactive availability calendar to rental property pages"
```

---

### Task 9: Production Deploy + Airbnb Setup + End-to-End Verification

**Files:** none (deployment + external configuration)

**Interfaces:** none — final integration task, verifies everything from Tasks 1-8 together in production.

- [ ] **Step 1: Push all commits**

```bash
git push origin master
```

- [ ] **Step 2: Deploy every changed/new file to production**

Following `Cozumel-Website/CLAUDE.md`'s deploy process, `scp` + `ssh`-copy each of:
`inc/ical-sync.php`, `inc/cli-sync-calendars.php`, `inc/rest-availability.php`, `inc/meta-fields.php`, `functions.php`, `single-rental-property.php`, `assets/js/availability-calendar.js`, `assets/css/theme.css`.
Run `php -l` on each PHP file after copying, per the established pattern.

- [ ] **Step 3: Confirm the REST endpoint and calendar render on production**

```bash
curl -s "https://cozumelhomes.net/wp-json/cozumel/v1/availability/24"
curl -s "https://cozumelhomes.net/rentals/cozumels-cool-caribbean-views/" | grep "data-cozumel-availability-calendar"
```
Expected: REST call returns `[]` or real data; the property page HTML contains the calendar container div.

- [ ] **Step 4: This step requires Fernando — get the 3 real Airbnb export URLs**

For each of the 3 rental properties (Nah Ha 101, Cool Caribbean Views, Casa Bohemia), in Kelley's Airbnb account: Listings → select listing → Availability → Calendar → Calendar sync → Export calendar → copy the iCal URL. Paste each into that property's `airbnb_ical_url` field in wp-admin (Task 4's existing field), Update.

- [ ] **Step 5: Run the sync manually and verify real data**

```bash
ssh -i ~/.ssh/id_ed25519_cozumel_vps deploy@2.25.104.105 \
  "cd /var/www/cozumelhomes.net/htdocs && sudo -u www-data wp cozumel sync-calendars"
```
Expected: success message, no failures. Then:
```bash
ssh -i ~/.ssh/id_ed25519_cozumel_vps deploy@2.25.104.105 \
  "cd /var/www/cozumelhomes.net/htdocs && for id in 24 25 26; do sudo -u www-data wp post meta get \$id airbnb_blocked_dates; done"
```
Cross-check the printed dates against what Kelley's actual Airbnb host calendar shows for each listing.

- [ ] **Step 6: This step requires Fernando — paste the outbound .ics URLs into Airbnb**

For each property, the outbound file is at `https://cozumelhomes.net/wp-content/uploads/calendars/<slug>.ics` (slugs: `cozumels-nah-ha-condominium-101`, `cozumels-cool-caribbean-views`, `cozumels-casa-bohemia` — confirm exact slugs via `wp post list --post_type=rental-property --field=post_name`). In Airbnb, same Calendar sync section, paste each URL into "Import calendar." Airbnb refreshes imports on its own 2-4hr cycle, so the next check (Step 7) should happen after that window, not immediately.

- [ ] **Step 7: Final end-to-end check (after Airbnb's import refresh window)**

In wp-admin, set a `manual_blocked_dates` test entry on one property a few days out (e.g. `[{"start":"2026-09-01","end":"2026-09-03"}]`), run the sync command again, then check Airbnb's own calendar UI for that listing shows those dates (plus the 1-day buffer) blocked. Remove the test entry afterward and re-run the sync to clear it.

- [ ] **Step 8: Update memory**

This is a documentation step for whoever executes this plan (human or agent) — not a code change. Note in the `[[ical_three_way_sync]]` memory (or a new memory if that one's since been superseded) that this shipped, targeting Airbnb directly rather than the originally-planned three-way Lodgify sync, and that it unblocks the booking-request-workflow project's "calendar/availability tie-in" open item.

No git commit for this task beyond what Step 1 already pushed.
