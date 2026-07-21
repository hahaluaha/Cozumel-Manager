# Rental Property Photo Carousel — Design Spec
Date: 2026-07-21

## Overview
Add a photo carousel to each rental property's single page on the companion WordPress site (`cozumel-homes.local`, theme `wp-content/themes/cozumel-homes`). Today each of the 3 rentals (Cool Caribbean Views, Casa Bohemia, Nah Ha 101) has exactly one photo live — the WP featured image, rendered as a static hero on `single-rental-property.php`. This spec adds a real multi-photo carousel to that same hero position, plus the admin tooling to manage which photos appear and in what order.

Scoped to **rental properties only**. The for-sale listing (`forsale-property`) has no gallery photos yet either and is a natural fast-follow, not part of this spec.

## Data Model
New post meta `gallery_ids` on `rental-property`, registered in `inc/meta-fields.php` alongside the existing custom fields (`mac_id`, `neighborhood`, `latitude`, etc.):

```php
register_post_meta('rental-property', 'gallery_ids', [
    'single'       => true,
    'type'         => 'array',
    'default'      => [],
    'show_in_rest' => [
        'schema' => ['type' => 'array', 'items' => ['type' => 'integer']],
    ],
]);
```

- An ordered array of WP attachment IDs — the display order of the carousel.
- IDs are **media-type agnostic**: an ID may point to an image or a video attachment. The frontend render loop branches on `wp_attachment_is('video', $id)`. This means a video slide can be dropped into the array later (once a Mac-app → WP video sync path exists, following PR #2) without any data-model change. Building that video upload/sync path itself is explicitly **out of scope** here.
- The existing featured image (`_thumbnail_id`) is unchanged and still drives archive/listing cards (`property-card.php`) — `gallery_ids` only affects the single-property carousel and may freely include the same photo as the featured image.

## Admin UI
A new "Gallery Photos" meta box on the `rental-property` edit screen (`inc/meta-fields.php`, next to the existing "Property Details" box), using WordPress core's own media tooling — no third-party plugin:

- `wp_enqueue_media()` (core) + `wp.media({ multiple: true })` JS call opens WordPress's native media library modal — pick existing library attachments or upload new ones on the spot.
- Current gallery shown as a row of thumbnails, each with a small "×" remove control.
- Thumbnails are drag-to-reorder via jQuery UI Sortable (`jquery-ui-sortable`, bundled with WP core).
- A hidden input holds the ordered, comma-separated attachment ID list; on save, `cozumel_save_meta()` (existing save handler in `inc/meta-fields.php`) is extended to also sanitize and persist `gallery_ids` as an array of ints, gated by the same nonce/capability check already used for the other fields.

## Frontend Carousel
Replaces the current static hero block in `single-rental-property.php`:

- Each slide is full-width, matching the existing hero's `max-height:500px; object-fit:cover` sizing.
- **Image slides:** rendered with `<picture>` — an AVIF `<source>` plus a JPG `<img>` fallback — since not all browsers support AVIF. (Both formats already exist per-photo from the Mac app's photo-resize step.)
- **Video slides** (when a `gallery_ids` entry is a video attachment): rendered as an inline HTML5 `<video controls>` in place of the `<img>`/`<picture>`. Never autoplay — the user must click play.
- Controls: prev/next arrow buttons + dot indicators (manual navigation only, no autoplay — matches the "no distracting motion on a listing page" decision). Left/right keyboard arrow keys also navigate when the carousel has focus. Touch swipe supported on mobile via CSS `scroll-snap-type` (no JS swipe library needed).
- Implementation stays dependency-free, consistent with the theme's current all-vanilla state: plain CSS (`scroll-snap`) for the sliding strip, one new small vanilla-JS file (~50 lines, no jQuery) for arrow/dot/keyboard interaction, enqueued only on `single-rental-property.php`.
- If `gallery_ids` has exactly one entry, render that single image/video with no arrows or dots — there's nothing to navigate.
- If `gallery_ids` is empty (not yet migrated for a given property), fall back to today's behavior: the featured image, or the existing gray "Photo coming soon" placeholder if there's no featured image either.

## Bulk Photo Migration (existing photos → WP gallery)
One-time data migration, not a recurring sync (the Mac-app → WP sync daemon from Plan B still doesn't exist):

For each of the 3 rentals, upload every photo currently sitting in the Mac app's sandboxed container at `~/Library/Containers/Team-Paraiso.CozumelManager/Data/Library/Application Support/CozumelManager/Photos/<prop-id>/` to WordPress via the same `wp/v2/media` REST POST already used for the featured images. Prefer the pre-resized `.avif` versions over the original `.jpg`s to keep upload size down. After upload, PATCH the corresponding `rental-property` post's `gallery_ids` with the resulting ordered attachment ID list.

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
- Test left/right keyboard arrow navigation.
- Resize to mobile width and confirm touch-swipe scroll-snap behavior.
- Confirm AVIF sources fall back to JPG in a browser/devtools context without AVIF support.
- In wp-admin, confirm the Gallery Photos meta box: add via the media modal, remove via "×", drag-reorder, save, and reload to confirm the order persisted.

## Out of Scope
- For-sale property (`forsale-property`) gallery/carousel — no gallery photos exist for it yet; a separate future pass.
- Video upload / Mac-app-to-WP video sync path — `gallery_ids` is designed to accept a video attachment ID later, but building that upload/sync mechanism is not part of this spec (follows from PR #2).
- Recurring/automatic photo sync from the Mac app (Plan B sync daemon) — this spec's migration step is a one-time manual script.
- Lightbox/full-screen photo viewer — carousel only shows the inline hero-sized slides.
- Autoplay — explicitly excluded per the interaction-model decision above.
