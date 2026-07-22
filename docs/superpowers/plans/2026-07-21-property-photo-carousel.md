# Property Photo Carousel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single static hero image on rental and for-sale property pages with a real multi-photo (and future-video) carousel, plus a wp-admin picker to manage each property's gallery, and migrate the 3 rentals' existing photos into it.

**Architecture:** A new `gallery_ids` post meta (ordered array of attachment IDs, media-type agnostic) drives a shared `template-parts/carousel.php` rendered on both `single-rental-property.php` and `single-forsale-property.php`. A wp-admin meta box on both post types uses WordPress core's own `wp.media()` picker plus jQuery UI Sortable (both bundled with WP core — no third-party plugin) to manage the list. A one-time REST migration script uploads the 3 rentals' existing resized photos and populates `gallery_ids`.

**Tech Stack:** WordPress (PHP 8+), theme `cozumel-homes` (child of GeneratePress) in the `Cozumel-Website` repo, no build tooling — plain PHP/CSS/vanilla JS + WP-core-bundled jQuery/jQuery UI for the admin picker only.

## Global Constraints

- **Repo:** All theme file changes happen in `~/Projects/Cozumel-Website` (git repo `Cozumel-Website`), symlinked into `~/Local Sites/cozumel-homes/app/public/wp-content/themes/cozumel-homes`. This plan file lives in `Cozumel_App_Final` as documentation only — commit theme changes in the `Cozumel-Website` repo, not this one.
- No third-party WordPress plugins — everything here uses WP core (`wp.media()`, `jquery-ui-sortable`) or hand-written PHP/CSS/JS, per standing project preference.
- Post types affected: `rental-property` and `forsale-property` (both already registered in `inc/post-types.php`). The carousel mechanism is built for both; only the bulk photo migration (Task 4) is rentals-only, since the for-sale listing has no photos to migrate yet.
- **Documented deviation from the design spec's `<picture>`+AVIF/JPG-fallback wording:** the Mac app's existing photo files don't have matching filenames between the original `.jpg` and resized `.avif` versions (e.g. `Cool Caribbean view.jpg` vs. `resized-Cool-Caribbean-view.avif`), so there's no reliable way to pair them into a `<picture>` fallback without fragile per-file heuristics. Carousel slides instead render a single `<img>` using whichever one file was actually uploaded to WordPress (matches current site behavior — the live Nah Ha 101 hero is already a bare `.avif` with no JPG fallback today, so this isn't a regression). Revisit true dual-format serving once Fernando's ongoing AVIF-vs-JPG quality/SEO test picks a winner — at that point the site would standardize on one format anyway, making the fallback question moot.
- REST API writes require a valid WordPress Application Password for user `akrati32` on `cozumel-homes.local` — the one used during design/spec verification was revoked afterward. Generate a fresh one (wp-admin → Users → Profile → Application Passwords) before Task 4.
- No autoplay, ever (carousel is manual-navigation only per approved spec).

---

### Task 1: `gallery_ids` post meta on both post types

**Files:**
- Modify: `theme/cozumel-homes/inc/meta-fields.php`

**Interfaces:**
- Produces: `gallery_ids` post meta (array of ints, default `[]`) on `rental-property` and `forsale-property`, REST-readable/writable at `meta.gallery_ids` — consumed by Task 2 (admin save) and Task 3 (frontend read).

---

- [ ] **Step 1: Add the meta registration**

  In `theme/cozumel-homes/inc/meta-fields.php`, add after the closing brace of `cozumel_register_meta_fields()` (currently ending at line 29, right before the `// ── Admin meta boxes` comment):

  ```php
  // ── Gallery photos meta (shared by rentals and for-sale) ───────────────────
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

- [ ] **Step 2: Verify the meta is registered and defaults to an empty array**

  Run:
  ```bash
  curl -s "http://cozumel-homes.local/wp-json/wp/v2/rental-property/24?_fields=id,meta" | python3 -m json.tool
  ```
  Expected: the JSON now includes `"gallery_ids": []` inside `meta`, alongside the existing fields (`mac_id`, `neighborhood`, etc.).

  Also check the for-sale listing:
  ```bash
  curl -s "http://cozumel-homes.local/wp-json/wp/v2/forsale-property/27?_fields=id,meta" | python3 -m json.tool
  ```
  Expected: same — `"gallery_ids": []` present.

- [ ] **Step 3: Commit**

  ```bash
  cd ~/Projects/Cozumel-Website
  git add theme/cozumel-homes/inc/meta-fields.php
  git commit -m "feat: register gallery_ids post meta on rental and for-sale properties"
  ```

---

### Task 2: Admin "Gallery Photos" picker (meta box + media picker JS)

**Files:**
- Modify: `theme/cozumel-homes/inc/meta-fields.php`
- Create: `theme/cozumel-homes/assets/js/gallery-picker.js`

**Interfaces:**
- Consumes: `gallery_ids` meta (Task 1).
- Produces: working wp-admin UI that writes an ordered `gallery_ids` array back via the existing `cozumel_save_meta()` save handler — consumed by Task 3's frontend render and Task 4's migration (which writes the same field via REST instead of this UI).

---

- [ ] **Step 1: Add the meta box render callback**

  In `theme/cozumel-homes/inc/meta-fields.php`, add after `cozumel_forsale_meta_box_html()` (currently ending at line 78, right before the `// ── Save meta on post save` comment):

  ```php
  function cozumel_gallery_meta_box_html($post) {
      wp_nonce_field('cozumel_save_meta', 'cozumel_meta_nonce');
      $ids = get_post_meta($post->ID, 'gallery_ids', true);
      if (!is_array($ids)) { $ids = []; }
      ?>
      <div id="cozumel-gallery-picker">
          <ul id="cozumel-gallery-list" style="display:flex;flex-wrap:wrap;gap:8px;list-style:none;margin:0 0 12px;padding:0">
              <?php foreach ($ids as $id):
                  $thumb = wp_get_attachment_image_src($id, 'thumbnail');
                  if (!$thumb) continue;
              ?>
                  <li class="cozumel-gallery-item" data-id="<?php echo esc_attr($id); ?>" style="position:relative;cursor:move">
                      <img src="<?php echo esc_url($thumb[0]); ?>" style="width:80px;height:80px;object-fit:cover;border-radius:4px;display:block">
                      <button type="button" class="cozumel-gallery-remove" style="position:absolute;top:-6px;right:-6px;background:#c00;color:#fff;border:none;border-radius:50%;width:20px;height:20px;line-height:1;cursor:pointer">×</button>
                  </li>
              <?php endforeach; ?>
          </ul>
          <input type="hidden" name="gallery_ids" id="cozumel-gallery-ids-input" value="<?php echo esc_attr(implode(',', $ids)); ?>">
          <button type="button" class="button" id="cozumel-gallery-add">Add Photos</button>
      </div>
      <?php
  }
  ```

- [ ] **Step 2: Register the meta box on both post types**

  In `theme/cozumel-homes/inc/meta-fields.php`, modify `cozumel_add_meta_boxes()` (lines 32-42) to add the new box:

  ```php
  function cozumel_add_meta_boxes() {
      add_meta_box(
          'rental_details', 'Property Details',
          'cozumel_rental_meta_box_html', 'rental-property', 'normal', 'high'
      );
      add_meta_box(
          'forsale_details', 'Property Details',
          'cozumel_forsale_meta_box_html', 'forsale-property', 'normal', 'high'
      );
      add_meta_box(
          'gallery_photos', 'Gallery Photos',
          'cozumel_gallery_meta_box_html', ['rental-property', 'forsale-property'], 'normal', 'high'
      );
  }
  add_action('add_meta_boxes', 'cozumel_add_meta_boxes');
  ```

- [ ] **Step 3: Extend the save handler for `gallery_ids`**

  In `theme/cozumel-homes/inc/meta-fields.php`, modify `cozumel_save_meta()` (lines 81-104) to add the array-field handling after the existing `foreach` loop, still inside the function and before its closing brace:

  ```php
  function cozumel_save_meta($post_id) {
      if (defined('DOING_AUTOSAVE') && DOING_AUTOSAVE) return;
      if (!isset($_POST['cozumel_meta_nonce']) ||
          !wp_verify_nonce($_POST['cozumel_meta_nonce'], 'cozumel_save_meta')) {
          return;
      }
      if (!current_user_can('edit_post', $post_id)) return;

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

      if (isset($_POST['gallery_ids'])) {
          $ids = array_filter(array_map('absint', explode(',', $_POST['gallery_ids'])));
          update_post_meta($post_id, 'gallery_ids', array_values($ids));
      }
  }
  add_action('save_post', 'cozumel_save_meta');
  ```

- [ ] **Step 4: Enqueue the media picker + Sortable only on these post types' edit screens**

  In `theme/cozumel-homes/functions.php`, add after the `require_once` lines (after line 16):

  ```php
  function cozumel_enqueue_gallery_admin_assets($hook) {
      if ($hook !== 'post.php' && $hook !== 'post-new.php') return;
      $screen = get_current_screen();
      if (!$screen || !in_array($screen->post_type, ['rental-property', 'forsale-property'], true)) return;

      wp_enqueue_media();
      wp_enqueue_script('jquery-ui-sortable');
      wp_enqueue_script(
          'cozumel-gallery-picker',
          get_stylesheet_directory_uri() . '/assets/js/gallery-picker.js',
          ['jquery', 'jquery-ui-sortable'],
          '1.0.0',
          true
      );
  }
  add_action('admin_enqueue_scripts', 'cozumel_enqueue_gallery_admin_assets');
  ```

- [ ] **Step 5: Write the admin picker JS**

  Create `theme/cozumel-homes/assets/js/gallery-picker.js`:

  ```js
  jQuery(function ($) {
      var $list = $('#cozumel-gallery-list');
      if (!$list.length) return;

      var $input = $('#cozumel-gallery-ids-input');

      function syncInput() {
          var ids = $list.find('.cozumel-gallery-item').map(function () {
              return $(this).data('id');
          }).get();
          $input.val(ids.join(','));
      }

      $list.sortable({ update: syncInput });

      $('#cozumel-gallery-add').on('click', function (e) {
          e.preventDefault();
          var frame = wp.media({
              title: 'Select Gallery Photos',
              multiple: true,
              library: { type: ['image', 'video'] }
          });
          frame.on('select', function () {
              var selection = frame.state().get('selection');
              selection.each(function (attachment) {
                  var data = attachment.toJSON();
                  var thumbUrl = (data.sizes && data.sizes.thumbnail) ? data.sizes.thumbnail.url : data.url;
                  var $item = $('<li class="cozumel-gallery-item" style="position:relative;cursor:move">')
                      .attr('data-id', data.id)
                      .append($('<img>').attr('src', thumbUrl).css({
                          width: 80, height: 80, objectFit: 'cover', borderRadius: 4, display: 'block'
                      }))
                      .append($('<button type="button" class="cozumel-gallery-remove">×</button>').css({
                          position: 'absolute', top: -6, right: -6, background: '#c00', color: '#fff',
                          border: 'none', borderRadius: '50%', width: 20, height: 20, lineHeight: 1, cursor: 'pointer'
                      }));
                  $list.append($item);
              });
              syncInput();
          });
          frame.open();
      });

      $list.on('click', '.cozumel-gallery-remove', function () {
          $(this).closest('.cozumel-gallery-item').remove();
          syncInput();
      });
  });
  ```

- [ ] **Step 6: Verify in wp-admin**

  Open `http://cozumel-homes.local/wp-admin`, edit the Cool Caribbean Views rental post. Confirm:
  - A "Gallery Photos" box appears below "Property Details".
  - Clicking "Add Photos" opens WordPress's native media library modal; selecting 2-3 images adds them as thumbnails with remove ("×") buttons.
  - Dragging a thumbnail to a new position reorders it.
  - Clicking "×" removes that thumbnail.
  - Clicking "Update" (publish/save) persists the change — reload the edit screen and confirm the same photos, in the same order, are still shown.

  Then confirm via REST:
  ```bash
  curl -s "http://cozumel-homes.local/wp-json/wp/v2/rental-property/24?_fields=id,meta" | python3 -c "import sys,json; print(json.load(sys.stdin)['meta']['gallery_ids'])"
  ```
  Expected: a non-empty list of integer attachment IDs, in the order set in wp-admin.

  Repeat the same check on the for-sale listing's edit screen to confirm the meta box also renders and saves there (it will start empty — that's expected, no photos loaded until Task 4's counterpart for for-sale, which is out of scope for now).

- [ ] **Step 7: Commit**

  ```bash
  cd ~/Projects/Cozumel-Website
  git add theme/cozumel-homes/inc/meta-fields.php theme/cozumel-homes/functions.php theme/cozumel-homes/assets/js/gallery-picker.js
  git commit -m "feat: add wp-admin gallery photo picker for rental and for-sale properties"
  ```

---

### Task 3: Frontend carousel (template part + CSS + JS), wired into both single templates

**Files:**
- Create: `theme/cozumel-homes/template-parts/carousel.php`
- Modify: `theme/cozumel-homes/assets/css/theme.css`
- Create: `theme/cozumel-homes/assets/js/carousel.js`
- Modify: `theme/cozumel-homes/functions.php`
- Modify: `theme/cozumel-homes/single-rental-property.php`
- Modify: `theme/cozumel-homes/single-forsale-property.php`

**Interfaces:**
- Consumes: `gallery_ids` meta (Task 1), populated either via Task 2's admin UI or Task 4's migration.
- Produces: `template-parts/carousel.php`, invoked via `get_template_part('template-parts/carousel')` — no other task depends on this beyond the two single-property templates modified here.

---

- [ ] **Step 1: Write the carousel template part**

  Create `theme/cozumel-homes/template-parts/carousel.php`:

  ```php
  <?php
  // Renders the property photo/video carousel for the current post in the loop.
  // Falls back to the featured image (or nothing) if gallery_ids is empty.
  $gallery_ids = get_post_meta(get_the_ID(), 'gallery_ids', true);
  if (!is_array($gallery_ids)) { $gallery_ids = []; }

  // Drop any IDs pointing at attachments that no longer exist.
  $gallery_ids = array_values(array_filter($gallery_ids, function ($id) {
      return get_post_status($id) !== false;
  }));

  if (empty($gallery_ids)) {
      if (has_post_thumbnail()) {
          echo '<div class="property-single__hero">';
          the_post_thumbnail('full', ['style' => 'width:100%;max-height:500px;object-fit:cover']);
          echo '</div>';
      }
      return;
  }
  ?>
  <div class="property-carousel">
      <div class="property-carousel__track">
          <?php foreach ($gallery_ids as $id): ?>
              <div class="property-carousel__slide">
                  <?php if (wp_attachment_is('video', $id)): ?>
                      <video controls class="property-carousel__media">
                          <source src="<?php echo esc_url(wp_get_attachment_url($id)); ?>">
                      </video>
                  <?php else: ?>
                      <img
                          src="<?php echo esc_url(wp_get_attachment_image_url($id, 'full')); ?>"
                          alt="<?php echo esc_attr(get_the_title()); ?>"
                          class="property-carousel__media"
                      >
                  <?php endif; ?>
              </div>
          <?php endforeach; ?>
      </div>
      <?php if (count($gallery_ids) > 1): ?>
          <button type="button" class="property-carousel__arrow property-carousel__arrow--prev" aria-label="Previous photo">‹</button>
          <button type="button" class="property-carousel__arrow property-carousel__arrow--next" aria-label="Next photo">›</button>
          <div class="property-carousel__dots">
              <?php foreach ($gallery_ids as $i => $id): ?>
                  <button
                      type="button"
                      class="property-carousel__dot<?php echo $i === 0 ? ' is-active' : ''; ?>"
                      aria-label="Go to photo <?php echo esc_attr($i + 1); ?>"
                  ></button>
              <?php endforeach; ?>
          </div>
      <?php endif; ?>
  </div>
  ```

- [ ] **Step 2: Add the carousel CSS**

  In `theme/cozumel-homes/assets/css/theme.css`, add at the end of the file (after the `@media (max-width: 640px)` block ending at line 99):

  ```css

  .property-carousel {
      position: relative;
      width: 100%;
      max-height: 500px;
      overflow: hidden;
  }
  .property-carousel__track {
      display: flex;
      overflow-x: auto;
      scroll-snap-type: x mandatory;
      scrollbar-width: none;
  }
  .property-carousel__track::-webkit-scrollbar { display: none; }
  .property-carousel__slide {
      flex: 0 0 100%;
      scroll-snap-align: start;
  }
  .property-carousel__media {
      width: 100%;
      max-height: 500px;
      object-fit: cover;
      display: block;
  }
  .property-carousel__arrow {
      position: absolute;
      top: 50%;
      transform: translateY(-50%);
      background: rgba(0,0,0,0.4);
      color: var(--color-white);
      border: none;
      width: 40px;
      height: 40px;
      border-radius: 50%;
      font-size: 1.5rem;
      cursor: pointer;
      z-index: 2;
  }
  .property-carousel__arrow--prev { left: 12px; }
  .property-carousel__arrow--next { right: 12px; }
  .property-carousel__dots {
      position: absolute;
      bottom: 12px;
      left: 50%;
      transform: translateX(-50%);
      display: flex;
      gap: 8px;
      z-index: 2;
  }
  .property-carousel__dot {
      width: 10px;
      height: 10px;
      border-radius: 50%;
      border: none;
      background: rgba(255,255,255,0.5);
      cursor: pointer;
      padding: 0;
  }
  .property-carousel__dot.is-active { background: var(--color-white); }
  ```

- [ ] **Step 3: Write the frontend carousel JS**

  Create `theme/cozumel-homes/assets/js/carousel.js`:

  ```js
  document.addEventListener('DOMContentLoaded', function () {
      document.querySelectorAll('.property-carousel').forEach(function (carousel) {
          var track = carousel.querySelector('.property-carousel__track');
          var slides = carousel.querySelectorAll('.property-carousel__slide');
          var dots = carousel.querySelectorAll('.property-carousel__dot');
          var prevBtn = carousel.querySelector('.property-carousel__arrow--prev');
          var nextBtn = carousel.querySelector('.property-carousel__arrow--next');
          var current = 0;

          function goTo(index) {
              current = Math.max(0, Math.min(index, slides.length - 1));
              track.scrollTo({ left: track.clientWidth * current, behavior: 'smooth' });
              dots.forEach(function (dot, i) {
                  dot.classList.toggle('is-active', i === current);
              });
          }

          if (prevBtn) prevBtn.addEventListener('click', function () { goTo(current - 1); });
          if (nextBtn) nextBtn.addEventListener('click', function () { goTo(current + 1); });
          dots.forEach(function (dot, i) {
              dot.addEventListener('click', function () { goTo(i); });
          });

          carousel.setAttribute('tabindex', '0');
          carousel.addEventListener('keydown', function (e) {
              if (e.key === 'ArrowLeft') goTo(current - 1);
              if (e.key === 'ArrowRight') goTo(current + 1);
          });
      });
  });
  ```

- [ ] **Step 4: Enqueue the carousel JS only on single property pages**

  In `theme/cozumel-homes/functions.php`, modify `cozumel_enqueue_styles()` (lines 2-7) to also enqueue the new script:

  ```php
  function cozumel_enqueue_styles() {
      wp_enqueue_style('parent-style', get_template_directory_uri() . '/style.css');
      wp_enqueue_style('child-style', get_stylesheet_uri(), ['parent-style']);
      wp_enqueue_style('cozumel-theme', get_stylesheet_directory_uri() . '/assets/css/theme.css', ['child-style'], '1.0.0');

      if (is_singular(['rental-property', 'forsale-property'])) {
          wp_enqueue_script(
              'cozumel-carousel',
              get_stylesheet_directory_uri() . '/assets/js/carousel.js',
              [],
              '1.0.0',
              true
          );
      }
  }
  add_action('wp_enqueue_scripts', 'cozumel_enqueue_styles');
  ```

- [ ] **Step 5: Wire the carousel into `single-rental-property.php`**

  In `theme/cozumel-homes/single-rental-property.php`, replace the existing hero block (lines 12-16):

  ```php
          <?php if (has_post_thumbnail()): ?>
              <div class="property-single__hero">
                  <?php the_post_thumbnail('full', ['style' => 'width:100%;max-height:500px;object-fit:cover']); ?>
              </div>
          <?php endif; ?>
  ```

  with:

  ```php
          <?php get_template_part('template-parts/carousel'); ?>
  ```

- [ ] **Step 6: Wire the carousel into `single-forsale-property.php`**

  In `theme/cozumel-homes/single-forsale-property.php`, replace the existing hero block (lines 11-15):

  ```php
          <?php if (has_post_thumbnail()): ?>
              <div class="property-single__hero">
                  <?php the_post_thumbnail('full', ['style' => 'width:100%;max-height:500px;object-fit:cover']); ?>
              </div>
          <?php endif; ?>
  ```

  with:

  ```php
          <?php get_template_part('template-parts/carousel'); ?>
  ```

- [ ] **Step 7: Verify in the browser**

  Open `http://cozumel-homes.local/rentals/cool-caribbean-views/` (adjust slug if different) — since `gallery_ids` is still empty at this point (Task 4 hasn't run yet), confirm the page falls back cleanly to the existing single featured-image hero with no errors or blank space.

  Then, in wp-admin, use the Task 2 picker to add 3+ test photos to Cool Caribbean Views' gallery, save, and reload the front-end page. Confirm:
  - The carousel renders with arrows and dots (since more than 1 slide).
  - Clicking the arrows and dots moves between slides.
  - Left/right arrow keys move between slides when the carousel is focused (click it first, then press arrow keys).
  - Resizing the browser to a narrow (mobile) width and swiping left/right on the image area also moves between slides.

  Remove the test photos afterward via the same picker (uncheck/remove + save) so Task 4's real migration starts from a clean `gallery_ids`.

- [ ] **Step 8: Commit**

  ```bash
  cd ~/Projects/Cozumel-Website
  git add theme/cozumel-homes/template-parts/carousel.php theme/cozumel-homes/assets/css/theme.css theme/cozumel-homes/assets/js/carousel.js theme/cozumel-homes/functions.php theme/cozumel-homes/single-rental-property.php theme/cozumel-homes/single-forsale-property.php
  git commit -m "feat: add photo/video carousel to rental and for-sale single property pages"
  ```

---

### Task 4: Bulk photo migration for the 3 rentals

**Files:**
- None (one-time data migration via REST, no new files)

**Interfaces:**
- Consumes: `gallery_ids` meta (Task 1), Task 2/3's working admin+frontend pipeline, the `wp/v2/media` and `wp/v2/rental-property` REST endpoints (already confirmed working as of the SSL/Application Passwords fix).
- Produces: populated `gallery_ids` on posts 24 (Cool Caribbean Views), 25 (Casa Bohemia), 26 (Nah Ha 101).

---

- [ ] **Step 1: Generate a fresh Application Password**

  In wp-admin → Users → your profile (`akrati32`) → Application Passwords, create one named `cozumel-manager-media` (the prior one used during design was revoked). Copy the generated password — you'll only see it once.

- [ ] **Step 2: Confirm each property's resized photo count**

  Run:
  ```bash
  for dir in prop-001 prop-002 prop-003; do
    echo "$dir:"
    ls ~/Library/Containers/Team-Paraiso.CozumelManager/Data/Library/Application\ Support/CozumelManager/Photos/$dir/resized-*.avif | wc -l
  done
  ```
  Expected: a non-zero count for all 3 (matches the earlier exploration — dozens of `resized-*.avif` files per property, one per original photo). Only these `resized-*.avif` files are uploaded — the plain `.jpg` originals in the same folders are skipped, per the "prefer AVIF" migration rule.

- [ ] **Step 3: Run the migration for each property**

  Run (replace `<APP_PASSWORD>` with the password from Step 1; note the mapping — `prop-001` → post 24, `prop-002` → post 25, `prop-003` → post 26):

  ```bash
  CREDS="akrati32:<APP_PASSWORD>"
  BASE="http://cozumel-homes.local/wp-json/wp/v2"

  migrate_property() {
    local prop_dir="$1" post_id="$2" label="$3"
    local photos_dir="$HOME/Library/Containers/Team-Paraiso.CozumelManager/Data/Library/Application Support/CozumelManager/Photos/$prop_dir"
    echo "=== $label ==="
    local ids=()
    for file in "$photos_dir"/resized-*.avif; do
      resp=$(curl -s -u "$CREDS" -X POST "$BASE/media" \
        -H "Content-Disposition: attachment; filename=$(basename "$file")" \
        -H "Content-Type: image/avif" \
        --data-binary "@$file")
      media_id=$(echo "$resp" | python3 -c "import sys,json; print(json.load(sys.stdin,strict=False).get('id',''))")
      if [[ -z "$media_id" ]]; then
        echo "UPLOAD FAILED for $(basename "$file"): $resp"
        continue
      fi
      echo "uploaded $(basename "$file") -> media #$media_id"
      ids+=("$media_id")
    done
    ids_csv=$(IFS=,; echo "${ids[*]}")
    ids_json="[$ids_csv]"
    patch=$(curl -s -u "$CREDS" -X PATCH "$BASE/rental-property/$post_id" \
      -H "Content-Type: application/json" \
      -d "{\"meta\": {\"gallery_ids\": $ids_json}}")
    echo "$patch" | python3 -c "import sys,json; d=json.load(sys.stdin,strict=False); print('$label gallery_ids now:', d.get('meta',{}).get('gallery_ids'))"
  }

  migrate_property "prop-001" 24 "Cool Caribbean Views"
  migrate_property "prop-002" 25 "Casa Bohemia"
  migrate_property "prop-003" 26 "Nah Ha 101"
  ```

- [ ] **Step 4: Verify each property's gallery via REST**

  Run:
  ```bash
  for id in 24 25 26; do
    curl -s "http://cozumel-homes.local/wp-json/wp/v2/rental-property/$id?_fields=id,title,meta" | python3 -c "import sys,json; d=json.load(sys.stdin,strict=False); print(d['id'], d['title']['rendered'], '->', len(d['meta']['gallery_ids']), 'photos')"
  done
  ```
  Expected: all 3 properties show a photo count matching Step 2's per-property counts.

- [ ] **Step 5: Verify visually in the browser**

  Load each rental's single page (`/rentals/cool-caribbean-views/`, `/rentals/casa-bohemia/`, `/rentals/nah-ha-condominium-101/` — adjust slugs as needed) and confirm the carousel now shows the full photo set with working arrows/dots, matching Task 3's verification but with the real migrated photos instead of test ones.

- [ ] **Step 6: Revoke the migration Application Password**

  Same as before — in wp-admin → Users → Profile → Application Passwords, revoke `cozumel-manager-media` now that the one-time migration is done.
