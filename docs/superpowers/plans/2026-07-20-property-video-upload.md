# Property Video Upload Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let Kelley attach one short video (~8s, imported from an external file — AI Studio, phone, editor) to each of the 3 rental properties and the for-sale property, viewable inline in the inspector.

**Architecture:** A new file-agnostic `VideoImporter` enum (copy + duration-check logic, unit tested without SwiftUI) backs a new shared `VideoSectionView` SwiftUI component. Both `Property` and `ForSaleProperty` gain an optional `videoURL` field, decoded the same way `Property.monthlyPrice` already is (`try?`, no migration). `PropertyInspectorView` and `ForSaleInspectorView` each embed `VideoSectionView`, passing their own destination directory and a `Binding<URL?>` into their draft.

**Tech Stack:** SwiftUI, macOS 14+, AVKit (`VideoPlayer`), AVFoundation (`AVURLAsset`), Swift Testing (`@Test`/`#expect`), `Foundation` (`FileManager`, `JSONEncoder`/`JSONDecoder`)

## Global Constraints

- Target: macOS 14+.
- Never use `.onChange(of:)` to react to `videoURL` changing — confirmed broken on this project's Xcode 26 beta toolchain (see project `CLAUDE.md`). Use `.id(videoURL)` on the player subview to force SwiftUI to rebuild it when the URL changes, and set state directly inside the action functions that mutate it (`pickVideo`, `removeVideo`).
- New Swift files are picked up automatically — this project uses `PBXFileSystemSynchronizedRootGroup` (Xcode 16 synchronized groups), so no manual "add to target" step is needed for `.swift` files placed under `CozumelManager/CozumelManager/`.
- One video per property — uploading a new one deletes and replaces the old file, never accumulates.
- Duration over 8s warns but never blocks the upload.
- Build after every task with `xcodebuild -project CozumelManager/CozumelManager.xcodeproj -scheme CozumelManager -configuration Debug -derivedDataPath /tmp/cozumel-build build` before committing.
- Run tests with `xcodebuild test -project CozumelManager/CozumelManager.xcodeproj -scheme CozumelManager -destination 'platform=macOS' -only-testing:<Target>/<Suite>`.

---

### Task 1: `VideoImporter` helper + unit tests

**Files:**
- Create: `CozumelManager/CozumelManager/Support/VideoImporter.swift`
- Create: `CozumelManager/CozumelManagerTests/VideoImporterTests.swift`

**Interfaces:**
- Produces: `VideoImporter.copy(from:into:) throws -> URL`, `VideoImporter.duration(of:) async -> Double?`, `VideoImporter.isOverLimit(_:) -> Bool`, `VideoImporter.warnDurationSeconds: Double` — consumed by Task 4's `VideoSectionView`.

---

- [ ] **Step 1: Write the failing tests**

  Create `CozumelManager/CozumelManagerTests/VideoImporterTests.swift`:

  ```swift
  import Foundation
  import Testing
  @testable import CozumelManager

  struct VideoImporterTests {

      private func makeTempFile(named name: String, contents: String = "fake video bytes") throws -> URL {
          let dir = FileManager.default.temporaryDirectory
              .appendingPathComponent(UUID().uuidString)
          try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
          let file = dir.appendingPathComponent(name)
          try contents.write(to: file, atomically: true, encoding: .utf8)
          return file
      }

      @Test func copy_placesFileInDestinationDirectory() throws {
          let source = try makeTempFile(named: "clip.mp4")
          let destDir = FileManager.default.temporaryDirectory
              .appendingPathComponent(UUID().uuidString)

          let result = try VideoImporter.copy(from: source, into: destDir)

          #expect(result.lastPathComponent == "clip.mp4")
          #expect(FileManager.default.fileExists(atPath: result.path))
      }

      @Test func copy_createsDestinationDirectoryIfMissing() throws {
          let source = try makeTempFile(named: "clip.mp4")
          let destDir = FileManager.default.temporaryDirectory
              .appendingPathComponent(UUID().uuidString)
              .appendingPathComponent("nested")

          _ = try VideoImporter.copy(from: source, into: destDir)

          var isDir: ObjCBool = false
          #expect(FileManager.default.fileExists(atPath: destDir.path, isDirectory: &isDir))
          #expect(isDir.boolValue)
      }

      @Test func copy_doesNotOverwriteExistingFileWithSameName() throws {
          let source = try makeTempFile(named: "clip.mp4", contents: "new bytes")
          let destDir = FileManager.default.temporaryDirectory
              .appendingPathComponent(UUID().uuidString)
          try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
          let existing = destDir.appendingPathComponent("clip.mp4")
          try "original bytes".write(to: existing, atomically: true, encoding: .utf8)

          let result = try VideoImporter.copy(from: source, into: destDir)

          let resultContents = try String(contentsOf: result, encoding: .utf8)
          #expect(resultContents == "original bytes")
      }

      @Test func isOverLimit_trueWhenAboveEightSeconds() {
          #expect(VideoImporter.isOverLimit(8.1))
          #expect(!VideoImporter.isOverLimit(8.0))
          #expect(!VideoImporter.isOverLimit(3.5))
      }

      @Test func duration_returnsNilForNonVideoFile() async throws {
          let source = try makeTempFile(named: "not-a-video.mp4", contents: "definitely not a video")
          let result = await VideoImporter.duration(of: source)
          #expect(result == nil)
      }
  }
  ```

- [ ] **Step 2: Run tests to verify they fail**

  Run: `xcodebuild test -project CozumelManager/CozumelManager.xcodeproj -scheme CozumelManager -destination 'platform=macOS' -only-testing:CozumelManagerTests/VideoImporterTests`
  Expected: FAIL — `VideoImporter` not found in scope.

- [ ] **Step 3: Implement `VideoImporter`**

  Create `CozumelManager/CozumelManager/Support/VideoImporter.swift`:

  ```swift
  import Foundation
  import AVFoundation

  enum VideoImporter {
      static let warnDurationSeconds: Double = 8.0

      /// Copies `source` into `directory` (creating it if needed) and returns the destination URL.
      /// If a file with the same name already exists at the destination, it is left untouched.
      static func copy(from source: URL, into directory: URL) throws -> URL {
          try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
          let destFile = directory.appendingPathComponent(source.lastPathComponent)
          if !FileManager.default.fileExists(atPath: destFile.path) {
              try FileManager.default.copyItem(at: source, to: destFile)
          }
          return destFile
      }

      static func duration(of url: URL) async -> Double? {
          let asset = AVURLAsset(url: url)
          guard let duration = try? await asset.load(.duration) else { return nil }
          let seconds = CMTimeGetSeconds(duration)
          return seconds.isFinite ? seconds : nil
      }

      static func isOverLimit(_ seconds: Double) -> Bool {
          seconds > warnDurationSeconds
      }
  }
  ```

- [ ] **Step 4: Run tests to verify they pass**

  Run: `xcodebuild test -project CozumelManager/CozumelManager.xcodeproj -scheme CozumelManager -destination 'platform=macOS' -only-testing:CozumelManagerTests/VideoImporterTests`
  Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

  ```bash
  git add CozumelManager/CozumelManager/Support/VideoImporter.swift CozumelManager/CozumelManagerTests/VideoImporterTests.swift
  git commit -m "feat: add VideoImporter helper for copying and duration-checking videos"
  ```

---

### Task 2: `Property.videoURL` field

**Files:**
- Modify: `CozumelManager/CozumelManager/Models/Property.swift`
- Modify: `CozumelManager/CozumelManagerTests/CozumelManagerTests.swift`

**Interfaces:**
- Consumes: nothing new.
- Produces: `Property.videoURL: URL?` — consumed by Task 4's `PropertyInspectorView` wiring.

---

- [ ] **Step 1: Write the failing tests**

  In `CozumelManager/CozumelManagerTests/CozumelManagerTests.swift`, add these two `@Test` methods inside `struct PropertyModelTests` (after `property_roundtrips_guestPricingFields`):

  ```swift
      @Test func property_decodesLegacyJSON_withNilVideoURL() throws {
          let json = """
          {"id":"p1","name":"Test","neighborhood":"N","address":"A","base_rate":100.0,"status":"active"}
          """.data(using: .utf8)!
          let decoder = JSONDecoder()
          decoder.dateDecodingStrategy = .iso8601
          let p = try decoder.decode(Property.self, from: json)
          #expect(p.videoURL == nil)
      }

      @Test func property_roundtrips_videoURL() throws {
          let original = Property(
              id: "prop-003", name: "Nah Ha 101", neighborhood: "N", address: "A",
              baseRate: 325.0, status: .active,
              videoURL: URL(fileURLWithPath: "/tmp/clip.mp4")
          )
          let encoder = JSONEncoder()
          encoder.dateEncodingStrategy = .iso8601
          let data = try encoder.encode(original)
          let decoder = JSONDecoder()
          decoder.dateDecodingStrategy = .iso8601
          let decoded = try decoder.decode(Property.self, from: data)
          #expect(decoded.videoURL == URL(fileURLWithPath: "/tmp/clip.mp4"))
      }
  ```

- [ ] **Step 2: Run tests to verify they fail**

  Run: `xcodebuild test -project CozumelManager/CozumelManager.xcodeproj -scheme CozumelManager -destination 'platform=macOS' -only-testing:CozumelManagerTests/PropertyModelTests`
  Expected: FAIL — `Property` has no initializer/member `videoURL`.

- [ ] **Step 3: Add `videoURL` to `Property`**

  In `CozumelManager/CozumelManager/Models/Property.swift`, add the stored property after `photos` (line 33):

  ```swift
      var photos: [URL]
      var videoURL: URL?
  ```

  Add the parameter to `init` (after `photos: [URL] = []`, line 39):

  ```swift
      init(id: String, name: String, neighborhood: String, address: String,
           baseRate: Double, monthlyPrice: Double? = nil,
           baseGuests: Int? = nil, maxGuests: Int? = nil, extraGuestFee: Double? = nil,
           status: PropertyStatus,
           unavailableDateRanges: [DateRange] = [], photos: [URL] = [],
           videoURL: URL? = nil) {
          self.id = id
          self.name = name
          self.neighborhood = neighborhood
          self.address = address
          self.baseRate = baseRate
          self.monthlyPrice = monthlyPrice
          self.baseGuests = baseGuests
          self.maxGuests = maxGuests
          self.extraGuestFee = extraGuestFee
          self.status = status
          self.unavailableDateRanges = unavailableDateRanges
          self.photos = photos
          self.videoURL = videoURL
      }
  ```

  Add the coding key (in `CodingKeys`, line 69-77):

  ```swift
      enum CodingKeys: String, CodingKey {
          case id, name, neighborhood, address, status, photos
          case baseRate = "base_rate"
          case monthlyPrice = "monthly_price"
          case baseGuests = "base_guests"
          case maxGuests = "max_guests"
          case extraGuestFee = "extra_guest_fee"
          case unavailableDateRanges = "unavailable_date_ranges"
          case videoURL = "video_url"
      }
  ```

  Add the `try?` decode in `init(from:)` (after `photos = ...`, line 92):

  ```swift
          photos = (try? c.decode([URL].self, forKey: .photos)) ?? []
          videoURL = try? c.decode(URL.self, forKey: .videoURL)
  ```

- [ ] **Step 4: Run tests to verify they pass**

  Run: `xcodebuild test -project CozumelManager/CozumelManager.xcodeproj -scheme CozumelManager -destination 'platform=macOS' -only-testing:CozumelManagerTests/PropertyModelTests`
  Expected: PASS (9 tests)

- [ ] **Step 5: Commit**

  ```bash
  git add CozumelManager/CozumelManager/Models/Property.swift CozumelManager/CozumelManagerTests/CozumelManagerTests.swift
  git commit -m "feat: add optional videoURL field to Property"
  ```

---

### Task 3: `ForSaleProperty.videoURL` field

**Files:**
- Modify: `CozumelManager/CozumelManager/Models/ForSaleProperty.swift`
- Create: `CozumelManager/CozumelManagerTests/ForSalePropertyTests.swift`

**Interfaces:**
- Consumes: nothing new.
- Produces: `ForSaleProperty.videoURL: URL?` — consumed by Task 5's `ForSaleInspectorView` wiring.

---

- [ ] **Step 1: Write the failing tests**

  Create `CozumelManager/CozumelManagerTests/ForSalePropertyTests.swift`:

  ```swift
  import Foundation
  import Testing
  @testable import CozumelManager

  struct ForSalePropertyTests {

      @Test func forSaleProperty_defaultsVideoURLToNil() {
          let p = ForSaleProperty(name: "Cozumel House", askingPrice: 350_000)
          #expect(p.videoURL == nil)
      }

      @Test func forSaleProperty_roundtrips_videoURL() throws {
          let original = ForSaleProperty(
              name: "Cozumel House", askingPrice: 350_000,
              videoURL: URL(fileURLWithPath: "/tmp/house.mp4")
          )
          let data = try JSONEncoder().encode(original)
          let decoded = try JSONDecoder().decode(ForSaleProperty.self, from: data)
          #expect(decoded.videoURL == URL(fileURLWithPath: "/tmp/house.mp4"))
      }

      @Test func forSaleProperty_decodesLegacyJSON_withNilVideoURL() throws {
          let json = """
          {"id":"\\(UUID().uuidString)","name":"Cozumel House","description":"","askingPrice":350000,"listingURL":"","photos":[],"notes":""}
          """.data(using: .utf8)!
          let decoded = try JSONDecoder().decode(ForSaleProperty.self, from: json)
          #expect(decoded.videoURL == nil)
      }
  }
  ```

- [ ] **Step 2: Run tests to verify they fail**

  Run: `xcodebuild test -project CozumelManager/CozumelManager.xcodeproj -scheme CozumelManager -destination 'platform=macOS' -only-testing:CozumelManagerTests/ForSalePropertyTests`
  Expected: FAIL — `ForSaleProperty` has no member `videoURL`.

- [ ] **Step 3: Add `videoURL` to `ForSaleProperty`**

  In `CozumelManager/CozumelManager/Models/ForSaleProperty.swift`, add the stored property after `photos` (line 9):

  ```swift
      var photos: [URL]
      var notes: String
      var videoURL: URL?
  ```

  Add the parameter to `init` (after `notes: String = ""`, line 19):

  ```swift
      init(
          id: UUID = UUID(),
          name: String,
          description: String = "",
          askingPrice: Double,
          listingURL: String = "",
          photos: [URL] = [],
          notes: String = "",
          videoURL: URL? = nil
      ) {
          self.id = id
          self.name = name
          self.description = description
          self.askingPrice = askingPrice
          self.listingURL = listingURL
          self.photos = photos
          self.notes = notes
          self.videoURL = videoURL
      }
  ```

  `ForSaleProperty`'s `Codable` conformance is synthesized (no custom `CodingKeys`/`init(from:)`), so the new field decodes as `nil` automatically for any existing JSON missing the key — Swift's synthesized `Decodable` treats an `Optional` property with no matching key as `nil` without needing `try?`.

- [ ] **Step 4: Run tests to verify they pass**

  Run: `xcodebuild test -project CozumelManager/CozumelManager.xcodeproj -scheme CozumelManager -destination 'platform=macOS' -only-testing:CozumelManagerTests/ForSalePropertyTests`
  Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

  ```bash
  git add CozumelManager/CozumelManager/Models/ForSaleProperty.swift CozumelManager/CozumelManagerTests/ForSalePropertyTests.swift
  git commit -m "feat: add optional videoURL field to ForSaleProperty"
  ```

---

### Task 4: `VideoSectionView` shared component + wire into `PropertyInspectorView`

**Files:**
- Create: `CozumelManager/CozumelManager/Views/VideoSectionView.swift`
- Modify: `CozumelManager/CozumelManager/Views/PropertyInspectorView.swift`

**Interfaces:**
- Consumes: `VideoImporter.copy(from:into:)`, `VideoImporter.duration(of:)`, `VideoImporter.isOverLimit(_:)` (Task 1); `Property.videoURL` (Task 2).
- Produces: `VideoSectionView(videoURL: Binding<URL?>, destinationDirectory: URL, onCommit: () -> Void)` — consumed by Task 5's `ForSaleInspectorView` wiring.

This task has no automated test — SwiftUI view rendering isn't covered by the Swift Testing suite in this project (see `PropertyInspectorView`/`ForSaleInspectorView`, both untested). Verification is a build + manual check.

---

- [ ] **Step 1: Create `VideoSectionView.swift`**

  Create `CozumelManager/CozumelManager/Views/VideoSectionView.swift`:

  ```swift
  import SwiftUI
  import UniformTypeIdentifiers
  import AVKit

  struct VideoSectionView: View {
      @Binding var videoURL: URL?
      let destinationDirectory: URL
      let onCommit: () -> Void

      @State private var showDurationWarning = false
      @State private var durationWarningText = ""

      var body: some View {
          Section("Video") {
              if let videoURL {
                  InlineVideoPlayer(url: videoURL)
                      .id(videoURL)
                  HStack {
                      Button("Replace Video") { pickVideo() }
                      Button(role: .destructive) {
                          removeVideo()
                      } label: {
                          Label("Remove Video", systemImage: "trash")
                      }
                  }
              } else {
                  Button {
                      pickVideo()
                  } label: {
                      Label("Add Video", systemImage: "plus")
                  }
              }
          }
          .alert("Video Longer Than 8 Seconds", isPresented: $showDurationWarning) {
              Button("OK", role: .cancel) {}
          } message: {
              Text(durationWarningText)
          }
      }

      private func pickVideo() {
          let panel = NSOpenPanel()
          panel.allowedContentTypes = [.movie]
          panel.canChooseFiles = true
          panel.canChooseDirectories = false
          panel.allowsMultipleSelection = false
          guard panel.runModal() == .OK, let source = panel.urls.first else { return }
          importVideo(from: source)
      }

      private func importVideo(from source: URL) {
          if let existing = videoURL {
              try? FileManager.default.removeItem(at: existing)
          }
          guard let destFile = try? VideoImporter.copy(from: source, into: destinationDirectory) else { return }
          videoURL = destFile
          onCommit()

          Task {
              if let seconds = await VideoImporter.duration(of: destFile), VideoImporter.isOverLimit(seconds) {
                  durationWarningText = "This video is \(Int(seconds))s — longer than the 8s AI Studio limit. It was uploaded anyway."
                  showDurationWarning = true
              }
          }
      }

      private func removeVideo() {
          if let existing = videoURL {
              try? FileManager.default.removeItem(at: existing)
          }
          videoURL = nil
          onCommit()
      }
  }

  private struct InlineVideoPlayer: View {
      let url: URL
      @State private var player: AVPlayer

      init(url: URL) {
          self.url = url
          _player = State(initialValue: AVPlayer(url: url))
      }

      var body: some View {
          VideoPlayer(player: player)
              .frame(height: 200)
      }
  }
  ```

  The `.id(videoURL)` on `InlineVideoPlayer` forces SwiftUI to discard and rebuild that subview (and its `@State private var player`) whenever `videoURL` changes for any reason — including the `.onReceive(store.$properties)` refresh in the parent inspector — without relying on the broken `.onChange(of:)` hook.

- [ ] **Step 2: Wire into `PropertyInspectorView`**

  In `CozumelManager/CozumelManager/Views/PropertyInspectorView.swift`, add `videoSection` to `body` after `photosSection` (line 25):

  ```swift
              availabilitySection
              photosSection
              videoSection
  ```

  Add the computed properties after the `// MARK: - Photos` block's `copyPhoto(from:)` function (after line 157, before `// MARK: - Availability`):

  ```swift
      // MARK: - Video

      private var videoSection: some View {
          VideoSectionView(videoURL: $draft.videoURL, destinationDirectory: videoDirectory, onCommit: commit)
      }

      private var videoDirectory: URL {
          let appSupport = FileManager.default.urls(
              for: .applicationSupportDirectory, in: .userDomainMask)[0]
          return appSupport.appendingPathComponent("CozumelManager/Videos/\(draft.id)")
      }
  ```

- [ ] **Step 3: Build to verify it compiles**

  Run: `xcodebuild -project CozumelManager/CozumelManager.xcodeproj -scheme CozumelManager -configuration Debug -derivedDataPath /tmp/cozumel-build build`
  Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Manual verification**

  Run: `open CozumelManager/CozumelManager.xcodeproj`, Cmd+R, select any rental property in the sidebar, scroll to the new "Video" section below Photos, click "Add Video", pick any short `.mp4`/`.mov` file. Confirm:
  - The video appears inline with playable controls.
  - "Replace Video" swaps it for a different file and the old file is removed from `~/Library/Containers/Team-Paraiso.CozumelManager/Data/Library/Application Support/CozumelManager/Videos/<property-id>/`.
  - Picking a video longer than 8s shows the alert but still uploads it.
  - "Remove Video" clears the section back to the "Add Video" button.

- [ ] **Step 5: Commit**

  ```bash
  git add CozumelManager/CozumelManager/Views/VideoSectionView.swift CozumelManager/CozumelManager/Views/PropertyInspectorView.swift
  git commit -m "feat: add video upload section to PropertyInspectorView"
  ```

---

### Task 5: Wire `VideoSectionView` into `ForSaleInspectorView`

**Files:**
- Modify: `CozumelManager/CozumelManager/Views/ForSaleInspectorView.swift`

**Interfaces:**
- Consumes: `VideoSectionView` (Task 4); `ForSaleProperty.videoURL` (Task 3).

No automated test — same rationale as Task 4. Verification is a build + manual check.

---

- [ ] **Step 1: Wire into `ForSaleInspectorView`**

  In `CozumelManager/CozumelManager/Views/ForSaleInspectorView.swift`, add `videoSection` to `body` after `photosSection` (line 27):

  ```swift
              photosSection
              videoSection
  ```

  Add the computed properties after the `// MARK: - Photos` block's `copyPhoto(from:)` function (after line 145, before the closing brace of the struct):

  ```swift
      // MARK: - Video

      private var videoSection: some View {
          VideoSectionView(videoURL: $draft.videoURL, destinationDirectory: videoDirectory, onCommit: commit)
      }

      private var videoDirectory: URL {
          let appSupport = FileManager.default.urls(
              for: .applicationSupportDirectory, in: .userDomainMask)[0]
          return appSupport.appendingPathComponent("CozumelManager/Videos/forsale/\(draft.id)")
      }
  ```

- [ ] **Step 2: Build to verify it compiles**

  Run: `xcodebuild -project CozumelManager/CozumelManager.xcodeproj -scheme CozumelManager -configuration Debug -derivedDataPath /tmp/cozumel-build build`
  Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Manual verification**

  Run: `open CozumelManager/CozumelManager.xcodeproj`, Cmd+R, select the for-sale property in the sidebar, scroll to the new "Video" section below Photos, upload the for-sale property's video file. Confirm it plays inline and persists after reselecting the property (check `~/Library/Containers/Team-Paraiso.CozumelManager/Data/Library/Application Support/CozumelManager/forSaleProperties.json` has a `video_url`/`videoURL` entry after relaunch).

- [ ] **Step 4: Commit**

  ```bash
  git add CozumelManager/CozumelManager/Views/ForSaleInspectorView.swift
  git commit -m "feat: add video upload section to ForSaleInspectorView"
  ```

---

## Out of Scope (carried from spec)

- In-app AI video generation (Google AI Studio API integration)
- Multiple videos per property
- Video compression/transcoding
- Uploading videos to the companion website
