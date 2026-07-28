# WhatsApp + Office Hours Contact Section — Design Spec
Date: 2026-07-28

## Overview
Add a WhatsApp contact channel and office-hours expectation-setting to the Cozumel Homes site (`Cozumel-Website` repo), replacing the LinkedIn link that was removed on 2026-07-27. Kelley confirmed her number can be shown directly (`+52 987 876 0638`, a Vonage VoIP US line forwarded to her Mexican mobile) — no privacy workaround needed. Fernando wants office hours (Mon–Fri, 9am–5pm, Cozumel time) shown alongside the number so visitors don't expect an instant reply outside those hours; this mirrors the reasoning already on file for why the raw number matters ([[website_contact_updates]] memory: publishing a contact channel without expectation-setting invites "immediate reward" thinking).

Kelley will provide a WhatsApp QR code image in a later session — this spec reserves a slot for it but does not implement it now.

## Content
- WhatsApp click-to-chat link target: `https://wa.me/529878760638` (country code + number, digits only — required format for wa.me links, distinct from the human-readable display text)
- Displayed link text: `WhatsApp: +52 987 876 0638`
- Office hours caption: `Mon–Fri, 9am–5pm · Cozumel time` (explicit "Cozumel time" rather than a US-style abbreviation like CST/EST, since Quintana Roo is fixed UTC-5 year-round with no DST and the phrasing needs to be unambiguous to international visitors)

## Placement
Both locations LinkedIn was removed from, matching that precedent:
1. **Footer** (`footer.php`) — site-wide
2. **Contact page** (`page-contact.php`) — full detail, grouped with Email in the left info column

## Footer changes (`footer.php`)
New paragraph between the existing email line and the Facebook link:
```php
<p class="site-footer__whatsapp">
    <a href="https://wa.me/529878760638" target="_blank" rel="noopener">WhatsApp: +52 987 876 0638</a><br>
    <span class="site-footer__hours">Mon–Fri, 9am–5pm · Cozumel time</span>
</p>
```
No layout changes needed — `.site-footer` is already a centered, stacked single-column layout at all viewport widths, so it's inherently mobile-first already.

New CSS in `theme.css`, next to the existing `.site-footer__*` rules:
```css
.site-footer__whatsapp { margin: 0 0 16px; }
.site-footer__whatsapp a { color: var(--color-turquoise); font-weight: 600; }
.site-footer__hours { font-size: 0.85rem; opacity: 0.75; }
```
The WhatsApp link uses `--color-turquoise` rather than the plain `--color-sand` used for the email/Facebook links — a deliberate small distinction signaling this is the "instant response" channel, using an existing trust-palette token rather than introducing WhatsApp's own brand green.

## Contact page changes (`page-contact.php`)

### Mobile-first grid fix (in-scope, not scope creep)
The page currently uses an inline `style="display:grid;grid-template-columns:1fr 1fr;gap:48px"` with **no mobile breakpoint** — on phones this squeezes the info column (where the new WhatsApp block lives) and the inquiry form into two cramped columns. Since the new content is being added directly into that column, this is fixed as part of this work:

Replace the inline style with a class:
```html
<div class="contact-grid" style="margin-top:32px">
```
New CSS in `theme.css`, mobile-first (base = single column, promoted to two columns at `min-width: 641px`, matching the breakpoint already used for `.properties-grid`):
```css
.contact-grid { display: grid; grid-template-columns: 1fr; gap: 48px; }
@media (min-width: 641px) {
    .contact-grid { grid-template-columns: 1fr 1fr; }
}
```

### New WhatsApp block
Inserted between the existing Email and Address blocks (grouping the two direct-contact methods together, ahead of the static mailing address):
```php
<div class="contact-whatsapp">
    <p>
        <strong>WhatsApp:</strong><br>
        <a href="https://wa.me/529878760638" target="_blank" rel="noopener">+52 987 876 0638</a><br>
        <span style="font-size:0.85rem;color:var(--color-muted)">Mon–Fri, 9am–5pm &middot; Cozumel time</span>
    </p>
    <!-- TODO: Kelley's WhatsApp QR code image goes here once provided -->
</div>
```
The wrapping `.contact-whatsapp` div gives Kelley's future QR code image a slot to drop into (e.g. as a sibling `<img>` inside the div) without restructuring the surrounding page.

## Out of scope
- Kelley's WhatsApp QR code image — placeholder comment only, added in a follow-up once she provides it
- Any broader footer/header visual redesign to match the navy/turquoise/gold palette (flagged as an open thread in the hero redesign session, not part of this task)
- Any other mobile-responsiveness gaps on the contact page or elsewhere in the theme beyond the one grid fix directly affecting this new content
