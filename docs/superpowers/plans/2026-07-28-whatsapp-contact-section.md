# WhatsApp + Office Hours Contact Section Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a WhatsApp click-to-chat link and Mon–Fri 9am–5pm office-hours caption to the Cozumel Homes site footer and contact page, and fix a pre-existing mobile-layout gap in the contact page's info/form grid that would otherwise squeeze the new content on phones.

**Architecture:** Plain PHP/HTML template edits (`footer.php`, `page-contact.php`) plus corresponding CSS additions in the theme's single stylesheet (`theme.css`). No build step, no JS, no test framework in this repo — verification is via `curl`-ing the rendered pages against the local WordPress dev site (`cozumel-homes.local`) and grepping for expected output, matching how prior sessions verified theme changes in this codebase.

**Tech Stack:** WordPress PHP theme (`cozumel-homes`), plain CSS custom properties (no preprocessor), Local by Flywheel dev site at `http://cozumel-homes.local`.

## Global Constraints
- WhatsApp link target: `https://wa.me/529878760638` (digits only — country code + number, no spaces/plus)
- Displayed text: `WhatsApp: +52 987 876 0638`
- Office hours text (exact, both locations): `Mon&ndash;Fri, 9am&ndash;5pm &middot; Cozumel time` (HTML entities, matching `footer.php`'s existing `&copy;` convention — never raw UTF-8 dash/middot characters in the PHP files)
- Repo root: `/Users/fernandogonzalez/Projects/Cozumel-Website`
- Theme root: `theme/cozumel-homes/` (relative to repo root)
- Dev site base URL for verification: `http://cozumel-homes.local`
- Spec: `docs/superpowers/specs/2026-07-28-whatsapp-contact-design.md` (in this repo, `Cozumel_App_Final` — cross-repo spec/plan convention already used for prior website work)

---

### Task 1: Footer WhatsApp link + office hours

**Files:**
- Modify: `theme/cozumel-homes/footer.php:5` (insert new paragraph after the existing email line)
- Modify: `theme/cozumel-homes/assets/css/theme.css:263` (insert new rules after `.site-footer__email`)

**Interfaces:**
- Produces: `.site-footer__whatsapp` and `.site-footer__hours` CSS classes, used only by this task's `footer.php` markup.

- [ ] **Step 1: Add the new CSS rules**

In `theme/cozumel-homes/assets/css/theme.css`, immediately after this existing line (currently line 263):
```css
.site-footer__email { margin: 0 0 16px; }
```
add:
```css
.site-footer__whatsapp { margin: 0 0 16px; }
.site-footer__whatsapp a { color: var(--color-turquoise); font-weight: 600; }
.site-footer__hours { font-size: 0.85rem; opacity: 0.75; }
```

- [ ] **Step 2: Add the new footer markup**

In `theme/cozumel-homes/footer.php`, the current content is:
```php
<?php wp_footer(); ?>
</div><!-- .site-content -->
<footer class="site-footer">
    <p class="site-footer__address">Avenida Rafael Melgar #602, Suite PA-6, Cozumel, Quintana Roo, Mexico 77600</p>
    <p class="site-footer__email"><a href="mailto:home@cozumelhomes.net">home@cozumelhomes.net</a></p>
    <p>
        <a href="https://www.facebook.com/CozumelRentalHomes/" target="_blank" rel="noopener">Facebook</a>
    </p>
    <p style="font-size:0.8rem;opacity:0.6">&copy; <?php echo date('Y'); ?> Cozumel Homes. All rights reserved.</p>
</footer>
</body>
</html>
```
Replace it with:
```php
<?php wp_footer(); ?>
</div><!-- .site-content -->
<footer class="site-footer">
    <p class="site-footer__address">Avenida Rafael Melgar #602, Suite PA-6, Cozumel, Quintana Roo, Mexico 77600</p>
    <p class="site-footer__email"><a href="mailto:home@cozumelhomes.net">home@cozumelhomes.net</a></p>
    <p class="site-footer__whatsapp">
        <a href="https://wa.me/529878760638" target="_blank" rel="noopener">WhatsApp: +52 987 876 0638</a><br>
        <span class="site-footer__hours">Mon&ndash;Fri, 9am&ndash;5pm &middot; Cozumel time</span>
    </p>
    <p>
        <a href="https://www.facebook.com/CozumelRentalHomes/" target="_blank" rel="noopener">Facebook</a>
    </p>
    <p style="font-size:0.8rem;opacity:0.6">&copy; <?php echo date('Y'); ?> Cozumel Homes. All rights reserved.</p>
</footer>
</body>
</html>
```

- [ ] **Step 3: Verify the footer renders correctly**

Run:
```bash
curl -s "http://cozumel-homes.local/" | grep -o 'wa.me/529878760638\|WhatsApp: +52 987 876 0638\|Mon&ndash;Fri, 9am&ndash;5pm &middot; Cozumel time\|site-footer__whatsapp'
```
Expected: all four strings printed (order may vary), confirming the link, display text, hours caption, and CSS class all made it into the rendered homepage footer.

- [ ] **Step 4: Verify the CSS rules are present**

Run:
```bash
grep -n "site-footer__whatsapp\|site-footer__hours" theme/cozumel-homes/assets/css/theme.css
```
Expected: 3 lines printed — the `.site-footer__whatsapp` rule, its `a` descendant rule, and the `.site-footer__hours` rule.

- [ ] **Step 5: Commit**

```bash
git add theme/cozumel-homes/footer.php theme/cozumel-homes/assets/css/theme.css
git commit -m "feat: add WhatsApp link and office hours to site footer"
```

---

### Task 2: Contact page mobile-first grid fix

**Files:**
- Modify: `theme/cozumel-homes/page-contact.php:6` (replace inline grid style with a class)
- Modify: `theme/cozumel-homes/assets/css/theme.css` (add `.contact-grid` rules)

**Interfaces:**
- Produces: `.contact-grid` CSS class, consumed by this task's `page-contact.php` change and by Task 3's new content (which lives inside the same grid).

**Why this is in scope:** `page-contact.php` currently hardcodes `style="display:grid;grid-template-columns:1fr 1fr;gap:48px;margin-top:32px"` with no mobile breakpoint at all. Task 3 adds new content into the left column of this grid, so on a phone that column (and the new WhatsApp block inside it) would be squeezed into half-width alongside the inquiry form. Fixing this here, before Task 3 lands new content into it, avoids ever having broken mobile layout in the working tree.

- [ ] **Step 1: Add the mobile-first `.contact-grid` CSS**

In `theme/cozumel-homes/assets/css/theme.css`, immediately after this existing block:
```css
@media (max-width: 640px) {
    .properties-grid { grid-template-columns: 1fr; }
}
```
add:
```css
.contact-grid { display: grid; grid-template-columns: 1fr; gap: 48px; }
@media (min-width: 641px) {
    .contact-grid { grid-template-columns: 1fr 1fr; }
}
```
This is mobile-first: the base (unqualified) rule is the single-column phone layout, and the `min-width` query promotes to two columns only on wider screens — never the other way around.

- [ ] **Step 2: Swap the inline style for the new class**

In `theme/cozumel-homes/page-contact.php`, the current line is:
```php
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:48px;margin-top:32px">
```
Replace it with:
```php
    <div class="contact-grid" style="margin-top:32px">
```
(`margin-top` stays inline since it's page-specific spacing, not part of the reusable grid layout rule.)

- [ ] **Step 3: Verify the old inline grid style is gone and the new class is present**

Run:
```bash
curl -s "http://cozumel-homes.local/contact/" | grep -o 'grid-template-columns:1fr 1fr;gap:48px\|contact-grid'
```
Expected: only `contact-grid` printed — the old inline `grid-template-columns:1fr 1fr;gap:48px` string must NOT appear (confirms it moved out of the inline style).

- [ ] **Step 4: Verify the CSS rules are present and mobile-first**

Run:
```bash
grep -n "contact-grid" theme/cozumel-homes/assets/css/theme.css
```
Expected: 3 lines — the base `.contact-grid` rule (grid-template-columns: 1fr), the `@media (min-width: 641px)` line, and the two-column override inside it. Confirm the base rule (1 column) appears BEFORE the `@media (min-width: 641px)` block in the file — if the media query came first, the base rule would win the cascade and desktop would incorrectly stay single-column.

- [ ] **Step 5: Commit**

```bash
git add theme/cozumel-homes/page-contact.php theme/cozumel-homes/assets/css/theme.css
git commit -m "fix: make contact page info/form grid mobile-first"
```

---

### Task 3: Contact page WhatsApp block with QR code slot

**Files:**
- Modify: `theme/cozumel-homes/page-contact.php` (insert new WhatsApp block between the existing Email and Address blocks)

**Interfaces:**
- Consumes: `.contact-grid` class from Task 2 (this task's new content lives inside that grid's left column, so it inherits Task 2's mobile-first single-column-then-two-column behavior automatically).

- [ ] **Step 1: Insert the WhatsApp block**

In `theme/cozumel-homes/page-contact.php`, the current left-column content (after Task 2's grid-class change) is:
```php
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
            </p>
        </div>
```
Replace it with:
```php
        <div>
            <h3>Kelley Morgan Gonzalez</h3>
            <p>Property Manager &amp; Real Estate Agent<br>Cozumel, Quintana Roo, Mexico</p>
            <p>
                <strong>Email:</strong><br>
                <a href="mailto:home@cozumelhomes.net">home@cozumelhomes.net</a>
            </p>
            <div class="contact-whatsapp">
                <p>
                    <strong>WhatsApp:</strong><br>
                    <a href="https://wa.me/529878760638" target="_blank" rel="noopener">+52 987 876 0638</a><br>
                    <span style="font-size:0.85rem;color:var(--color-muted)">Mon&ndash;Fri, 9am&ndash;5pm &middot; Cozumel time</span>
                </p>
                <!-- TODO: Kelley's WhatsApp QR code image goes here once provided -->
            </div>
            <p>
                <strong>Address:</strong><br>
                Avenida Rafael Melgar #602, Suite PA-6<br>
                Cozumel, Quintana Roo, Mexico 77600
            </p>
            <p>
                <a href="https://www.facebook.com/CozumelRentalHomes/" target="_blank" rel="noopener">Facebook</a>
            </p>
        </div>
```

- [ ] **Step 2: Verify the contact page renders the new block**

Run:
```bash
curl -s "http://cozumel-homes.local/contact/" | grep -o 'wa.me/529878760638\|+52 987 876 0638\|Mon&ndash;Fri, 9am&ndash;5pm &middot; Cozumel time\|contact-whatsapp\|Kelley.s WhatsApp QR code'
```
Expected: all five strings printed, confirming the link, display number, hours caption, wrapping class, and QR placeholder comment are all present. (The placeholder HTML comment is stripped from output by some setups — if it doesn't appear, confirm instead via `grep -n "QR code" theme/cozumel-homes/page-contact.php` directly against the source file.)

- [ ] **Step 3: Verify placement — WhatsApp appears between Email and Address**

Run:
```bash
curl -s "http://cozumel-homes.local/contact/" | grep -o 'Email:\|WhatsApp:\|Address:' 
```
Expected: printed in the order `Email:`, `WhatsApp:`, `Address:` — confirms the new block is grouped with Email ahead of the static mailing address, as specified.

- [ ] **Step 4: Commit**

```bash
git add theme/cozumel-homes/page-contact.php
git commit -m "feat: add WhatsApp contact block to contact page"
```

---

### Task 4: Full manual visual verification

**Files:** None (verification only).

- [ ] **Step 1: Verify homepage footer in a real browser at mobile and desktop widths**

Using the Node/Puppeteer setup already installed from the hero-redesign session (`puppeteer-core` driving the local Brave Browser — see that session's notes on why this is preferred over raw CLI screenshot flags for reliable viewport sizing), load `http://cozumel-homes.local/` at both a narrow viewport (e.g. 375×812, iPhone-sized) and a desktop viewport (e.g. 1440×900). Confirm:
- The WhatsApp line and office-hours caption appear in the footer at both widths, stacked centered like the other footer lines (no overlap or clipping).
- The WhatsApp link is visually distinguished (turquoise) from the plain sand-colored email/Facebook links.

- [ ] **Step 2: Verify the contact page grid collapses correctly on mobile**

At the narrow viewport, confirm the info column (name/email/WhatsApp/address/Facebook) and the inquiry form stack in a single column, full-width, in that order — not squeezed side-by-side. At the desktop viewport, confirm they sit side-by-side as two columns, matching the page's layout before this change.

- [ ] **Step 3: Click the WhatsApp link**

Confirm `https://wa.me/529878760638` is the link target in both the footer and contact-page instances (e.g. via the browser's hover/status-bar or an `evaluate()` call reading `.getAttribute('href')`), and that it's not silently pointing at a placeholder or malformed URL.

- [ ] **Step 4: Report results to Fernando**

Summarize what was checked and confirm no regressions to the rest of the footer or contact page (Facebook link, copyright line, inquiry form still present and functional).
