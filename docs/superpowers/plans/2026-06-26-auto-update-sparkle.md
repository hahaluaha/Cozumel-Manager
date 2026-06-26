# Auto-Update via Sparkle 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate Sparkle 2 into CozumelManager to provide automatic update checks on launch and a "Check for Updates…" menu item, with updates signed and hosted on GitHub Releases.

**Architecture:** Sparkle 2 is added as an SPM dependency and initialized once at app startup via `SPUStandardUpdaterController`. The appcast.xml is committed to the repo root and served at a stable raw GitHub URL; each release's `.dmg` is signed with an Ed25519 key and uploaded to GitHub Releases.

**Tech Stack:** Sparkle 2 (SPM), SwiftUI, macOS 14+, GitHub Releases for hosting.

## Global Constraints

- macOS 14+ deployment target — do not lower it.
- Sparkle 2 only — do not use Sparkle 1.x.
- Private signing key must never be committed to git.
- `SUFeedURL` must use HTTPS.
- App entry point is `CozumelManager/CozumelManager/CozumelManagerApp.swift` — `PropertyStore` is already injected there; do not move it.
- Xcode project uses `GENERATE_INFOPLIST_FILE = YES` — Info.plist keys are added via the target's Info tab, not a file.

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `CozumelManager/CozumelManager/CozumelManagerApp.swift` | Modify | Add `SPUStandardUpdaterController` + `Commands` with "Check for Updates…" |
| Xcode target Info tab | Modify (Xcode UI) | Add `SUFeedURL` and `SUPublicEDKey` keys |
| `appcast.xml` (repo root) | Create | Feed file Sparkle fetches to discover updates |
| `~/sparkle-tools/` (local only, not in repo) | Create | Holds `generate_keys` and `sign_update` binaries |

---

## Task 1: Add Sparkle 2 via SPM

**Files:**
- Modify: Xcode project (via Xcode UI — no manual file edits)

**Interfaces:**
- Produces: `import Sparkle` available in Swift files; `SPUStandardUpdaterController` type resolvable at compile time

- [ ] **Step 1: Add the package in Xcode**

  In Xcode with the project open:
  1. File → Add Package Dependencies…
  2. Paste into the search bar: `https://github.com/sparkle-project/Sparkle`
  3. Set the version rule to **Up to Next Major Version** from `2.0.0`
  4. Click **Add Package**
  5. When prompted to choose package products, check **Sparkle** and set the target to **CozumelManager**
  6. Click **Add Package**

- [ ] **Step 2: Verify the build succeeds**

  In Xcode: Cmd+B

  Expected: Build Succeeded. If you see "No such module 'Sparkle'" the package wasn't added to the target — repeat Step 1 and ensure CozumelManager is checked.

- [ ] **Step 3: Commit the package resolution**

  ```bash
  git add CozumelManager/CozumelManager.xcodeproj/project.pbxproj
  git add CozumelManager/CozumelManager.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/
  git commit -m "chore: add Sparkle 2 SPM dependency"
  ```

---

## Task 2: Generate Ed25519 signing key pair

**Files:**
- Create: `~/sparkle-tools/` (local, never committed)

**Interfaces:**
- Produces: Ed25519 public key string (used in Task 3), private key stored in Keychain

- [ ] **Step 1: Download Sparkle binary release**

  Go to https://github.com/sparkle-project/Sparkle/releases and download the latest `Sparkle-2.x.x.tar.xz`. Extract it somewhere temporary (e.g., `~/Downloads/Sparkle-2.x.x/`).

  The archive contains a `bin/` folder with `generate_keys` and `sign_update`. Copy these to a stable location:

  ```bash
  mkdir -p ~/sparkle-tools
  cp ~/Downloads/Sparkle-2.*/bin/generate_keys ~/sparkle-tools/
  cp ~/Downloads/Sparkle-2.*/bin/sign_update ~/sparkle-tools/
  chmod +x ~/sparkle-tools/generate_keys ~/sparkle-tools/sign_update
  ```

- [ ] **Step 2: Generate the key pair**

  ```bash
  ~/sparkle-tools/generate_keys
  ```

  Expected output (example — your values will differ):

  ```
  A new signing key has been generated and saved in your Keychain.
  Supply the following EdDSA public key in your app's Info.plist under the SUPublicEDKey key:

  r9XJaGE9/eKLJYKX1Ia2SJzNE3U7HoTLleBOcv+XXXX=
  ```

  **Copy the public key string now.** The private key is saved to Keychain automatically — you do not need to store it anywhere else.

- [ ] **Step 3: Verify the private key is in Keychain**

  Open Keychain Access.app → search for "Sparkle" → confirm an entry named "Sparkle Key" or similar exists. If it does not appear, re-run `generate_keys`.

---

## Task 3: Configure Info.plist keys in Xcode

**Files:**
- Modify: Xcode target Info tab (CozumelManager target → Info)

**Interfaces:**
- Consumes: Ed25519 public key string from Task 2
- Produces: App at runtime reads `SUFeedURL` and `SUPublicEDKey` from its bundle

- [ ] **Step 1: Open the target Info tab**

  In Xcode: click the **CozumelManager** project in the navigator → select the **CozumelManager** target → click the **Info** tab.

- [ ] **Step 2: Add SUFeedURL**

  Under "Custom macOS Target Properties", click the **+** button on any existing row:
  - Key: `SUFeedURL`
  - Type: `String`
  - Value: `https://raw.githubusercontent.com/hahaluaha/Cozumel-Manager/main/appcast.xml`

- [ ] **Step 3: Add SUPublicEDKey**

  Click **+** again:
  - Key: `SUPublicEDKey`
  - Type: `String`
  - Value: *(paste the public key string from Task 2)*

- [ ] **Step 4: Verify build succeeds**

  Cmd+B. Expected: Build Succeeded.

- [ ] **Step 5: Commit**

  ```bash
  git add CozumelManager/CozumelManager.xcodeproj/project.pbxproj
  git commit -m "chore: add Sparkle 2 Info.plist keys (feed URL + public key)"
  ```

---

## Task 4: Wire Sparkle into the app + add menu item

**Files:**
- Modify: `CozumelManager/CozumelManager/CozumelManagerApp.swift`

**Interfaces:**
- Consumes: `SPUStandardUpdaterController` from Sparkle (Task 1)
- Produces: Automatic update check on launch; "Check for Updates…" in the app menu

- [ ] **Step 1: Replace CozumelManagerApp.swift**

  Open `CozumelManager/CozumelManager/CozumelManagerApp.swift` and replace its contents with:

  ```swift
  import SwiftUI
  import Sparkle

  @main
  struct CozumelManagerApp: App {
      @StateObject private var store = PropertyStore()
      private let updaterController = SPUStandardUpdaterController(
          startingUpdater: true,
          updaterDelegate: nil,
          userDriverDelegate: nil
      )

      var body: some Scene {
          Window("Cozumel Manager", id: "main") {
              MainDashboardView()
                  .environmentObject(store)
          }
          .commands {
              CommandGroup(after: .appInfo) {
                  Button("Check for Updates…") {
                      updaterController.checkForUpdates(nil)
                  }
              }
          }
      }
  }
  ```

- [ ] **Step 2: Build**

  Cmd+B. Expected: Build Succeeded with no warnings about Sparkle.

- [ ] **Step 3: Run and verify the menu item**

  Cmd+R to run. Open the **CozumelManager** menu in the menu bar. Confirm "Check for Updates…" appears below "About CozumelManager".

- [ ] **Step 4: Verify the first-run permission dialog**

  On first launch after Sparkle is wired up, Sparkle shows a one-time dialog asking permission to check for updates automatically. Confirm it appears. Click "Check Automatically" to dismiss it.

  (In the Simulator or a dev build this dialog may appear even if the appcast URL doesn't resolve yet — that is expected.)

- [ ] **Step 5: Commit**

  ```bash
  git add CozumelManager/CozumelManager/CozumelManagerApp.swift
  git commit -m "feat: wire Sparkle 2 updater and add Check for Updates menu item"
  ```

---

## Task 5: Create initial appcast.xml

**Files:**
- Create: `appcast.xml` (repo root)

**Interfaces:**
- Produces: Stable feed URL Sparkle can fetch; update entries added here each release

- [ ] **Step 1: Create appcast.xml at the repo root**

  Create `/Users/fernandogonzalez/Documents/Cozumel_App_Final/appcast.xml`:

  ```xml
  <?xml version="1.0" encoding="utf-8"?>
  <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
      <channel>
          <title>Cozumel Manager</title>
          <link>https://raw.githubusercontent.com/hahaluaha/Cozumel-Manager/main/appcast.xml</link>
          <!-- Add a new <item> here for each release, newest first. -->
      </channel>
  </rss>
  ```

  No `<item>` entries yet — the first one is added when you ship the first update.

- [ ] **Step 2: Commit**

  ```bash
  git add appcast.xml
  git commit -m "chore: add initial empty appcast.xml for Sparkle 2"
  ```

---

## Per-Release Workflow (reference — not a task)

Each time you ship a new version, after archiving and notarizing:

1. Export the `.dmg` from Xcode Organizer.
2. Sign it:
   ```bash
   ~/sparkle-tools/sign_update CozumelManager.dmg
   ```
   Copy the `edSignature` value from the output.

3. Get file size:
   ```bash
   wc -c < CozumelManager.dmg
   ```

4. Upload `.dmg` to a new GitHub Release tagged `v1.x` at `https://github.com/hahaluaha/Cozumel-Manager/releases`.

5. Prepend a new `<item>` to `appcast.xml`:
   ```xml
   <item>
       <title>Version 1.1</title>
       <pubDate>Thu, 26 Jun 2026 00:00:00 +0000</pubDate>
       <sparkle:version>1.1</sparkle:version>
       <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
       <enclosure
           url="https://github.com/hahaluaha/Cozumel-Manager/releases/download/v1.1/CozumelManager.dmg"
           sparkle:edSignature="PASTE_SIGNATURE_HERE"
           length="PASTE_FILE_SIZE_HERE"
           type="application/octet-stream" />
   </item>
   ```

6. Commit and push `appcast.xml` to `main`. Sparkle picks it up on the next automatic check.
