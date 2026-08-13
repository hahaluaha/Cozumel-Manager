# Content Migration + DNS Cutover Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the real WordPress site (theme + database + media) from
local development onto the already-provisioned production VPS, verify it
renders correctly, then — only after explicit go-ahead — cut DNS over
from the current third-party-hosted site to the VPS.

**Architecture:** WP-CLI database export from local dev, transferred over
the existing hardened SSH key to the VPS, imported into the already-running
empty WordPress install, followed by a serialization-safe domain
search-replace, theme/upload file sync, a fresh WordPress Application
Password for the Mac app's sync feature, and a temporary local `/etc/hosts`
override for visual verification — all before touching the live DNS `A`
records.

**Tech Stack:** WP-CLI (local, via Local by Flywheel's Site Shell; remote,
via WordOps' bundled install), `rsync`/`scp` over SSH key auth,
MySQL/MariaDB.

**Spec:** No separate written spec for this plan — design was proposed and
approved in-chat on 2026-08-13. This plan is a direct continuation of
`docs/superpowers/specs/2026-08-12-vps-setup-design.md` and
`docs/superpowers/plans/2026-08-12-vps-setup.md`, which provisioned the
VPS this migrates onto.

## Global Constraints

- **Never use real names as usernames, labels, or identifiers** in this
  doc, in commit messages, or in any credential created while executing
  it — use generic role labels only ("the operator," "the property
  manager"). Do not paste actual generated passwords/usernames into this
  file, commits, or chat transcripts that get saved to disk.
- DNS cutover (Task 6) requires the operator's **explicit go-ahead** after
  Task 5's verification passes — do not proceed automatically.
- DNS cutover may only change the `A` records for `@` and `www`. `MX`,
  `TXT` (SPF), `NS`, and every other existing record at the registrar must
  remain untouched — the property manager's Google Workspace email must
  keep working uninterrupted.
- Local WordPress site: Local by Flywheel site `cozumel-homes`, files at
  `~/Local Sites/cozumel-homes/app/public`.
- Production VPS: IP `2.25.104.105`, domain `cozumelhomes.net`, WordPress
  at `/var/www/cozumelhomes.net/htdocs`, SSH via
  `~/.ssh/id_ed25519_cozumel_vps` as user `deploy` (passwordless sudo
  already configured).
- Deadline: migration + cutover need to complete by 2026-08-14 — the
  property manager wants to cancel a paid third-party hosting subscription
  before its next billing date on 2026-08-18.
- A full database import overwrites the production WordPress admin
  account with local dev's — intentional, per operator decision.
- The draft blog post already in local dev's database migrates as-is and
  stays unpublished/draft on production — do not publish it as part of
  this plan.

---

### Task 1: Export the local WordPress database

**Files:** none (local Site Shell + a local export file)

**Interfaces:**
- Produces: a SQL dump file at `~/Desktop/cozumel-homes-export.sql`, consumed by Task 3.

This step needs an interactive terminal (Local by Flywheel's Site Shell,
launched from its GUI) — it cannot run through a non-interactive Bash
tool. The operator runs this step directly.

- [ ] **Step 1: Open the Site Shell for the `cozumel-homes` site**

In the Local by Flywheel app: right-click the `cozumel-homes` site →
"Open Site Shell". This opens a terminal with WP-CLI already scoped to
that site.

- [ ] **Step 2: Export the database**

```bash
wp db export ~/Desktop/cozumel-homes-export.sql
```

- [ ] **Step 3: Verify the export file exists and isn't empty**

```bash
ls -lh ~/Desktop/cozumel-homes-export.sql
```
Expected: a file at least tens of KB in size (not 0 bytes).

- [ ] **Step 4: No commit needed** — this only touches a local file outside the git repo.

---

### Task 2: Transfer the database export, theme, and media to the VPS

**Files:** none (data transfer only, using the existing SSH key)

**Interfaces:**
- Consumes: `~/Desktop/cozumel-homes-export.sql` from Task 1.
- Produces: `~/cozumel-homes-export.sql`, `~/cozumel-homes-theme/`,
  `~/generatepress-theme/`, `~/cozumel-homes-uploads/` in the `deploy`
  user's home directory on the VPS — consumed by Task 3.

- [ ] **Step 1: Copy the database export**

```bash
scp -i ~/.ssh/id_ed25519_cozumel_vps ~/Desktop/cozumel-homes-export.sql deploy@2.25.104.105:~/
```

- [ ] **Step 2: Copy the child theme**

```bash
rsync -avz -e "ssh -i ~/.ssh/id_ed25519_cozumel_vps" "$HOME/Local Sites/cozumel-homes/app/public/wp-content/themes/cozumel-homes/" deploy@2.25.104.105:~/cozumel-homes-theme/
```

- [ ] **Step 3: Copy the parent theme (GeneratePress)**

```bash
rsync -avz -e "ssh -i ~/.ssh/id_ed25519_cozumel_vps" "$HOME/Local Sites/cozumel-homes/app/public/wp-content/themes/generatepress/" deploy@2.25.104.105:~/generatepress-theme/
```

- [ ] **Step 4: Copy uploaded media**

```bash
rsync -avz -e "ssh -i ~/.ssh/id_ed25519_cozumel_vps" "$HOME/Local Sites/cozumel-homes/app/public/wp-content/uploads/" deploy@2.25.104.105:~/cozumel-homes-uploads/
```

- [ ] **Step 5: Verify everything landed on the VPS**

```bash
ssh -i ~/.ssh/id_ed25519_cozumel_vps deploy@2.25.104.105 "ls -lh ~/cozumel-homes-export.sql && du -sh ~/cozumel-homes-theme ~/generatepress-theme ~/cozumel-homes-uploads"
```
Expected: the SQL file present, theme directories non-empty, uploads
directory roughly matching the local size (~100M).

---

### Task 3: Import the database and move files into place on production

**Files (remote):**
- `/var/www/cozumelhomes.net/htdocs/wp-content/themes/cozumel-homes/`
- `/var/www/cozumelhomes.net/htdocs/wp-content/themes/generatepress/`
- `/var/www/cozumelhomes.net/htdocs/wp-content/uploads/`

**Interfaces:**
- Consumes: files transferred in Task 2.
- Produces: a production WordPress database and file tree matching local
  dev, still reachable only via IP/Host-header (no DNS change yet) —
  consumed by Task 4.

- [ ] **Step 1: Back up the current (default) production database first**

```bash
ssh -i ~/.ssh/id_ed25519_cozumel_vps deploy@2.25.104.105 "sudo -n wp db export /home/deploy/pre-migration-backup.sql --allow-root --path=/var/www/cozumelhomes.net/htdocs"
```
Expected: no error; gives a rollback point if anything below goes wrong.

- [ ] **Step 2: Import the migrated database**

```bash
ssh -i ~/.ssh/id_ed25519_cozumel_vps deploy@2.25.104.105 "sudo -n wp db import /home/deploy/cozumel-homes-export.sql --allow-root --path=/var/www/cozumelhomes.net/htdocs"
```
Expected: `Success: Imported from '/home/deploy/cozumel-homes-export.sql'.`

- [ ] **Step 3: Move the theme folders into place**

```bash
ssh -i ~/.ssh/id_ed25519_cozumel_vps deploy@2.25.104.105 "sudo -n rsync -a /home/deploy/cozumel-homes-theme/ /var/www/cozumelhomes.net/htdocs/wp-content/themes/cozumel-homes/ && sudo -n rsync -a /home/deploy/generatepress-theme/ /var/www/cozumelhomes.net/htdocs/wp-content/themes/generatepress/"
```

- [ ] **Step 4: Move uploaded media into place**

```bash
ssh -i ~/.ssh/id_ed25519_cozumel_vps deploy@2.25.104.105 "sudo -n rsync -a /home/deploy/cozumel-homes-uploads/ /var/www/cozumelhomes.net/htdocs/wp-content/uploads/"
```

- [ ] **Step 5: Fix file ownership**

```bash
ssh -i ~/.ssh/id_ed25519_cozumel_vps deploy@2.25.104.105 "sudo -n chown -R www-data:www-data /var/www/cozumelhomes.net/htdocs/wp-content/themes/cozumel-homes /var/www/cozumelhomes.net/htdocs/wp-content/themes/generatepress /var/www/cozumelhomes.net/htdocs/wp-content/uploads"
```

- [ ] **Step 6: Activate the migrated theme**

```bash
ssh -i ~/.ssh/id_ed25519_cozumel_vps deploy@2.25.104.105 "sudo -n wp theme activate cozumel-homes --allow-root --path=/var/www/cozumelhomes.net/htdocs"
```

- [ ] **Step 7: Verify the theme is active**

```bash
ssh -i ~/.ssh/id_ed25519_cozumel_vps deploy@2.25.104.105 "sudo -n wp theme list --allow-root --path=/var/www/cozumelhomes.net/htdocs"
```
Expected: `cozumel-homes` shows `status: active`.

---

### Task 4: Fix domain references in the database

**Files:** none (remote database only)

**Interfaces:**
- Consumes: imported database from Task 3.
- Produces: a database with all local-dev URLs rewritten to the production
  domain — consumed by Task 5.

WP-CLI's `search-replace` is serialization-safe (WordPress stores some
options as PHP-serialized arrays; a plain `sed` replace would corrupt
those) — always use it instead of a raw text substitution for WordPress
databases.

- [ ] **Step 1: Replace the scheme+domain form**

```bash
ssh -i ~/.ssh/id_ed25519_cozumel_vps deploy@2.25.104.105 "sudo -n wp search-replace 'http://cozumel-homes.local' 'https://cozumelhomes.net' --all-tables --allow-root --path=/var/www/cozumelhomes.net/htdocs"
```

- [ ] **Step 2: Replace any remaining bare-domain references**

```bash
ssh -i ~/.ssh/id_ed25519_cozumel_vps deploy@2.25.104.105 "sudo -n wp search-replace 'cozumel-homes.local' 'cozumelhomes.net' --all-tables --allow-root --path=/var/www/cozumelhomes.net/htdocs"
```

- [ ] **Step 3: Verify the site URL options updated**

```bash
ssh -i ~/.ssh/id_ed25519_cozumel_vps deploy@2.25.104.105 "sudo -n wp option get siteurl --allow-root --path=/var/www/cozumelhomes.net/htdocs && sudo -n wp option get home --allow-root --path=/var/www/cozumelhomes.net/htdocs"
```
Expected: both print `https://cozumelhomes.net`.

---

### Task 5: Generate a fresh Application Password and verify visually

**Files:** local `/etc/hosts` (temporary edit, must be reverted)

**Interfaces:**
- Consumes: migrated + URL-fixed site from Task 4.
- Produces: a working Application Password for the Mac app's sync feature
  (Task 7), and visual confirmation the migrated site renders correctly
  before DNS cutover (Task 6).

- [ ] **Step 1: List admin-role users to find the username to use**

```bash
ssh -i ~/.ssh/id_ed25519_cozumel_vps deploy@2.25.104.105 "sudo -n wp user list --role=administrator --field=user_login --allow-root --path=/var/www/cozumelhomes.net/htdocs"
```
Note the username directly from this output — do not copy it into this
plan file, a commit, or any other saved doc.

- [ ] **Step 2: Generate a new Application Password for that user**

```bash
ssh -i ~/.ssh/id_ed25519_cozumel_vps deploy@2.25.104.105 "sudo -n wp user application-password create <username-from-step-1> mac-app-sync --allow-root --path=/var/www/cozumelhomes.net/htdocs"
```
This prints the password once. The operator captures it directly (e.g.
into a password manager) — it is not shown again and must not be pasted
into any file this plan writes.

- [ ] **Step 3: Add a temporary hosts override (operator runs this — needs the Mac's own sudo password)**

```bash
echo "2.25.104.105  cozumelhomes.net" | sudo tee -a /etc/hosts
```

- [ ] **Step 4: Load the site in a browser and visually confirm it**

Open `http://cozumelhomes.net` (Safari worked reliably for this during
VPS verification; other browsers may cache old resolutions). Confirm:
homepage loads, property pages load, the hero video plays, the contact
section and map render, no broken images (uploads path is now correct).

- [ ] **Step 5: Remove the temporary hosts override**

```bash
sudo sed -i '' '/cozumelhomes.net/d' /etc/hosts
```

- [ ] **Step 6: Verify it's gone**

```bash
grep cozumelhomes.net /etc/hosts
```
Expected: no output.

- [ ] **Step 7: Stop and report** — summarize what was verified, then wait
  for the operator's explicit go-ahead before Task 6. Do not proceed
  automatically.

---

### Task 6: DNS cutover (only after explicit go-ahead)

**Files:** none (registrar DNS zone + remote server state)

**Interfaces:**
- Consumes: operator's explicit go-ahead following Task 5.
- Produces: `cozumelhomes.net` and `www.cozumelhomes.net` resolving to the
  VPS, served over HTTPS.

- [ ] **Step 1: Confirm the operator has explicitly said to proceed.** This
  is a checkpoint, not a command — do not continue without it.

- [ ] **Step 2: Update the `A` records at the registrar (operator does this
  directly in the registrar's dashboard — no API credential exists for
  this)**

Change `A` record for `@` from the current value to `2.25.104.105`.
Change `A` record for `www` from the current value to `2.25.104.105`.
Leave every other record (`MX`, `TXT`, `NS`, `CNAME`s) untouched.

- [ ] **Step 3: Verify DNS has propagated**

```bash
dig +short cozumelhomes.net
```
Expected: eventually returns `2.25.104.105` (may take up to the record's
TTL to update — check every few minutes rather than assuming instant
propagation).

- [ ] **Step 4: Request the Let's Encrypt certificate now that DNS points here**

```bash
ssh -i ~/.ssh/id_ed25519_cozumel_vps deploy@2.25.104.105 "sudo wo site update cozumelhomes.net --letsencrypt"
```
If prompted for a renewal-notice email, use a role-based mailbox (e.g. a
shared/business alias), not a personal name-based address.

- [ ] **Step 5: Verify HTTPS is live**

```bash
curl -sI https://cozumelhomes.net | head -1
```
Expected: `HTTP/2 200` (or `HTTP/1.1 200`).

- [ ] **Step 6: No commit needed** — this task only changes DNS/server state, nothing in the git repo.

---

### Task 7: Point the Mac app's sync feature at production

**Files:** none (app runtime configuration, entered via the GUI)

**Interfaces:**
- Consumes: production URL and Application Password from Task 5/6.
- Produces: a working Mac-app-to-production WordPress sync.

This is a manual GUI step for the operator, not a code change.

- [ ] **Step 1: Open the CozumelManager app's Settings sheet, WordPress sync section.**

- [ ] **Step 2: Update the site URL to `https://cozumelhomes.net`.**

- [ ] **Step 3: Enter the new Application Password generated in Task 5, Step 2.**

- [ ] **Step 4: Save, then trigger a test sync** (e.g. edit a property field
  and use the existing Sync-to-Website action) to confirm the end-to-end
  path works against production.

---

## Not part of this plan

Retiring/canceling the previous third-party hosting subscription itself
(the operator's own account action, separate from any DNS/server change
here) — do once Task 6 is confirmed stable. The [[ical_three_way_sync]]
work (Airbnb/website/app calendar sync) is a separate, not-yet-designed
follow-on and is not addressed by this plan.
