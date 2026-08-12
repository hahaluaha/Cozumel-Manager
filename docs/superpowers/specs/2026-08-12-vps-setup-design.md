# Hostinger VPS Setup — Server Hardening + WordPress Stack

## Context

Companion website `cozumelhomes.net` currently runs only locally (Local by
Flywheel, `cozumel-homes.local`) with Plan A/B complete — see
[[website_plan_a_wp_setup]] and [[plan_b_sync_status]]. Production hosting
has not existed until now. Fernando purchased a Hostinger VPS: Ubuntu 24.04
LTS, bare (no panel/app bundle), IP `2.25.104.105`, root password set,
server already `apt update && upgrade`d.

`cozumelhomes.net` (GoDaddy-managed nameservers) currently resolves to a
generic domain-parking placeholder — confirmed via `dig`/`curl` 2026-08-10.
There is no live production traffic to protect, so this setup can happen
entirely invisibly to the public domain; the only visible moment is the
final DNS cutover (a single A-record swap, not a live-site migration).

## Scope

Server provisioning and hardening only: hardened Ubuntu, WordOps-managed
nginx/PHP-FPM/MariaDB/WP-CLI stack, a fresh WordPress install reachable over
HTTP (SSL once DNS points here). Migrating the actual local site content
(theme, posts, media, `mac_id` sync config) is a separate follow-up — see
[[production_sync_plan_needed]] — not part of this plan.

## Access model

- One sudo user, `deploy`, created for both Fernando and Claude to use —
  Claude operates through Fernando's own Mac terminal/SSH session, so there
  is no separate "Claude identity" to provision for.
- Root SSH login disabled entirely once `deploy` access is verified working.
  No dedicated root access is kept for day-to-day use.
- Kelley never touches SSH or the server directly. She manages the site
  exclusively through WordPress's own `wp-admin` dashboard — completely
  separate credential set, unaffected by anything in this plan.
- SSH key: a single ed25519 keypair generated on Fernando's Mac at
  `~/.ssh/id_ed25519_cozumel_vps` (private) / `id_ed25519_cozumel_vps.pub`
  (public), comment `cozumel-vps-deploy` so it's identifiable in
  `authorized_keys`. This is the one key both Fernando and Claude use since
  Claude acts through Fernando's own shell session — not two separate keys.

## Stack approach

**WordOps** (scripted installer for nginx + PHP-FPM + MariaDB + WP-CLI +
Let's Encrypt automation), superseding the earlier 2026-08-10 plan to
hand-build LEMP piece by piece. Revisited during this session: WordOps is a
CLI tool, not a GUI panel — no bundled control panel or exposed
phpMyAdmin, which was the actual concern behind the original "avoid
managed/pre-built stacks" reasoning (see [[feedback_wordpress_plugins]]).
It produces the same nginx-based, key-only-SSH, UFW/fail2ban-hardened stack
without hand-writing every config file. Chosen for speed without
reintroducing the attack-surface risk the original concern was about.

## Section 1 — Server hardening

1. Generate SSH keypair on the Mac (`ssh-keygen -t ed25519 -C
   cozumel-vps-deploy -f ~/.ssh/id_ed25519_cozumel_vps`).
2. Add the public key to `root`'s `authorized_keys` on the VPS via the
   initial root-password login, to get key-based access working first.
3. Create the `deploy` user, add to the `sudo` group, copy the authorized
   key to `deploy` as well.
4. Verify `ssh deploy@2.25.104.105` works and `sudo` succeeds — **before**
   touching anything else.
5. Lock down `/etc/ssh/sshd_config`: `PermitRootLogin no`,
   `PasswordAuthentication no`, restart `sshd`.
6. UFW: allow OpenSSH, 80, 443; deny everything else by default; enable.
7. Install fail2ban with the default `sshd` jail.

Order matters: step 4 (verify `deploy` access) must succeed before step 5
(locking out root/password auth), so there's no risk of a lockout.

## Section 2 — WordOps install + WordPress site creation

1. Install WordOps via its official install script
   (`wget -qO wo wops.cc && sudo bash wo`).
2. Create the WordPress site for the real domain,
   `wo site create cozumelhomes.net --wp` — safe to do now even though DNS
   doesn't point here yet, since WordOps doesn't require live DNS to build
   the site locally on the server.
3. Leave SSL off for this step (`--letsencrypt` requires live DNS
   validation) — WordOps still produces a working HTTP site in the
   meantime.

## Section 3 — Verification without live DNS

1. Add a temporary entry to the Mac's `/etc/hosts`
   (`2.25.104.105  cozumelhomes.net`) so the browser resolves the real
   domain name straight to the new VPS — same technique already used for
   `cozumel-homes.local`.
2. Visit `http://cozumelhomes.net` in a browser (with the `/etc/hosts`
   override active) — should hit the fresh WordPress install screen.
3. Once ready to go live: flip the GoDaddy A record for `cozumelhomes.net`
   to `2.25.104.105`, remove the temporary `/etc/hosts` entry, then run
   `wo site update cozumelhomes.net --letsencrypt` for real SSL.

## Out of scope (separate follow-ups)

- Migrating the actual site content (theme, posts, media, sync
  configuration) from local dev to production — [[production_sync_plan_needed]].
- Unattended security upgrades, broader OS-level hardening beyond
  SSH/UFW/fail2ban — can be added in a later pass if desired.
- Any change to Kelley's or the WordPress `wp-admin` credential model.
