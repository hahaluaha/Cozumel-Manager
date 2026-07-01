# Companion Website — Design Spec
Date: 2026-07-01

## Overview
A public-facing WordPress website for Cozumel Homes (cozumelhomes.net), replacing the current Lodgify-hosted site. Displays all rental and for-sale properties, syncs content automatically from the Mac app, shows Airbnb availability calendars, and accepts direct bookings with Stripe payment. Kelley and Fernando handle all website maintenance — Kelley touches only Airbnb for bookings.

## Separate Project
This is a standalone project independent from the Mac app repo. It will live in its own repository when implementation begins.

## Development Environment
- **Local WordPress:** Local by Flywheel (Mac app, free) — runs WordPress locally for development and testing
- **IDE:** Antigravity IDE and/or PyCharm (PyCharm for the Python sync daemon)
- **Deployment:** Hostinger entry-level VPS (to be provisioned when site is ready) — nginx + SSL (Let's Encrypt), UFW firewall, fail2ban, SSH key-only access

## Tech Stack
- **CMS:** WordPress (self-hosted)
- **Theme:** GeneratePress (lightweight base) + custom child theme
- **Booking plugin:** MotoPress Hotel Booking (~$99/year) — handles availability calendar, two-way iCal sync, Stripe checkout, email confirmations
- **Payment:** Stripe (~2.9% + $0.30/transaction)
- **Maps:** Google Maps (primary), swappable to Apple MapKit JS or Leaflet via single theme setting
- **Sync daemon:** Python 3 + `watchdog` library, runs as macOS launchd service on Kelley's Mac
- **Contact forms:** Contact Form 7 (free WordPress plugin)

---

## Part 1: WordPress Data Model

### Custom Post Type: `rental-property`
Maps from Mac app `Property` model. Fields managed by Python sync (never edited manually in WordPress):

| WordPress field | Mac app field | Notes |
|---|---|---|
| Post title | `name` | |
| `mac_id` | `id` (String) | Sync key — never overwritten manually |
| `neighborhood` | `neighborhood` | |
| `address` | `address` | |
| `base_rate` | `baseRate` (Double) | USD nightly rate |
| `status` | `status` | active / inactive / maintenance |
| Featured media | `photos` ([URL]) | Uploaded on first sync, new photos added incrementally |

Fields set once manually in WordPress (never touched by sync):

| Field | Purpose |
|---|---|
| `latitude` | For Google Map embed |
| `longitude` | For Google Map embed |
| `airbnb_ical_url` | Airbnb export iCal URL for this listing |
| `airbnb_listing_url` | Link to Airbnb listing page |
| Full description | Rich text — from Lodgify content (entered once) |
| Amenities list | From Lodgify content (entered once) |
| House rules | From Lodgify content (entered once) |

### Custom Post Type: `forsale-property`
Maps from Mac app `ForSaleProperty` model. Fields managed by Python sync:

| WordPress field | Mac app field | Notes |
|---|---|---|
| Post title | `name` | |
| `mac_id` | `id` (UUID String) | Sync key |
| `description` | `description` | |
| `asking_price` | `askingPrice` (Double) | USD |
| `listing_url` | `listingURL` | External listing link |
| `notes` | `notes` | Internal only — not displayed publicly |
| Featured media | `photos` ([URL]) | Uploaded on first sync |

Fields set once manually:

| Field | Purpose |
|---|---|
| `latitude` / `longitude` | For Google Map embed |
| Full property details | Rich text (from existing Lodgify listing) |

### Seed Content (4 Properties)

**Cool Caribbean Views** — 1BD/1BA, 2 guests, downtown oceanfront, Carnivale balcony views, $250/night
**Casa Bohemia** — 3BD/2BA, 8 guests, Corpus Christi townhome, private garden, 2 parking spaces, $180/night
**Nah Ha Condominium 101** — 3BD/3.5BA, 8 guests, North Shore oceanfront, infinity pool, jacuzzi, beach access, $425/night
**Cozumel House for Sale** — 4BD/3BA, $550,000 USD, Colonia Independencia, saltwater pool, 888m² garden, palapa roof, wheelchair accessible

---

## Part 2: Python Sync Daemon

### Purpose
Watches the Mac app's JSON data files for changes and automatically pushes updates to WordPress via REST API. Runs silently as a background service on Kelley's Mac. Kelley never interacts with it.

### File Watching
Uses the Python `watchdog` library to monitor:
- `~/Library/Application Support/CozumelManager/properties.json`
- `~/Library/Application Support/CozumelManager/forSaleProperties.json`

On any file change event, the daemon wakes, reads the updated JSON, and syncs to WordPress.

### Sync Logic
- **Match key:** `mac_id` custom field in WordPress — used to find the existing post for each property
- **Upsert:** If a post with matching `mac_id` exists → update. If not → create new post.
- **Delete:** If a property present in the last snapshot is missing from the new JSON → set the WordPress post to Draft (not permanent delete, for safety)
- **Status:** If a rental property's `status` is `inactive` or `maintenance` → set the WordPress post to Draft (hidden from public). If status returns to `active` → restore to Published.
- **Photos:** On first sync, upload all photos to WordPress Media Library. On subsequent syncs, compare by filename — only upload new photos. Never re-upload existing ones.
- **Ignored fields:** `latitude`, `longitude`, `airbnb_ical_url`, `airbnb_listing_url`, `description` (rich text), `amenities`, `house rules` — sync never overwrites these; they are managed manually in WordPress

### Auth
WordPress Application Password stored in `~/.cozumel-sync/config.json` (never in the repo):
```json
{
  "wordpress_url": "https://cozumelhomes.net",
  "username": "admin",
  "app_password": "xxxx xxxx xxxx xxxx"
}
```

### launchd Service
A `.plist` file at `~/Library/LaunchAgents/net.cozumelhomes.sync.plist` starts the daemon on login and restarts it if it crashes. Kelley never sees it running.

### Project structure
```
cozumel-sync/
├── sync.py              # Main daemon
├── watcher.py           # watchdog file watcher
├── wordpress.py         # WordPress REST API client
├── config.py            # Loads ~/.cozumel-sync/config.json
├── requirements.txt     # watchdog, requests
└── net.cozumelhomes.sync.plist  # launchd plist template
```

---

## Part 3: Public Website

### Pages

**Home (`/`)**
- Hero: full-width Cozumel ocean photo, site name, tagline
- Kelley's intro (bio carried from current site — 20+ years experience, bilingual, boutique service)
- Rental properties grid (3 cards)
- For Sale section (1 card)
- Testimonials (3 existing reviews from current site)
- Inquiry form at bottom
- Footer: address (Avenida Rafael Melgar #602, Suite PA-6, Cozumel), email (home@cozumelhomes.net), Facebook, LinkedIn

**Rentals (`/rentals/`)**
- Grid of rental property cards: primary photo, name, neighborhood, guest count, beds/baths, nightly rate
- Each card links to individual property page

**For Sale (`/for-sale/`)**
- Grid of for-sale property cards: primary photo, name, asking price, key specs
- Each card links to individual property page

**Individual Rental Property Page (`/rentals/<slug>/`)**
- Full photo gallery
- Description, amenities list, house rules
- Nightly rate + guest/bed/bath count
- Google Map centered on property coordinates
- Availability calendar (MotoPress — two-way iCal synced with Airbnb)
- **"Book Direct & Save"** button → MotoPress Stripe checkout (with direct booking discount shown)
- **"Book on Airbnb"** button → Airbnb listing URL
- Inquiry form for questions

**Individual For Sale Property Page (`/for-sale/<slug>/`)**
- Full photo gallery
- Full property description and features (from existing Lodgify listing)
- Asking price
- Google Map
- "View Listing" link → external listing URL
- Inquiry form
- No booking calendar (for sale, not rental)

**Contact (`/contact/`)**
- Kelley's contact info, address, email
- Facebook + LinkedIn links
- General inquiry form (Contact Form 7 → home@cozumelhomes.net)

### Theme
- Base: GeneratePress child theme
- Colors: white/sand tones, ocean accent
- Typography: clean, readable, luxury feel
- No page builders — clean PHP templates
- Fully responsive (mobile-first)

### Map Integration
- Provider: Google Maps (primary)
- Each property page embeds a map centered on `latitude`/`longitude` custom fields
- Provider swappable via single `COZUMEL_MAP_PROVIDER` theme constant — accepts `'google'`, `'apple'`, `'openstreetmap'`
- Map partial: `template-parts/map.php` — reads the constant and renders the appropriate embed

### Airbnb iCal Sync (MotoPress)
- Each rental property has an `airbnb_ical_url` field (Airbnb export URL — Kelley finds in Airbnb → Manage Listing → Availability → Export Calendar)
- MotoPress imports this feed → shows blocked dates on WordPress calendar
- MotoPress generates its own iCal export URL → imported into Airbnb → blocks direct-booked dates on Airbnb
- Result: two-way sync, no double bookings

### Direct Booking (MotoPress + Stripe)
- MotoPress Hotel Booking plugin handles the full checkout flow
- Guest selects dates → sees total price → pays via Stripe
- Direct booking discount displayed (e.g. "Save 10% vs. Airbnb") — percentage set in MotoPress settings
- Email confirmation sent automatically to guest and to home@cozumelhomes.net
- Booked dates immediately blocked on both WordPress and Airbnb calendars

---

## Implementation Order
This project decomposes into three implementation plans, built in sequence:

1. **Plan A — WordPress setup + theme + property content** — Local by Flywheel install, GeneratePress child theme, CPTs registered, all 4 properties entered, Google Maps on property pages, Contact Form 7
2. **Plan B — Python sync daemon** — watchdog file watcher, WordPress REST API client, launchd service, photos upload
3. **Plan C — MotoPress booking + Stripe + iCal** — MotoPress install and config, Airbnb iCal two-way sync, Stripe account connection, direct booking discount, email confirmations

Each plan is independent enough to be specced and implemented separately.

---

## Future Phases (Out of Scope Now)
- Landing page with local market analysis and targeted calls to action
- Private management dashboard for Kelley (web version of Mac app)
- Server hardening and deployment to Hostinger VPS
- Moving appcast.xml from GitHub raw URL to own domain

## Out of Scope (This Spec)
- Live availability pricing (dynamic pricing based on dates/season)
- Guest messaging or automated responses
- Staff scheduling or task management
- Any feature requiring Kelley to edit WordPress directly
