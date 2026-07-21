# Property Photo Carousel — Design Spec
Date: 2026-07-21

## Overview
Add a photo carousel to each property's single page on the companion WordPress site (`cozumel-homes.local`, theme `wp-content/themes/cozumel-homes`) — both the 3 rentals (Cool Caribbean Views, Casa Bohemia, Nah Ha 101) and the for-sale listing (Cozumel House for Sale). Today each rental has exactly one photo live (the WP featured image, rendered as a static hero on `single-rental-property.php`); the for-sale listing has none. This spec adds a real multi-photo carousel to that same hero position on both post types, plus the admin tooling to manage which photos appear and in what order.

The carousel mechanism (data model, admin UI, frontend rendering) is built generically for both `rental-property` and `forsale-property` now, since there's no reason to build it twice. **Only the data migration differs**: the 3 rentals have existing photos to bulk-upload today; the for-sale listing has no photos anywhere yet (checked: no featured image, no photo folder in the Mac app's container), so its migration step is deferred until photos actually exist for it — see Out of Scope.

## Data Model
New post meta `gallery_ids`, registered on **both** `rental-property` and `forsale-property` in `inc/meta-fields.php` alongside each post type's existing custom fields (`mac_id`, `neighborhood`/`asking_price`, `latitude`, etc.) — same shape for both, via a small shared helper so it's not duplicated per post type:

```php
function cozumel_register_gallery_meta($post_type) {
    register_post_meta($post_type, 'gallery_ids', [
        'single'       => true,
        'type'         => 'array',
        'default'      => [],
        'show_in_rest' => [
            'schema' => ['type' => 'array', 'items' => ['type' => 'integer']],
        ],
    ]);
}
add_action('init', function () {
    cozumel_register_gallery_meta('rental-property');
    cozumel_register_gallery_meta('forsale-property');
});
```

- An ordered array of WP attachment IDs — the display order of the carousel.
- IDs are **media-type agnostic**: an ID may point to an image or a video attachment. The frontend render loop branches on `wp_attachment_is('video', $id)`. This means a video slide can be dropped into the array later (once a Mac-app → WP video sync path exists, following PR #2) without any data-model change. Building that video upload/sync path itself is explicitly **out of scope** here.
- The existing featured image (`_thumbnail_id`) is unchanged and still drives archive/listing cards (`property-card.php` / `forsale-card.php`) — `gallery_ids` only affects the single-property carousel and may freely include the same photo as the featured image.

## Admin UI
A new "Gallery Photos" meta box registered on **both** the `rental-property` and `forsale-property` edit screens (`inc/meta-fields.php`, next to each post type's existing "Property Details" box), using WordPress core's own media tooling — no third-party plugin. One shared render/save implementation, added to both post types' meta box registration:

- `wp_enqueue_media()` (core) + `wp.media({ multiple: true })` JS call opens WordPress's native media library modal — pick existing library attachments or upload new ones on the spot.
- Current gallery shown as a row of thumbnails, each with a small "×" remove control.
- Thumbnails are drag-to-reorder via jQuery UI Sortable (`jquery-ui-sortable`, bundled with WP core).
- A hidden input holds the ordered, comma-separated attachment ID list; on save, `cozumel_save_meta()` (existing save handler in `inc/meta-fields.php`, already shared across both post types) is extended to also sanitize and persist `gallery_ids` as an array of ints, gated by the same nonce/capability check already used for the other fields.

## Frontend Carousel
A shared template part (`template-parts/carousel.php`) replaces the current static hero block in both `single-rental-property.php` and `single-forsale-property.php`:

- Each slide is full-width, matching the existing hero's `max-height:500px; object-fit:cover` sizing.
- **Image slides:** rendered with `<picture>` — an AVIF `<source>` plus a JPG `<img>` fallback — since not all browsers support AVIF. (Both formats already exist per-photo from the Mac app's photo-resize step.)
- **Video slides** (when a `gallery_ids` entry is a video attachment): rendered as an inline HTML5 `<video controls>` in place of the `<img>`/`<picture>`. Never autoplay — the user must click play.
- Controls: prev/next arrow buttons + dot indicators (manual navigation only, no autoplay — matches the "no distracting motion on a listing page" decision). Left/right keyboard arrow keys also navigate when the carousel has focus. Touch swipe supported on mobile via CSS `scroll-snap-type` (no JS swipe library needed).
- Implementation stays dependency-free, consistent with the theme's current all-vanilla state: plain CSS (`scroll-snap`) for the sliding strip, one new small vanilla-JS file (~50 lines, no jQuery) for arrow/dot/keyboard interaction, enqueued only on the two single-property templates (via `is_singular(['rental-property', 'forsale-property'])`).
- If `gallery_ids` has exactly one entry, render that single image/video with no arrows or dots — there's nothing to navigate.
- If `gallery_ids` is empty (not yet migrated for a given property), fall back to today's behavior: the featured image, or the existing gray "Photo coming soon" placeholder if there's no featured image either.

## Bulk Photo Migration (existing photos → WP gallery)
One-time data migration, not a recurring sync (the Mac-app → WP sync daemon from Plan B still doesn't exist), and **rentals only** — the for-sale listing has no photos to migrate yet (see Out of Scope):

For each of the 3 rentals, upload every photo currently sitting in the Mac app's sandboxed container at `~/Library/Containers/Team-Paraiso.CozumelManager/Data/Library/Application Support/CozumelManager/Photos/<prop-id>/` to WordPress via the same `wp/v2/media` REST POST already used for the featured images. Prefer the pre-resized `.avif` versions over the original `.jpg`s to keep upload size down. After upload, PATCH the corresponding `rental-property` post's `gallery_ids` with the resulting ordered attachment ID list.

The for-sale listing gets the exact same admin UI and frontend carousel code (nothing extra to build), just no photos loaded into `gallery_ids` yet — Fernando or Kelley can add them anytime later through the wp-admin picker built here, with no further code changes needed.

## Cool Caribbean Views AVIF/JPG Format Test (adjacent, not carousel-dependent)
Separate from the carousel: Fernando is testing whether switching Cool Caribbean Views' *featured image* from the current `Cool Caribbean view.jpg` (media #29) to an AVIF version renders better quality and performs better for SEO. This is just a featured-image swap (upload the AVIF file, PATCH `featured_media` to the new attachment ID) — independent of the gallery/carousel work above and can happen before, during, or after it.

## Error Handling / Edge Cases
- Missing `gallery_ids` → fall back to featured image / placeholder (see above).
- A `gallery_ids` entry pointing at a deleted attachment → skipped silently in the render loop; arrow/dot count reflects only the slides actually rendered.
- Exactly one valid entry → no carousel controls rendered.
- Video slides never autoplay.

## Verification
No automated test suite exists in this theme (pure PHP/CSS/vanilla-JS, no build tooling) — verification is manual:
- Load each rental's single page; click through arrows and dots; confirm correct slide order.
- Load the for-sale listing's single page; confirm it falls back cleanly to the placeholder/featured-image behavior (no `gallery_ids` yet) without errors.
- Test left/right keyboard arrow navigation.
- Resize to mobile width and confirm touch-swipe scroll-snap behavior.
- Confirm AVIF sources fall back to JPG in a browser/devtools context without AVIF support.
- In wp-admin, confirm the Gallery Photos meta box on both a rental and the for-sale listing: add via the media modal, remove via "×", drag-reorder, save, and reload to confirm the order persisted.

## Out of Scope
- Actually loading photos into the for-sale listing's `gallery_ids` — the admin UI and carousel are built for it, but no photos exist for it yet, so its migration is deferred until Kelley/Fernando source some.
- Video upload / Mac-app-to-WP video sync path — `gallery_ids` is designed to accept a video attachment ID later, but building that upload/sync mechanism is not part of this spec (follows from PR #2).
- Recurring/automatic photo sync from the Mac app (Plan B sync daemon) — this spec's migration step is a one-time manual script.
- Lightbox/full-screen photo viewer — carousel only shows the inline hero-sized slides.
- Autoplay — explicitly excluded per the interaction-model decision above.
