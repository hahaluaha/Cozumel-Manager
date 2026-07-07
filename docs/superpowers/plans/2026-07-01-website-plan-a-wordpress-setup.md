# Companion Website — Plan A: WordPress Setup, Theme & Content

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and populate a fully functional WordPress property listing website running locally in Local by Flywheel, ready for the booking/availability integration (Plan C, design TBD) and Python sync daemon (Plan B).

**Architecture:** GeneratePress child theme with two Custom Post Types (`rental-property`, `forsale-property`), custom meta fields for structured data, PHP templates for all pages, swappable Google Maps embed, and a custom PHP inquiry form (no third-party form plugin — see project preference in Task 8). All 4 properties entered with full content.

**Tech Stack:** WordPress, PHP 8+, GeneratePress (free theme), Local by Flywheel (local dev environment), Git. No third-party WordPress plugins — per project preference, functionality that would normally come from a plugin (contact forms, and eventually booking/availability in Plan C) is built as custom theme code instead.

## Global Constraints

- **Separate repo:** Implementation files live in a new `Cozumel-Website` GitHub repo — NOT in `Cozumel_App_Final`. This plan file lives in the Mac app repo as documentation only.
- Child theme name (directory and slug): `cozumel-homes`
- Parent theme: `generatepress`
- CPT slugs: `rental-property` (archive at `/rentals/`) and `forsale-property` (archive at `/for-sale/`)
- Map provider constant: `COZUMEL_MAP_PROVIDER` — default `'google'`; valid values `'google'`, `'apple'`, `'openstreetmap'`
- Google Maps API key stored in `wp-config.php` as `GOOGLE_MAPS_API_KEY` — never in theme files or git
- Contact email: `home@cozumelhomes.net`
- Local dev URL: `http://cozumel-homes.local`
- `notes` field on for-sale properties: stored in meta, never displayed publicly
- Inactive/maintenance rental properties: WordPress post status set to Draft (hidden from public)
- Booking/availability calendar: placeholder comment in template — implemented in Plan C (design not yet started; will be custom-built, not a plugin, per project preference — see Task 8)
- No page builders and no third-party plugins — pure PHP templates and custom theme code only

---

### Task 1: Repository + Local WordPress Setup

**Files:**
- Create: `Cozumel-Website/.gitignore`
- Create: `Cozumel-Website/README.md`
- Create: `Cozumel-Website/theme/cozumel-homes/` (empty directory placeholder)

**Interfaces:**
- Produces: GitHub repo `Cozumel-Website`, local WordPress site at `http://cozumel-homes.local`, child theme directory symlinked into Local's themes folder

---

- [ ] **Step 1: Install Local by Flywheel**

  Download from https://localwp.com and install. Open the app.

- [ ] **Step 2: Create a new WordPress site in Local**

  Click **+** → Create new site → Site name: `cozumel-homes` → Continue → Choose "Preferred" setup → WordPress username: `admin`, password: (save this), email: `home@cozumelhomes.net` → Add Site.

  Local creates the site. Note the path shown — typically:
  `~/Local Sites/cozumel-homes/app/public/`

  Start the site. Verify: open `http://cozumel-homes.local` in your browser — default WordPress site should load.

- [ ] **Step 3: Create the GitHub repo**

  ```bash
  mkdir ~/Projects/Cozumel-Website
  cd ~/Projects/Cozumel-Website
  git init
  ```

  On GitHub: create a new public repo named `Cozumel-Website`. Then:

  ```bash
  git remote add origin https://github.com/hahaluaha/Cozumel-Website.git
  ```

- [ ] **Step 4: Create initial repo structure**

  Create `~/Projects/Cozumel-Website/.gitignore`:
  ```
  .DS_Store
  node_modules/
  *.log
  wp-config.php
  ```

  Create `~/Projects/Cozumel-Website/README.md`:
  ```markdown
  # Cozumel Homes — Website

  WordPress child theme and sync daemon for cozumelhomes.net.

  ## Development

  1. Install Local by Flywheel
  2. Create a site named `cozumel-homes`
  3. Symlink `theme/cozumel-homes` into the Local themes directory
  4. Install GeneratePress, activate the child theme
  ```

  Create the theme directory:
  ```bash
  mkdir -p ~/Projects/Cozumel-Website/theme/cozumel-homes
  ```

- [ ] **Step 5: Symlink theme into Local's WordPress**

  ```bash
  ln -s ~/Projects/Cozumel-Website/theme/cozumel-homes \
    ~/Local\ Sites/cozumel-homes/app/public/wp-content/themes/cozumel-homes
  ```

  Verify the symlink:
  ```bash
  ls ~/Local\ Sites/cozumel-homes/app/public/wp-content/themes/
  ```
  Expected: `cozumel-homes` appears in the list (as a symlink).

- [ ] **Step 6: Initial commit**

  ```bash
  cd ~/Projects/Cozumel-Website
  git add .gitignore README.md theme/
  git commit -m "chore: initial repo structure"
  git push -u origin main
  ```

---

### Task 2: GeneratePress Child Theme

**Files:**
- Create: `theme/cozumel-homes/style.css`
- Create: `theme/cozumel-homes/functions.php`
- Create: `theme/cozumel-homes/assets/css/theme.css`

**Interfaces:**
- Consumes: GeneratePress installed in WordPress
- Produces: Active child theme at `http://cozumel-homes.local` with base CSS loaded

---

- [ ] **Step 1: Install GeneratePress**

  In WordPress admin (`http://cozumel-homes.local/wp-admin`) → Appearance → Themes → Add New → search "GeneratePress" → Install → Activate.

  Do NOT activate it yet — we'll activate the child theme instead in Step 4.

- [ ] **Step 2: Create `style.css`**

  Full content of `theme/cozumel-homes/style.css`:
  ```css
  /*
  Theme Name: Cozumel Homes
  Theme URI: https://cozumelhomes.net
  Description: Child theme for Cozumel Homes vacation rental website
  Author: Fernando Gonzalez
  Template: generatepress
  Version: 1.0.0
  */
  ```

- [ ] **Step 3: Create `functions.php`**

  Full content of `theme/cozumel-homes/functions.php`:
  ```php
  <?php
  function cozumel_enqueue_styles() {
      wp_enqueue_style('parent-style', get_template_directory_uri() . '/style.css');
      wp_enqueue_style('child-style', get_stylesheet_uri(), ['parent-style']);
      wp_enqueue_style('cozumel-theme', get_stylesheet_directory_uri() . '/assets/css/theme.css', ['child-style'], '1.0.0');
  }
  add_action('wp_enqueue_scripts', 'cozumel_enqueue_styles');

  // Map provider: 'google' | 'apple' | 'openstreetmap'
  define('COZUMEL_MAP_PROVIDER', 'google');
  define('COZUMEL_GOOGLE_MAPS_KEY', defined('GOOGLE_MAPS_API_KEY') ? GOOGLE_MAPS_API_KEY : '');

  require_once get_stylesheet_directory() . '/inc/post-types.php';
  require_once get_stylesheet_directory() . '/inc/meta-fields.php';
  require_once get_stylesheet_directory() . '/inc/inquiry-form.php';
  ```

- [ ] **Step 4: Create base CSS**

  Full content of `theme/cozumel-homes/assets/css/theme.css`:
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

  body {
      font-family: var(--font-sans);
      color: var(--color-text);
      background: var(--color-white);
  }

  .btn {
      display: inline-block;
      padding: 12px 28px;
      border-radius: 4px;
      font-weight: 600;
      text-decoration: none;
      cursor: pointer;
      transition: opacity 0.2s;
  }
  .btn:hover { opacity: 0.85; }
  .btn--primary { background: var(--color-ocean); color: var(--color-white); }
  .btn--airbnb { background: #ff5a5f; color: var(--color-white); }
  .btn--outline { border: 2px solid var(--color-ocean); color: var(--color-ocean); background: transparent; }

  .properties-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
      gap: 32px;
      padding: 32px 0;
  }

  .property-card {
      border-radius: 8px;
      overflow: hidden;
      box-shadow: 0 2px 12px rgba(0,0,0,0.08);
      transition: box-shadow 0.2s;
  }
  .property-card:hover { box-shadow: 0 4px 24px rgba(0,0,0,0.14); }
  .property-card a { text-decoration: none; color: inherit; }
  .property-card__image { width: 100%; height: 220px; object-fit: cover; display: block; }
  .property-card__body { padding: 20px; }
  .property-card__title { font-family: var(--font-primary); font-size: 1.2rem; margin: 0 0 6px; }
  .property-card__neighborhood { color: var(--color-muted); font-size: 0.9rem; margin: 0 0 6px; }
  .property-card__specs { color: var(--color-muted); font-size: 0.85rem; margin: 0 0 10px; }
  .property-card__rate { font-weight: 700; font-size: 1.1rem; color: var(--color-ocean); margin: 0; }

  .property-single { max-width: 960px; margin: 0 auto; padding: 32px 24px; }
  .property-single h1 { font-family: var(--font-primary); font-size: 2.2rem; }
  .property-single__neighborhood { color: var(--color-muted); font-size: 1.1rem; }
  .property-single__specs { color: var(--color-muted); }
  .property-single__rate { font-size: 1.5rem; font-weight: 700; color: var(--color-ocean); }
  .property-single__booking { margin: 32px 0; display: flex; gap: 16px; flex-wrap: wrap; align-items: center; }
  .property-single__map { margin: 32px 0; border-radius: 8px; overflow: hidden; }
  .property-single__inquiry { margin-top: 48px; }

  .hero {
      background: var(--color-sand);
      padding: 80px 24px;
      text-align: center;
  }
  .hero__title { font-family: var(--font-primary); font-size: 3rem; margin: 0 0 16px; }
  .hero__tagline { font-size: 1.3rem; color: var(--color-muted); margin: 0 0 32px; }

  .section { padding: 64px 24px; max-width: 1100px; margin: 0 auto; }
  .section__title { font-family: var(--font-primary); font-size: 2rem; margin: 0 0 8px; }
  .section__subtitle { color: var(--color-muted); margin: 0 0 32px; }

  .testimonials { background: var(--color-sand); padding: 64px 24px; }
  .testimonials__grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 24px; max-width: 1100px; margin: 0 auto; }
  .testimonial { background: var(--color-white); padding: 28px; border-radius: 8px; }
  .testimonial__text { font-style: italic; margin: 0 0 16px; line-height: 1.7; }
  .testimonial__author { font-weight: 600; color: var(--color-muted); font-size: 0.9rem; }

  .site-footer { background: var(--color-text); color: var(--color-white); padding: 48px 24px; text-align: center; }
  .site-footer a { color: var(--color-sand); }
  .site-footer__address { margin: 0 0 8px; }
  .site-footer__email { margin: 0 0 16px; }

  @media (max-width: 640px) {
      .hero__title { font-size: 2rem; }
      .properties-grid { grid-template-columns: 1fr; }
  }
  ```

- [ ] **Step 5: Create `inc/` directory**

  ```bash
  mkdir -p ~/Projects/Cozumel-Website/theme/cozumel-homes/inc
  touch ~/Projects/Cozumel-Website/theme/cozumel-homes/inc/post-types.php
  touch ~/Projects/Cozumel-Website/theme/cozumel-homes/inc/meta-fields.php
  touch ~/Projects/Cozumel-Website/theme/cozumel-homes/inc/inquiry-form.php
  ```

  Leave all three files empty for now (post-types.php and meta-fields.php are filled in Task 3, inquiry-form.php in Task 8).

- [ ] **Step 6: Activate child theme in WordPress**

  In wp-admin → Appearance → Themes → find "Cozumel Homes" → Activate.

  Verify: visit `http://cozumel-homes.local` — site loads with GeneratePress layout and no PHP errors.

- [ ] **Step 7: Commit**

  ```bash
  cd ~/Projects/Cozumel-Website
  git add theme/
  git commit -m "feat: add GeneratePress child theme with base CSS"
  git push
  ```

---

### Task 3: Custom Post Types + Meta Fields + Admin UI

**Files:**
- Modify: `theme/cozumel-homes/inc/post-types.php`
- Modify: `theme/cozumel-homes/inc/meta-fields.php`

**Interfaces:**
- Produces: `rental-property` CPT at `/rentals/`, `forsale-property` CPT at `/for-sale/`, meta fields registered on both CPTs, meta boxes visible in wp-admin edit screens

---

- [ ] **Step 1: Write `inc/post-types.php`**

  Full content:
  ```php
  <?php
  function cozumel_register_post_types() {
      register_post_type('rental-property', [
          'labels' => [
              'name'          => 'Rental Properties',
              'singular_name' => 'Rental Property',
              'add_new_item'  => 'Add New Rental Property',
              'edit_item'     => 'Edit Rental Property',
              'view_item'     => 'View Rental Property',
              'all_items'     => 'All Rental Properties',
          ],
          'public'       => true,
          'has_archive'  => true,
          'rewrite'      => ['slug' => 'rentals'],
          'supports'     => ['title', 'editor', 'thumbnail'],
          'show_in_rest' => true,
          'menu_icon'    => 'dashicons-building',
          'menu_position' => 5,
      ]);

      register_post_type('forsale-property', [
          'labels' => [
              'name'          => 'For Sale Properties',
              'singular_name' => 'For Sale Property',
              'add_new_item'  => 'Add New For Sale Property',
              'edit_item'     => 'Edit For Sale Property',
              'view_item'     => 'View Property',
              'all_items'     => 'All For Sale Properties',
          ],
          'public'       => true,
          'has_archive'  => true,
          'rewrite'      => ['slug' => 'for-sale'],
          'supports'     => ['title', 'editor', 'thumbnail'],
          'show_in_rest' => true,
          'menu_icon'    => 'dashicons-store',
          'menu_position' => 6,
      ]);
  }
  add_action('init', 'cozumel_register_post_types');

  // Flush rewrite rules on theme activation (runs once)
  function cozumel_flush_rewrite_rules() {
      cozumel_register_post_types();
      flush_rewrite_rules();
  }
  add_action('after_switch_theme', 'cozumel_flush_rewrite_rules');
  ```

- [ ] **Step 2: Write `inc/meta-fields.php`**

  Full content:
  ```php
  <?php
  // ── Register meta for REST API access ──────────────────────────────────────
  function cozumel_register_meta_fields() {
      $rental_fields = [
          'mac_id', 'neighborhood', 'address', 'base_rate', 'status',
          'max_guests', 'bedrooms', 'bathrooms',
          'latitude', 'longitude', 'airbnb_ical_url', 'airbnb_listing_url',
      ];
      foreach ($rental_fields as $field) {
          register_post_meta('rental-property', $field, [
              'show_in_rest' => true,
              'single'       => true,
              'type'         => 'string',
          ]);
      }

      $forsale_fields = [
          'mac_id', 'asking_price', 'listing_url', 'notes',
          'bedrooms', 'bathrooms', 'latitude', 'longitude',
      ];
      foreach ($forsale_fields as $field) {
          register_post_meta('forsale-property', $field, [
              'show_in_rest' => true,
              'single'       => true,
              'type'         => 'string',
          ]);
      }
  }
  add_action('init', 'cozumel_register_meta_fields');

  // ── Admin meta boxes ────────────────────────────────────────────────────────
  function cozumel_add_meta_boxes() {
      add_meta_box(
          'rental_details', 'Property Details',
          'cozumel_rental_meta_box_html', 'rental-property', 'normal', 'high'
      );
      add_meta_box(
          'forsale_details', 'Property Details',
          'cozumel_forsale_meta_box_html', 'forsale-property', 'normal', 'high'
      );
  }
  add_action('add_meta_boxes', 'cozumel_add_meta_boxes');

  function cozumel_meta_field($key, $label, $post_id, $type = 'text') {
      $value = esc_attr(get_post_meta($post_id, $key, true));
      echo "<p><label style='font-weight:600'>{$label}</label><br>";
      echo "<input type='{$type}' name='{$key}' value='{$value}' style='width:100%;margin-top:4px'></p>";
  }

  function cozumel_rental_meta_box_html($post) {
      cozumel_meta_field('mac_id',              'Mac App ID (managed by sync — do not edit)', $post->ID);
      cozumel_meta_field('neighborhood',        'Neighborhood', $post->ID);
      cozumel_meta_field('address',             'Address', $post->ID);
      cozumel_meta_field('base_rate',           'Nightly Rate (USD)', $post->ID);
      cozumel_meta_field('status',              'Status (active / inactive / maintenance)', $post->ID);
      cozumel_meta_field('max_guests',          'Max Guests', $post->ID);
      cozumel_meta_field('bedrooms',            'Bedrooms', $post->ID);
      cozumel_meta_field('bathrooms',           'Bathrooms', $post->ID);
      cozumel_meta_field('latitude',            'Latitude (set once — not overwritten by sync)', $post->ID);
      cozumel_meta_field('longitude',           'Longitude (set once — not overwritten by sync)', $post->ID);
      cozumel_meta_field('airbnb_ical_url',     'Airbnb iCal Export URL', $post->ID);
      cozumel_meta_field('airbnb_listing_url',  'Airbnb Listing URL', $post->ID);
  }

  function cozumel_forsale_meta_box_html($post) {
      cozumel_meta_field('mac_id',       'Mac App ID (managed by sync — do not edit)', $post->ID);
      cozumel_meta_field('asking_price', 'Asking Price (USD)', $post->ID);
      cozumel_meta_field('listing_url',  'External Listing URL', $post->ID);
      cozumel_meta_field('bedrooms',     'Bedrooms', $post->ID);
      cozumel_meta_field('bathrooms',    'Bathrooms', $post->ID);
      cozumel_meta_field('latitude',     'Latitude', $post->ID);
      cozumel_meta_field('longitude',    'Longitude', $post->ID);
      $notes = esc_textarea(get_post_meta($post->ID, 'notes', true));
      echo "<p><label style='font-weight:600'>Notes (internal — not shown publicly)</label><br>";
      echo "<textarea name='notes' style='width:100%;height:80px;margin-top:4px'>{$notes}</textarea></p>";
  }

  // ── Save meta on post save ──────────────────────────────────────────────────
  function cozumel_save_meta($post_id) {
      if (defined('DOING_AUTOSAVE') && DOING_AUTOSAVE) return;
      if (!current_user_can('edit_post', $post_id)) return;

      $all_fields = [
          'mac_id', 'neighborhood', 'address', 'base_rate', 'status',
          'max_guests', 'bedrooms', 'bathrooms',
          'latitude', 'longitude', 'airbnb_ical_url', 'airbnb_listing_url',
          'asking_price', 'listing_url', 'notes',
      ];
      foreach ($all_fields as $field) {
          if (array_key_exists($field, $_POST)) {
              update_post_meta($post_id, $field, sanitize_text_field($_POST[$field]));
          }
      }
  }
  add_action('save_post', 'cozumel_save_meta');
  ```

- [ ] **Step 3: Verify in WordPress admin**

  Visit `http://cozumel-homes.local/wp-admin`. Verify:
  - "Rental Properties" appears in the left sidebar
  - "For Sale Properties" appears in the left sidebar
  - Click "Add New Rental Property" — verify the "Property Details" meta box appears below the editor with all fields listed

- [ ] **Step 4: Verify archive URLs**

  Visit `http://cozumel-homes.local/rentals/` and `http://cozumel-homes.local/for-sale/` — both should return a page (404 would mean rewrite rules need flushing: wp-admin → Settings → Permalinks → Save).

- [ ] **Step 5: Commit**

  ```bash
  cd ~/Projects/Cozumel-Website
  git add theme/cozumel-homes/inc/
  git commit -m "feat: register CPTs and meta fields with admin UI"
  git push
  ```

---

### Task 4: Google Maps Template Part

**Files:**
- Create: `theme/cozumel-homes/template-parts/map.php`

**Interfaces:**
- Consumes: `COZUMEL_MAP_PROVIDER` constant, `COZUMEL_GOOGLE_MAPS_KEY` constant, `latitude` and `longitude` post meta on current post
- Produces: `get_template_part('template-parts/map')` renders an iframe map for any post with lat/lng set

---

- [ ] **Step 1: Get a Google Maps API key**

  1. Go to https://console.cloud.google.com
  2. Create a project named "Cozumel Homes"
  3. Enable the **Maps Embed API**
  4. Create an API key → restrict it to your domain (`cozumel-homes.local` for dev, `cozumelhomes.net` for production)
  5. Copy the key

- [ ] **Step 2: Add key to `wp-config.php`**

  Open `~/Local Sites/cozumel-homes/app/public/wp-config.php` in your editor. Add this line **before** `/* That's all, stop editing! */`:

  ```php
  define('GOOGLE_MAPS_API_KEY', 'YOUR_KEY_HERE');
  ```

  `wp-config.php` is gitignored — this key never enters the repo.

- [ ] **Step 3: Create `template-parts/map.php`**

  ```bash
  mkdir -p ~/Projects/Cozumel-Website/theme/cozumel-homes/template-parts
  ```

  Full content of `theme/cozumel-homes/template-parts/map.php`:
  ```php
  <?php
  $lat = get_post_meta(get_the_ID(), 'latitude', true);
  $lng = get_post_meta(get_the_ID(), 'longitude', true);

  if (!$lat || !$lng) {
      return; // No map if coordinates not set
  }

  $lat = floatval($lat);
  $lng = floatval($lng);
  ?>
  <div class="property-single__map">
  <?php switch (COZUMEL_MAP_PROVIDER):
      case 'openstreetmap': ?>
          <iframe
              width="100%" height="350" frameborder="0" scrolling="no"
              src="https://www.openstreetmap.org/export/embed.html?bbox=<?php echo ($lng - 0.005); ?>,<?php echo ($lat - 0.005); ?>,<?php echo ($lng + 0.005); ?>,<?php echo ($lat + 0.005); ?>&layer=mapnik&marker=<?php echo $lat; ?>,<?php echo $lng; ?>"
          ></iframe>
          <?php break;
      case 'apple': ?>
          <div id="cozumel-map" style="width:100%;height:350px;background:#e8e8e8;display:flex;align-items:center;justify-content:center">
              <p style="color:#666">Map loading…</p>
          </div>
          <!-- When implementing: pin to a specific version and compute SRI hash (integrity="sha384-...") before deploying -->
          <script src="https://cdn.apple-mapkit.com/mk/5.x.x/mapkit.js" crossorigin="anonymous"></script>
          <script>
              mapkit.init({ authorizationCallback: function(done) { done('<?php echo esc_js(COZUMEL_MAPKIT_TOKEN); ?>'); } });
              var map = new mapkit.Map('cozumel-map');
              var coord = new mapkit.Coordinate(<?php echo $lat; ?>, <?php echo $lng; ?>);
              map.center = coord;
              map.addAnnotation(new mapkit.MarkerAnnotation(coord));
          </script>
          <?php break;
      case 'google':
      default: ?>
          <iframe
              width="100%" height="350" frameborder="0" style="border:0"
              src="https://www.google.com/maps/embed/v1/place?key=<?php echo esc_attr(COZUMEL_GOOGLE_MAPS_KEY); ?>&q=<?php echo $lat; ?>,<?php echo $lng; ?>&zoom=15"
              allowfullscreen
          ></iframe>
          <?php break;
  endswitch; ?>
  </div>
  ```

- [ ] **Step 4: Verify map renders**

  Create a test rental property in wp-admin:
  - Title: "Test Property"
  - Set Latitude: `20.5088`, Longitude: `-86.9468` (Cozumel coordinates)
  - Publish

  Visit the single post URL (shown in wp-admin "View Post"). Confirm the map iframe appears (may show "This page can't load Google Maps correctly" if the API key is not yet active — that's OK, the iframe is present).

  Delete the test property after verifying.

- [ ] **Step 5: Commit**

  ```bash
  cd ~/Projects/Cozumel-Website
  git add theme/cozumel-homes/template-parts/
  git commit -m "feat: add swappable map template part (Google Maps default)"
  git push
  ```

---

### Task 5: Property Cards + Archive Pages

**Files:**
- Create: `theme/cozumel-homes/template-parts/property-card.php`
- Create: `theme/cozumel-homes/template-parts/forsale-card.php`
- Create: `theme/cozumel-homes/archive-rental-property.php`
- Create: `theme/cozumel-homes/archive-forsale-property.php`

**Interfaces:**
- Produces: `/rentals/` shows a grid of rental property cards; `/for-sale/` shows for-sale property cards; both cards are reusable via `get_template_part`

---

- [ ] **Step 1: Create `template-parts/property-card.php`**

  ```php
  <?php
  $neighborhood = get_post_meta(get_the_ID(), 'neighborhood', true);
  $guests       = get_post_meta(get_the_ID(), 'max_guests', true);
  $bedrooms     = get_post_meta(get_the_ID(), 'bedrooms', true);
  $bathrooms    = get_post_meta(get_the_ID(), 'bathrooms', true);
  $rate         = get_post_meta(get_the_ID(), 'base_rate', true);
  ?>
  <div class="property-card">
      <a href="<?php the_permalink(); ?>">
          <?php if (has_post_thumbnail()): ?>
              <?php the_post_thumbnail('medium_large', ['class' => 'property-card__image', 'alt' => get_the_title()]); ?>
          <?php else: ?>
              <div class="property-card__image property-card__image--placeholder"></div>
          <?php endif; ?>
          <div class="property-card__body">
              <h3 class="property-card__title"><?php the_title(); ?></h3>
              <?php if ($neighborhood): ?>
                  <p class="property-card__neighborhood"><?php echo esc_html($neighborhood); ?></p>
              <?php endif; ?>
              <?php if ($guests || $bedrooms || $bathrooms): ?>
                  <p class="property-card__specs">
                      <?php
                      $specs = array_filter([
                          $guests    ? "{$guests} guests" : '',
                          $bedrooms  ? "{$bedrooms} bed"  : '',
                          $bathrooms ? "{$bathrooms} bath" : '',
                      ]);
                      echo esc_html(implode(' · ', $specs));
                      ?>
                  </p>
              <?php endif; ?>
              <?php if ($rate): ?>
                  <p class="property-card__rate">$<?php echo esc_html(number_format((float)$rate)); ?> / night</p>
              <?php endif; ?>
          </div>
      </a>
  </div>
  ```

- [ ] **Step 2: Create `template-parts/forsale-card.php`**

  ```php
  <?php
  $price     = get_post_meta(get_the_ID(), 'asking_price', true);
  $bedrooms  = get_post_meta(get_the_ID(), 'bedrooms', true);
  $bathrooms = get_post_meta(get_the_ID(), 'bathrooms', true);
  ?>
  <div class="property-card property-card--forsale">
      <a href="<?php the_permalink(); ?>">
          <?php if (has_post_thumbnail()): ?>
              <?php the_post_thumbnail('medium_large', ['class' => 'property-card__image', 'alt' => get_the_title()]); ?>
          <?php else: ?>
              <div class="property-card__image property-card__image--placeholder"></div>
          <?php endif; ?>
          <div class="property-card__body">
              <h3 class="property-card__title"><?php the_title(); ?></h3>
              <?php if ($bedrooms || $bathrooms): ?>
                  <p class="property-card__specs">
                      <?php
                      $specs = array_filter([
                          $bedrooms  ? "{$bedrooms} bed"   : '',
                          $bathrooms ? "{$bathrooms} bath"  : '',
                      ]);
                      echo esc_html(implode(' · ', $specs));
                      ?>
                  </p>
              <?php endif; ?>
              <?php if ($price): ?>
                  <p class="property-card__rate">$<?php echo esc_html(number_format((float)$price)); ?> USD</p>
              <?php endif; ?>
          </div>
      </a>
  </div>
  ```

- [ ] **Step 3: Create `archive-rental-property.php`**

  ```php
  <?php get_header(); ?>
  <main class="archive-page">
      <div class="section">
          <h1 class="section__title">Vacation Rentals</h1>
          <p class="section__subtitle">Premium properties in Cozumel, Mexico — managed by Kelley Morgan Gonzalez</p>
          <?php if (have_posts()): ?>
              <div class="properties-grid">
                  <?php while (have_posts()) : the_post(); ?>
                      <?php get_template_part('template-parts/property-card'); ?>
                  <?php endwhile; ?>
              </div>
          <?php else: ?>
              <p>No properties available at this time. <a href="/contact/">Contact us</a> to learn more.</p>
          <?php endif; ?>
      </div>
  </main>
  <?php get_footer(); ?>
  ```

- [ ] **Step 4: Create `archive-forsale-property.php`**

  ```php
  <?php get_header(); ?>
  <main class="archive-page">
      <div class="section">
          <h1 class="section__title">Properties for Sale</h1>
          <p class="section__subtitle">Exceptional Cozumel real estate — represented by Kelley Morgan Gonzalez</p>
          <?php if (have_posts()): ?>
              <div class="properties-grid">
                  <?php while (have_posts()) : the_post(); ?>
                      <?php get_template_part('template-parts/forsale-card'); ?>
                  <?php endwhile; ?>
              </div>
          <?php else: ?>
              <p>No properties currently listed for sale. <a href="/contact/">Contact us</a> for more information.</p>
          <?php endif; ?>
      </div>
  </main>
  <?php get_footer(); ?>
  ```

- [ ] **Step 5: Add a test property and verify**

  In wp-admin: add one rental property (title: "Test Rental", neighborhood: "Downtown", rate: 250, guests: 2, bedrooms: 1, bathrooms: 1, publish).

  Visit `http://cozumel-homes.local/rentals/` — property card should appear.
  Visit `http://cozumel-homes.local/for-sale/` — empty state message should appear.

  Delete the test property.

- [ ] **Step 6: Commit**

  ```bash
  cd ~/Projects/Cozumel-Website
  git add theme/cozumel-homes/template-parts/forsale-card.php \
           theme/cozumel-homes/template-parts/property-card.php \
           theme/cozumel-homes/archive-rental-property.php \
           theme/cozumel-homes/archive-forsale-property.php
  git commit -m "feat: add property cards and archive pages"
  git push
  ```

---

### Task 6: Individual Property Page Templates

**Files:**
- Create: `theme/cozumel-homes/single-rental-property.php`
- Create: `theme/cozumel-homes/single-forsale-property.php`

**Interfaces:**
- Consumes: `template-parts/map.php` (Task 4), all meta fields from Task 3
- Produces: Individual rental page at `/rentals/<slug>/` and for-sale page at `/for-sale/<slug>/` with full details, map, booking placeholder, and inquiry form shortcode

---

- [ ] **Step 1: Create `single-rental-property.php`**

  ```php
  <?php get_header(); ?>
  <main class="property-single">
      <?php while (have_posts()) : the_post(); ?>
          <?php
          $neighborhood     = get_post_meta(get_the_ID(), 'neighborhood', true);
          $address          = get_post_meta(get_the_ID(), 'address', true);
          $rate             = get_post_meta(get_the_ID(), 'base_rate', true);
          $guests           = get_post_meta(get_the_ID(), 'max_guests', true);
          $bedrooms         = get_post_meta(get_the_ID(), 'bedrooms', true);
          $bathrooms        = get_post_meta(get_the_ID(), 'bathrooms', true);
          $airbnb_url       = get_post_meta(get_the_ID(), 'airbnb_listing_url', true);
          ?>

          <?php if (has_post_thumbnail()): ?>
              <div class="property-single__hero">
                  <?php the_post_thumbnail('full', ['style' => 'width:100%;max-height:500px;object-fit:cover']); ?>
              </div>
          <?php endif; ?>

          <div style="max-width:960px;margin:0 auto;padding:32px 24px">

              <h1 style="font-family:Georgia,serif;font-size:2.2rem;margin:0 0 8px"><?php the_title(); ?></h1>

              <?php if ($neighborhood): ?>
                  <p class="property-single__neighborhood"><?php echo esc_html($neighborhood); ?></p>
              <?php endif; ?>

              <?php if ($guests || $bedrooms || $bathrooms): ?>
                  <p class="property-single__specs">
                      <?php
                      $specs = array_filter([
                          $guests    ? "{$guests} guests"   : '',
                          $bedrooms  ? "{$bedrooms} bedrooms" : '',
                          $bathrooms ? "{$bathrooms} bathrooms" : '',
                      ]);
                      echo esc_html(implode(' · ', $specs));
                      ?>
                  </p>
              <?php endif; ?>

              <?php if ($rate): ?>
                  <p class="property-single__rate">$<?php echo esc_html(number_format((float)$rate)); ?> / night</p>
              <?php endif; ?>

              <div class="property-single__booking">
                  <?php /* Custom booking/availability calendar — added in Plan C (not yet designed) */ ?>
                  <?php if ($airbnb_url): ?>
                      <a href="<?php echo esc_url($airbnb_url); ?>" class="btn btn--airbnb" target="_blank" rel="noopener noreferrer">Book on Airbnb</a>
                  <?php endif; ?>
              </div>

              <div class="property-single__description">
                  <?php the_content(); ?>
              </div>

              <?php if ($address): ?>
                  <p style="color:#6b6b6b;font-size:0.9rem"><?php echo esc_html($address); ?></p>
              <?php endif; ?>

              <?php get_template_part('template-parts/map'); ?>

              <div class="property-single__inquiry">
                  <h3>Have a question or want to book?</h3>
                  <?php cozumel_render_inquiry_form(get_the_title()); ?>
              </div>

          </div>
      <?php endwhile; ?>
  </main>
  <?php get_footer(); ?>
  ```

- [ ] **Step 2: Create `single-forsale-property.php`**

  ```php
  <?php get_header(); ?>
  <main class="property-single">
      <?php while (have_posts()) : the_post(); ?>
          <?php
          $price       = get_post_meta(get_the_ID(), 'asking_price', true);
          $listing_url = get_post_meta(get_the_ID(), 'listing_url', true);
          $bedrooms    = get_post_meta(get_the_ID(), 'bedrooms', true);
          $bathrooms   = get_post_meta(get_the_ID(), 'bathrooms', true);
          ?>

          <?php if (has_post_thumbnail()): ?>
              <div class="property-single__hero">
                  <?php the_post_thumbnail('full', ['style' => 'width:100%;max-height:500px;object-fit:cover']); ?>
              </div>
          <?php endif; ?>

          <div style="max-width:960px;margin:0 auto;padding:32px 24px">

              <h1 style="font-family:Georgia,serif;font-size:2.2rem;margin:0 0 8px"><?php the_title(); ?></h1>

              <?php if ($bedrooms || $bathrooms): ?>
                  <p class="property-single__specs">
                      <?php
                      $specs = array_filter([
                          $bedrooms  ? "{$bedrooms} bedrooms"  : '',
                          $bathrooms ? "{$bathrooms} bathrooms" : '',
                      ]);
                      echo esc_html(implode(' · ', $specs));
                      ?>
                  </p>
              <?php endif; ?>

              <?php if ($price): ?>
                  <p class="property-single__rate">$<?php echo esc_html(number_format((float)$price)); ?> USD</p>
              <?php endif; ?>

              <?php if ($listing_url): ?>
                  <div style="margin:24px 0">
                      <a href="<?php echo esc_url($listing_url); ?>" class="btn btn--primary" target="_blank" rel="noopener noreferrer">View Full Listing</a>
                  </div>
              <?php endif; ?>

              <div class="property-single__description">
                  <?php the_content(); ?>
              </div>

              <?php get_template_part('template-parts/map'); ?>

              <div class="property-single__inquiry">
                  <h3>Interested in this property?</h3>
                  <?php cozumel_render_inquiry_form(get_the_title()); ?>
              </div>

          </div>
      <?php endwhile; ?>
  </main>
  <?php get_footer(); ?>
  ```

- [ ] **Step 3: Verify**

  Add a test rental property, publish it, click "View Post" — confirm title, specs, "Book on Airbnb" button placeholder, and map area all render. No PHP errors.

  Delete the test property.

- [ ] **Step 4: Commit**

  ```bash
  cd ~/Projects/Cozumel-Website
  git add theme/cozumel-homes/single-rental-property.php \
           theme/cozumel-homes/single-forsale-property.php
  git commit -m "feat: add individual property page templates"
  git push
  ```

---

### Task 7: Home Page

**Files:**
- Create: `theme/cozumel-homes/front-page.php`

**Interfaces:**
- Consumes: `template-parts/property-card.php`, `template-parts/forsale-card.php` (Task 5)
- Produces: WordPress front page at `http://cozumel-homes.local/` with hero, rental grid, for-sale section, testimonials, and inquiry form

---

- [ ] **Step 1: Set WordPress to use a static front page**

  In wp-admin → Settings → Reading → Your homepage displays → select "A static page" → Homepage: create/select a page titled "Home" → Save.

  WordPress will then use `front-page.php` for the homepage.

- [ ] **Step 2: Create `front-page.php`**

  ```php
  <?php get_header(); ?>
  <main>

      <!-- Hero -->
      <section class="hero">
          <h1 class="hero__title">Cozumel Homes</h1>
          <p class="hero__tagline">Premium vacation rentals and real estate in Cozumel, Mexico</p>
          <a href="/rentals/" class="btn btn--primary">View Rentals</a>
          &nbsp;
          <a href="/for-sale/" class="btn btn--outline">Properties for Sale</a>
      </section>

      <!-- About Kelley -->
      <section class="section" style="border-bottom:1px solid #eee">
          <div style="max-width:760px">
              <h2 class="section__title">Boutique Property Management</h2>
              <p style="font-size:1.1rem;line-height:1.8;color:#444">
                  Kelley Morgan Gonzalez brings over 20 years of island experience to every stay.
                  Whether you're planning a diving escape, a family holiday, or searching for your
                  dream property in Cozumel, you'll receive friendly, personalized service from
                  someone who truly knows this island.
              </p>
              <p style="color:#6b6b6b">
                  <a href="mailto:home@cozumelhomes.net">home@cozumelhomes.net</a>
              </p>
          </div>
      </section>

      <!-- Rental Properties -->
      <section class="section">
          <h2 class="section__title">Vacation Rentals</h2>
          <p class="section__subtitle">Hand-selected properties across Cozumel's most sought-after neighborhoods</p>
          <div class="properties-grid">
              <?php
              $rentals = new WP_Query([
                  'post_type'      => 'rental-property',
                  'posts_per_page' => 6,
                  'post_status'    => 'publish',
                  'meta_query'     => [[
                      'key'     => 'status',
                      'value'   => 'active',
                      'compare' => '=',
                  ]],
              ]);
              if ($rentals->have_posts()):
                  while ($rentals->have_posts()) : $rentals->the_post();
                      get_template_part('template-parts/property-card');
                  endwhile;
                  wp_reset_postdata();
              else: ?>
                  <p>Rental properties coming soon.</p>
              <?php endif; ?>
          </div>
          <p style="margin-top:24px"><a href="/rentals/" class="btn btn--outline">View All Rentals</a></p>
      </section>

      <!-- For Sale -->
      <?php
      $forsale = new WP_Query([
          'post_type'      => 'forsale-property',
          'posts_per_page' => 3,
          'post_status'    => 'publish',
      ]);
      if ($forsale->have_posts()): ?>
          <section class="section" style="background:#f9f6f0">
              <h2 class="section__title">Properties for Sale</h2>
              <p class="section__subtitle">Exceptional Cozumel real estate represented by Kelley Morgan Gonzalez</p>
              <div class="properties-grid">
                  <?php while ($forsale->have_posts()) : $forsale->the_post();
                      get_template_part('template-parts/forsale-card');
                  endwhile;
                  wp_reset_postdata(); ?>
              </div>
              <p style="margin-top:24px"><a href="/for-sale/" class="btn btn--outline">View All For Sale</a></p>
          </section>
      <?php endif; ?>

      <!-- Testimonials -->
      <section class="testimonials">
          <div style="max-width:1100px;margin:0 auto">
              <h2 class="section__title" style="text-align:center;margin-bottom:32px">What Our Guests Say</h2>
              <div class="testimonials__grid">
                  <div class="testimonial">
                      <p class="testimonial__text">"The property exceeded our expectations in every way. Kelley was incredibly responsive and made our stay in Cozumel truly memorable."</p>
                      <p class="testimonial__author">— Guest, Nah Ha Condominium 101</p>
                  </div>
                  <div class="testimonial">
                      <p class="testimonial__text">"Vistas increíbles al mar — incredible ocean views. The apartment is exactly as described and Kelley's local knowledge made all the difference."</p>
                      <p class="testimonial__author">— Guest, Cool Caribbean Views</p>
                  </div>
                  <div class="testimonial">
                      <p class="testimonial__text">"We loved staying at Casa Bohemia. A bright, airy home in a wonderful neighborhood — perfect for our family vacation to Cozumel."</p>
                      <p class="testimonial__author">— Guest, Casa Bohemia</p>
                  </div>
              </div>
          </div>
      </section>

      <!-- Home Inquiry -->
      <section class="section" style="max-width:760px">
          <h2 class="section__title">Plan Your Cozumel Stay</h2>
          <p class="section__subtitle">Send us your dates and we'll find the right property for you.</p>
          <?php cozumel_render_inquiry_form(); ?>
      </section>

  </main>
  <?php get_footer(); ?>
  ```

- [ ] **Step 3: Verify**

  Visit `http://cozumel-homes.local/` — confirm hero, about section, empty grids (no properties yet), testimonials, and form area render. No PHP errors.

- [ ] **Step 4: Commit**

  ```bash
  cd ~/Projects/Cozumel-Website
  git add theme/cozumel-homes/front-page.php
  git commit -m "feat: add home page with hero, grids, testimonials"
  git push
  ```

---

### Task 8: Custom Inquiry Form + Contact Page + Navigation + Footer

**Files:**
- Create: `theme/cozumel-homes/inc/inquiry-form.php`
- Create: `theme/cozumel-homes/page-contact.php`

**Interfaces:**
- Produces: `cozumel_render_inquiry_form(string $property_name = '')` — called from `front-page.php`, `single-rental-property.php`, `single-forsale-property.php`, and `page-contact.php` (already wired to call this function in Tasks 6 and 7 above)
- Produces: Contact form active at `/contact/`, navigation menu linking all pages, footer with address/email/social

No third-party plugin — per project preference to avoid WordPress plugins where a small amount of custom PHP does the job (fewer moving parts, no plugin-vulnerability surface). This uses only WordPress core APIs (`admin-post.php`, `wp_mail()`, nonces).

---

- [ ] **Step 1: Create `inc/inquiry-form.php`**

  Full content of `theme/cozumel-homes/inc/inquiry-form.php`:
  ```php
  <?php
  function cozumel_render_inquiry_form($property_name = '') {
      if (isset($_GET['inquiry']) && $_GET['inquiry'] === 'sent') {
          echo '<p style="color:#2a6fa8;font-weight:600">Thanks — your message has been sent. We\'ll get back to you soon.</p>';
      } elseif (isset($_GET['inquiry']) && $_GET['inquiry'] === 'error') {
          echo '<p style="color:#b23b3b;font-weight:600">Something went wrong sending your message. Please try again or email us directly at home@cozumelhomes.net.</p>';
      }
      ?>
      <form class="inquiry-form" method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>">
          <input type="hidden" name="action" value="cozumel_inquiry">
          <?php wp_nonce_field('cozumel_inquiry', 'cozumel_inquiry_nonce'); ?>
          <input type="hidden" name="redirect_to" value="<?php echo esc_url(get_permalink() ?: home_url('/')); ?>">
          <p style="position:absolute;left:-9999px" aria-hidden="true">
              <label>Leave this field empty<input type="text" name="website" tabindex="-1" autocomplete="off"></label>
          </p>
          <p><label>Your Name<br><input type="text" name="your_name" required></label></p>
          <p><label>Email Address<br><input type="email" name="your_email" required></label></p>
          <p><label>Phone Number<br><input type="tel" name="your_phone"></label></p>
          <p><label>Property of Interest<br><input type="text" name="property_name" value="<?php echo esc_attr($property_name); ?>"></label></p>
          <p><label>Preferred Check-in Date<br><input type="date" name="checkin_date"></label></p>
          <p><label>Preferred Check-out Date<br><input type="date" name="checkout_date"></label></p>
          <p><label>Number of Guests<br><input type="number" name="guests" min="1" max="10"></label></p>
          <p><label>Message<br><textarea name="your_message" rows="5"></textarea></label></p>
          <p><button type="submit" class="btn btn--primary">Send Inquiry</button></p>
      </form>
      <?php
  }

  function cozumel_handle_inquiry_submission() {
      $redirect_to = !empty($_POST['redirect_to']) ? esc_url_raw($_POST['redirect_to']) : home_url('/');

      if (!isset($_POST['cozumel_inquiry_nonce']) || !wp_verify_nonce($_POST['cozumel_inquiry_nonce'], 'cozumel_inquiry')) {
          wp_safe_redirect(add_query_arg('inquiry', 'error', $redirect_to));
          exit;
      }

      // Honeypot: bots fill every field, humans never see this one. Silently
      // pretend success so bots don't learn to leave it blank.
      if (!empty($_POST['website'])) {
          wp_safe_redirect(add_query_arg('inquiry', 'sent', $redirect_to));
          exit;
      }

      $name = sanitize_text_field($_POST['your_name'] ?? '');
      $email = sanitize_email($_POST['your_email'] ?? '');

      if (empty($name) || !is_email($email)) {
          wp_safe_redirect(add_query_arg('inquiry', 'error', $redirect_to));
          exit;
      }

      $phone = sanitize_text_field($_POST['your_phone'] ?? '');
      $property_name = sanitize_text_field($_POST['property_name'] ?? '');
      $checkin = sanitize_text_field($_POST['checkin_date'] ?? '');
      $checkout = sanitize_text_field($_POST['checkout_date'] ?? '');
      $guests = sanitize_text_field($_POST['guests'] ?? '');
      $message = sanitize_textarea_field($_POST['your_message'] ?? '');

      $subject = sprintf('New Inquiry from %s — %s', $name, $property_name ?: 'General');
      $body = "Name: $name\nEmail: $email\nPhone: $phone\nProperty: $property_name\n" .
              "Check-in: $checkin\nCheck-out: $checkout\nGuests: $guests\n\nMessage:\n$message\n";

      $sent = wp_mail('home@cozumelhomes.net', $subject, $body, ['Reply-To: ' . $name . ' <' . $email . '>']);

      wp_safe_redirect(add_query_arg('inquiry', $sent ? 'sent' : 'error', $redirect_to));
      exit;
  }
  add_action('admin_post_cozumel_inquiry', 'cozumel_handle_inquiry_submission');
  add_action('admin_post_nopriv_cozumel_inquiry', 'cozumel_handle_inquiry_submission');
  ```

- [ ] **Step 2: Create `page-contact.php`**

  ```php
  <?php
  /* Template Name: Contact */
  get_header(); ?>
  <main class="section" style="max-width:960px;margin:0 auto;padding:48px 24px">
      <h1 style="font-family:Georgia,serif">Contact Us</h1>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:48px;margin-top:32px">
          <div>
              <h3>Kelley Morgan Gonzalez</h3>
              <p>Property Manager &amp; Real Estate Agent<br>Cozumel, Quintana Roo, Mexico</p>
              <p>
                  <strong>Email:</strong><br>
                  <a href="mailto:home@cozumelhomes.net">home@cozumelhomes.net</a>
              </p>
              <p>
                  <strong>Address:</strong><br>
                  Avenida Rafael Melgar #602, Suite PA-6<br>
                  Cozumel, Quintana Roo, Mexico 77600
              </p>
              <p>
                  <a href="https://www.facebook.com/CozumelRentalHomes/" target="_blank" rel="noopener">Facebook</a>
                  &nbsp;·&nbsp;
                  <a href="https://mx.linkedin.com/in/kelley-morgan-gonzalez-89344666" target="_blank" rel="noopener">LinkedIn</a>
              </p>
          </div>
          <div>
              <?php cozumel_render_inquiry_form(); ?>
          </div>
      </div>
  </main>
  <?php get_footer(); ?>
  ```

- [ ] **Step 3: Create WordPress pages and navigation**

  In wp-admin → Pages → Add New, create:
  - "Home" (already exists from Task 7 — skip if done)
  - "Rentals" — content empty (archive-rental-property.php handles it)
  - "For Sale" — content empty (archive-forsale-property.php handles it)
  - "Contact" — set template to "Contact" (from Template dropdown in editor sidebar)

  In wp-admin → Appearance → Menus → Create Menu named "Primary" → add pages: Home, Rentals, For Sale, Contact → Assign to "Primary Menu" location → Save.

- [ ] **Step 4: Add footer via GeneratePress customizer**

  In wp-admin → Appearance → Customize → Footer → add footer widgets or footer bar with:
  - Address: Avenida Rafael Melgar #602, Suite PA-6, Cozumel, Mexico
  - Email: home@cozumelhomes.net
  - Links: Facebook, LinkedIn

  Alternatively, override `footer.php` in the child theme to use a custom footer (simpler and version-controlled):

  Create `theme/cozumel-homes/footer.php`:
  ```php
  <?php wp_footer(); ?>
  </div><!-- .site-content -->
  <footer class="site-footer">
      <p class="site-footer__address">Avenida Rafael Melgar #602, Suite PA-6, Cozumel, Quintana Roo, Mexico 77600</p>
      <p class="site-footer__email"><a href="mailto:home@cozumelhomes.net">home@cozumelhomes.net</a></p>
      <p>
          <a href="https://www.facebook.com/CozumelRentalHomes/" target="_blank" rel="noopener">Facebook</a>
          &nbsp;·&nbsp;
          <a href="https://mx.linkedin.com/in/kelley-morgan-gonzalez-89344666" target="_blank" rel="noopener">LinkedIn</a>
      </p>
      <p style="font-size:0.8rem;opacity:0.6">&copy; <?php echo date('Y'); ?> Cozumel Homes. All rights reserved.</p>
  </footer>
  </body>
  </html>
  ```

- [ ] **Step 5: Verify**

  Visit `http://cozumel-homes.local/contact/` — contact page with form and info renders.
  Submit the form with a test message — confirm email arrives at `home@cozumelhomes.net` (Local uses a mail catcher — check Mailhog at `http://cozumel-homes.local:8025` or configure Local's outgoing mail). Confirm the page redirects back with the "Thanks — your message has been sent" notice.
  Submit again leaving Your Name blank — confirm it redirects with the error notice and no email is sent.
  Verify navigation shows Home, Rentals, For Sale, Contact.
  Verify footer shows on all pages.
  Verify the inquiry form also renders correctly on a rental property page, a for-sale property page, and the home page (all three call `cozumel_render_inquiry_form()` from Tasks 6 and 7).

- [ ] **Step 6: Commit**

  ```bash
  cd ~/Projects/Cozumel-Website
  git add theme/cozumel-homes/inc/inquiry-form.php \
           theme/cozumel-homes/page-contact.php \
           theme/cozumel-homes/footer.php \
           theme/cozumel-homes/single-rental-property.php \
           theme/cozumel-homes/single-forsale-property.php \
           theme/cozumel-homes/front-page.php
  git commit -m "feat: add custom inquiry form, contact page, navigation and footer"
  git push
  ```

---

### Task 9: Property Content Entry

**Files:** None — all data entered via WordPress admin UI.

**Interfaces:**
- Produces: All 4 properties live on the site with full content, photos (or placeholders), coordinates, and all meta fields populated

---

- [ ] **Step 1: Enter Cool Caribbean Views**

  wp-admin → Rental Properties → Add New:

  - **Title:** Cozumel's Cool Caribbean Views
  - **Body (editor):**
    ```
    ## About This Property

    A beautiful blend of classic colonial style and modern elegance — this studio oceanfront condo offers breathtaking Caribbean vistas from its balconies, along with street-side views of Cozumel's famous Carnivale celebrations. Located downtown, steps from restaurants, shops, the ferry pier, and world-class diving.

    ## Amenities

    - Wireless internet · Air conditioning · Ceiling fans
    - Kitchenette: microwave, refrigerator, coffee machine, blender, toaster, cooking utensils, water purifier
    - Bed linens and towels · Blow dryer · First aid kit · Safe
    - Housekeeper service included
    - Pet-friendly (by prior arrangement)

    ## House Rules

    - Check-in: 1:00 PM · Check-out: 11:00 AM
    - No smoking · Children welcome · Pets by arrangement
    - Credit cards accepted
    ```
  - **Featured Image:** Upload a photo of the property
  - **Meta fields:**
    - mac_id: `prop-001`
    - neighborhood: `Downtown`
    - address: `Avenida Rafael E. Melgar #602, Edificio Colon, Apt 6-PA`
    - base_rate: `250`
    - status: `active`
    - max_guests: `2`
    - bedrooms: `1`
    - bathrooms: `1`
    - latitude: `20.5101`
    - longitude: `-86.9468`
    - airbnb_ical_url: *(get from Airbnb → Manage Listing → Availability → Export Calendar)*
    - airbnb_listing_url: *(Airbnb listing URL)*
  - **Publish**

- [ ] **Step 2: Enter Casa Bohemia**

  - **Title:** Cozumel's Casa Bohemia
  - **Body:**
    ```
    ## About This Property

    A recently renovated, bright and airy townhome just two blocks from the oceanfront in the Corpus Christi neighborhood. Perfect for families, groups, athletes, or anyone seeking a comfortable home base for exploring Cozumel's diving, snorkeling, and island life.

    ## Amenities

    - Individual mini-split AC per room · Ceiling fans · Wireless internet
    - Full kitchen: stove, oven, microwave, refrigerator, blender, coffee machine, toaster, cooking utensils, water purifier, spices
    - Washing machine · Clothes dryer · Iron and board · Blow dryer
    - Private patio · Private garden · 2 dedicated parking spaces
    - Housekeeper included · Safe · Lockbox · 24/7 access

    ## House Rules

    - Check-in: 1:00 PM · Check-out: 11:00 AM
    - No smoking · Children welcome · Pets by arrangement
    - Credit cards accepted
    ```
  - **Meta fields:**
    - mac_id: `prop-002`
    - neighborhood: `Corpus Christi`
    - address: `10 Avenida Sur #849`
    - base_rate: `180`
    - status: `active`
    - max_guests: `8`
    - bedrooms: `3`
    - bathrooms: `2`
    - latitude: `20.5072`
    - longitude: `-86.9529`
    - airbnb_ical_url: *(get from Airbnb)*
    - airbnb_listing_url: *(Airbnb listing URL)*
  - **Publish**

- [ ] **Step 3: Enter Nah Ha Condominium 101**

  - **Title:** Cozumel's Nah Ha Condominium 101
  - **Body:**
    ```
    ## About This Property

    A ground-floor oceanfront unit on Cozumel's beautiful north shore — every room frames a Caribbean view. Features a 60-foot infinity pool, jacuzzi, direct beach access, and shaded lounge areas. The stainless steel kitchen with granite countertops, a doorman, and elevator make this a truly premium experience. Wheelchair accessible and suitable for guests with limited mobility.

    ## Amenities

    - Wireless internet · Satellite TV · Central air conditioning
    - Full kitchen: stainless steel appliances, granite countertops, dishwasher, oven, microwave, grill, complete cookware
    - Doorman · 24/7 access · Elevator · Parking · Housekeeper included
    - Infinity pool · Jacuzzi · Beach chairs · Beach entry
    - Snorkeling equipment · Stereo system · Safe · First aid kit
    - Laundry facilities · Wheelchair accessible

    ## House Rules

    - Check-in: 2:00 PM · Check-out: 8:00 PM
    - No smoking · Children welcome · Pets by arrangement
    - Wheelchair accessible · Suitable for seniors
    - Credit cards accepted
    ```
  - **Meta fields:**
    - mac_id: `prop-003`
    - neighborhood: `North Shore`
    - address: `North Shore Highway Km 3.3`
    - base_rate: `425`
    - status: `active`
    - max_guests: `8`
    - bedrooms: `3`
    - bathrooms: `3.5`
    - latitude: `20.5280`
    - longitude: `-86.9811`
    - airbnb_ical_url: *(get from Airbnb)*
    - airbnb_listing_url: *(Airbnb listing URL)*
  - **Publish**

- [ ] **Step 4: Enter the For Sale property**

  wp-admin → For Sale Properties → Add New:

  - **Title:** Cozumel House for Sale
  - **Body:**
    ```
    ## One of Cozumel's Most Private Properties

    This exceptional two-story tropical residence sits on 888 m² (9,558 ft²) of lush garden in the residential Colonia Independencia neighborhood — 7 blocks from the waterfront, 2 blocks from the Sports Complex and Gardner School.

    ## Key Features

    - 4 bedrooms · 3 full bathrooms
    - 2 living areas with palapa seating
    - Large saltwater pool with waterfall
    - Master bedroom: palapa roof, garden patio view, soaking tub with skylight
    - Wheelchair-accessible downstairs bedroom / office
    - 2-car covered garage
    - 3 palapas · Stonework landscaping · Multiple outdoor dining areas
    - 12-foot perimeter walls for total privacy
    - Cross-ventilation with ceiling fans throughout
    - Laundry room and storage
    - Furnished option available

    **Construction:** 286.94 m² (3,089 ft²) · **Lot:** 888 m² (9,558 ft²)

    Represented by Kelley Morgan Gonzalez — over 20 years of Cozumel real estate experience. Bilingual assistance available. Contact us for showings and more information.
    ```
  - **Meta fields:**
    - mac_id: `550e8400-e29b-41d4-a716-446655440001`
    - asking_price: `550000`
    - listing_url: `https://cozumelhomes.net/en/4134544/cozumel-house-for-sale1`
    - bedrooms: `4`
    - bathrooms: `3`
    - latitude: `20.5012`
    - longitude: `-86.9556`
  - **Publish**

- [ ] **Step 5: Verify the full site**

  - `http://cozumel-homes.local/` — home page shows 3 rental cards and 1 for-sale card
  - `http://cozumel-homes.local/rentals/` — 3 rental property cards
  - `http://cozumel-homes.local/for-sale/` — 1 for-sale card
  - Each individual property page: title, specs, rate/price, description, map (if Google API key is active), Airbnb button (rentals only), inquiry form
  - `http://cozumel-homes.local/contact/` — contact page with form

- [ ] **Step 6: Push final commit**

  There are no code changes in this task — content is in the WordPress database, not in git. No commit needed.

  Document the property coordinates used:
  - Cool Caribbean Views: 20.5101, -86.9468
  - Casa Bohemia: 20.5072, -86.9529
  - Nah Ha Condominium 101: 20.5280, -86.9811
  - Cozumel House for Sale: 20.5012, -86.9556

  *(Note: verify these coordinates on Google Maps before publishing — adjust to exact property locations.)*
