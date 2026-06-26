# Auto-Update via Sparkle 2 — Design Spec

**Date:** 2026-06-26
**Status:** Approved

## Overview

Add in-app auto-update capability to CozumelManager using Sparkle 2. Updates check automatically on launch and are available on demand via a "Check for Updates…" menu item. Releases are hosted on GitHub Releases; the appcast is a static XML file committed to the main branch of the repo.

## Scope

- macOS only. Sparkle is a macOS framework; iOS updates are handled by the App Store.
- Applies to CozumelManager and any future macOS apps built under this project.

## Architecture

```
CozumelManager.app
  └── Sparkle (via SPM)
        ├── Checks appcast.xml on launch + on demand
        ├── Shows native macOS update UI when new version found
        └── Downloads + installs update (via XPC helper)

appcast.xml  ← committed to repo root, served via raw.githubusercontent.com
  └── each <item> points to a GitHub Release asset (.dmg)
              └── signed with Ed25519 private key (stored in Keychain)
```

## Security

- **EdDSA (Ed25519) signatures** — every release `.dmg` is signed with a private key stored in Keychain. Sparkle verifies the signature against the public key embedded in `Info.plist` before installing. Tampered or unsigned updates are rejected.
- **HTTPS enforced** — Sparkle 2 rejects plaintext HTTP appcast URLs at the API level.
- **XPC isolation** — update installation runs in a separate sandboxed XPC process.
- Private key must never be committed to git.

## App Integration

### 1. SPM Dependency

Add via Xcode → File → Add Package Dependencies:
```
https://github.com/sparkle-project/Sparkle
```
Version: `2.x.x` (latest stable). Add `Sparkle` framework to the CozumelManager target.

### 2. Info.plist Keys

```xml
<key>SUFeedURL</key>
<string>https://raw.githubusercontent.com/hahaluaha/Cozumel-Manager/main/appcast.xml</string>

<key>SUPublicEDKey</key>
<string><!-- Ed25519 public key from generate_keys --></string>
```

### 3. CozumelManagerApp.swift

```swift
import Sparkle

@main
struct CozumelManagerApp: App {
    private let updaterController = SPARKLEUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
    // rest of body unchanged
}
```

### 4. "Check for Updates…" Menu Item

```swift
.commands {
    CommandGroup(after: .appInfo) {
        Button("Check for Updates…") {
            updaterController.checkForUpdates(nil)
        }
    }
}
```

Automatic launch check is handled by Sparkle with no additional code.

## Appcast Format

File: `appcast.xml` at repo root. Served from:
`https://raw.githubusercontent.com/hahaluaha/Cozumel-Manager/main/appcast.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>Cozumel Manager</title>
        <link>https://raw.githubusercontent.com/hahaluaha/Cozumel-Manager/main/appcast.xml</link>
        <item>
            <title>Version 1.1</title>
            <pubDate>Thu, 26 Jun 2026 00:00:00 +0000</pubDate>
            <sparkle:version>1.1</sparkle:version>
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
            <enclosure
                url="https://github.com/hahaluaha/Cozumel-Manager/releases/download/v1.1/CozumelManager.dmg"
                sparkle:edSignature="<!-- output of sign_update -->"
                length="<!-- file size in bytes -->"
                type="application/octet-stream" />
        </item>
    </channel>
</rss>
```

New releases are prepended as additional `<item>` entries. Oldest entries can be pruned over time.

## One-Time Setup

1. Run `generate_keys` (bundled with Sparkle) to create the Ed25519 key pair.
2. Save the private key to Keychain when prompted.
3. Paste the public key into `Info.plist` as `SUPublicEDKey`.

Done once. The key pair never changes unless you rotate it intentionally.

## Per-Release Workflow

1. Archive + notarize in Xcode (Product → Archive → Distribute → Direct Distribution).
2. Export `.dmg`.
3. Run `./sign_update CozumelManager.dmg` — copy the `edSignature` output.
4. Upload `.dmg` to a new GitHub Release tagged `v1.x`.
5. Add a new `<item>` at the top of `appcast.xml` with version, download URL, signature, and file size.
6. Commit and push `appcast.xml` to `main`.

Sparkle picks up the update on the next automatic check or when the user selects "Check for Updates…".
