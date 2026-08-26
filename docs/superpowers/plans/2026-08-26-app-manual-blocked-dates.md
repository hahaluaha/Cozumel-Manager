# Mac App Manual Blocked Dates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let Kelley or Fernando block a date range on a rental property directly in the Mac app, with an optional note, and have it sync automatically to the website's guest-facing calendar and (via the existing hourly cron) to Airbnb — closing a gap where the app's existing "Add Block" UI has never actually reached the website.

**Architecture:** Extend the existing `DateRange` model with an optional note. Add `manual_blocked_dates` to the payload `WordPressSyncService.syncRentals` already sends — this field already exists on the WordPress side (`Cozumel-Website` theme) and is already merged into both the outbound `.ics` and the public availability REST endpoint, so no server-side changes are needed. Extract the credential-loading + sync-triggering logic that currently lives inline in `SidebarView` into a reusable `WebsiteSyncCoordinator`, so `PropertyInspectorView` can trigger the same sync automatically right after a block is added or removed, instead of only through Sidebar's toolbar button.

**Tech Stack:** Swift, SwiftUI (macOS 14+), Swift Testing (`import Testing`, `@Test`, `#expect`), XCTest via `xcodebuild test`.

**Spec:** `docs/superpowers/specs/2026-08-26-app-manual-blocked-dates-design.md`

## Global Constraints

- No `Cozumel-Website` / WordPress / PHP changes — this plan is Mac-app-only (spec: Non-Goals).
- `manual_blocked_dates` is the one field in `syncRentals` exempt from the blank/zero guard added in commit `1d77e67` — always send it, including `"[]"` for an empty list, never omit the key (spec: Sync Change).
- No general auto-sync-everything change — auto-sync is scoped to the add/remove-block action only (spec: Goals).
- A failed auto-sync must never fail silently — the block still saves locally, and the user sees a visible message (spec: Error Handling).
- Match existing code style: Swift Testing (`@Test`/`#expect`), not XCTest, for all new test files — matches every existing test file in `CozumelManagerTests`.

---

### Task 1: `DateRange` gains an optional note

**Files:**
- Modify: `CozumelManager/CozumelManager/Models/Property.swift:9-19`
- Test: `CozumelManager/CozumelManagerTests/CozumelManagerTests.swift`

**Interfaces:**
- Produces: `DateRange.note: String?` (nil-default), and `DateRange.init(id:start:end:note:)` with `note` defaulting to `nil` — every later task that constructs a `DateRange` uses this initializer.

- [ ] **Step 1: Write the failing tests**

Add to `struct PropertyModelTests` in `CozumelManager/CozumelManagerTests/CozumelManagerTests.swift`, right after the existing `dateRange_preserves_startAndEnd` test (currently ends at line 49):

```swift
    @Test func dateRange_preserves_note() {
        let start = Date(timeIntervalSinceReferenceDate: 1000)
        let end   = Date(timeIntervalSinceReferenceDate: 2000)
        let r = DateRange(start: start, end: end, note: "Family friend — cash booking")
        #expect(r.note == "Family friend — cash booking")
    }

    @Test func dateRange_note_defaultsToNil() {
        let start = Date(timeIntervalSinceReferenceDate: 1000)
        let end   = Date(timeIntervalSinceReferenceDate: 2000)
        let r = DateRange(start: start, end: end)
        #expect(r.note == nil)
    }

    @Test func dateRange_decodesLegacyJSON_missingNoteField() throws {
        let json = """
        {"id":"11111111-1111-1111-1111-111111111111","start":"2026-09-10T00:00:00Z","end":"2026-09-12T00:00:00Z"}
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let r = try decoder.decode(DateRange.self, from: json)
        #expect(r.note == nil)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project CozumelManager/CozumelManager.xcodeproj -scheme CozumelManager -destination 'platform=macOS' -only-testing:CozumelManagerTests/PropertyModelTests 2>&1 | tail -40`
Expected: FAIL — `DateRange` has no member `note`, and the `init(start:end:note:)` overload doesn't exist yet.

- [ ] **Step 3: Add `note` to `DateRange`**

In `CozumelManager/CozumelManager/Models/Property.swift`, replace:

```swift
struct DateRange: Codable, Identifiable {
    var id: UUID
    var start: Date
    var end: Date

    init(id: UUID = UUID(), start: Date, end: Date) {
        self.id = id
        self.start = start
        self.end = end
    }
}
```

with:

```swift
struct DateRange: Codable, Identifiable {
    var id: UUID
    var start: Date
    var end: Date
    var note: String?

    init(id: UUID = UUID(), start: Date, end: Date, note: String? = nil) {
        self.id = id
        self.start = start
        self.end = end
        self.note = note
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project CozumelManager/CozumelManager.xcodeproj -scheme CozumelManager -destination 'platform=macOS' -only-testing:CozumelManagerTests/PropertyModelTests 2>&1 | tail -40`
Expected: PASS — all `PropertyModelTests` cases, including the 3 new ones.

- [ ] **Step 5: Commit**

```bash
git add CozumelManager/CozumelManager/Models/Property.swift CozumelManager/CozumelManagerTests/CozumelManagerTests.swift
git commit -m "feat: add optional note to DateRange for manual blocked dates"
```

---

### Task 2: `syncRentals` sends `manual_blocked_dates`, exempt from the blank guard

**Files:**
- Modify: `CozumelManager/CozumelManager/Support/WordPressSyncService.swift`
- Test: `CozumelManager/CozumelManagerTests/WordPressSyncServiceTests.swift`

**Interfaces:**
- Consumes: `DateRange.note: String?` from Task 1.
- Produces: `WordPressSyncService` now sends a `"manual_blocked_dates"` key in every rental's `meta` payload — a JSON string, always present even when empty (`"[]"`). No new public API; this is internal to `syncRentals`.

- [ ] **Step 1: Write the failing tests**

Add to `struct WordPressSyncServiceTests` in `CozumelManager/CozumelManagerTests/WordPressSyncServiceTests.swift`. First, extend the existing `makeProperty` helper to accept blocked ranges:

```swift
    private func makeProperty(id: String = "prop-001", name: String = "Nah Ha 101", status: PropertyStatus = .active, unavailableDateRanges: [DateRange] = []) -> Property {
        Property(id: id, name: name, neighborhood: "North Shore", address: "123 Main St",
                  baseRate: 325, baseGuests: 2, maxGuests: 6, extraGuestFee: 25, status: status,
                  unavailableDateRanges: unavailableDateRanges)
    }
```

(This replaces the current `makeProperty` signature — it's additive, every existing call site keeps compiling since the new parameter defaults to `[]`.)

Then add three new test cases after `sync_rental_blankOrZeroLocalFields_omitsKeysInsteadOfClearingThem`:

```swift
    @Test func sync_rental_sendsManualBlockedDatesAsJSON_withNote() async {
        let client = MockWordPressAPIClient()
        client.postsByType["rental-property"] = [WordPressPost(id: 24, meta: .init(mac_id: "prop-001"))]
        let service = WordPressSyncService(apiClient: client)
        var components = DateComponents(calendar: .current)
        components.year = 2026; components.month = 9; components.day = 10
        let start = Calendar.current.date(from: components)!
        components.day = 12
        let end = Calendar.current.date(from: components)!
        let range = DateRange(start: start, end: end, note: "Family friend — cash booking")
        let results = await service.sync(properties: [makeProperty(unavailableDateRanges: [range])], forSaleProperties: [])
        #expect(results == [SyncResult(propertyName: "Nah Ha 101", outcome: .updated)])
        let meta = client.updatedPayloads[0].payload.meta["manual_blocked_dates"]
        #expect(meta == "[{\"end\":\"2026-09-12\",\"note\":\"Family friend — cash booking\",\"start\":\"2026-09-10\"}]")
    }

    @Test func sync_rental_blockWithoutNote_omitsNoteKeyFromJSON() async {
        let client = MockWordPressAPIClient()
        client.postsByType["rental-property"] = [WordPressPost(id: 24, meta: .init(mac_id: "prop-001"))]
        let service = WordPressSyncService(apiClient: client)
        var components = DateComponents(calendar: .current)
        components.year = 2026; components.month = 9; components.day = 10
        let start = Calendar.current.date(from: components)!
        components.day = 12
        let end = Calendar.current.date(from: components)!
        let range = DateRange(start: start, end: end)
        _ = await service.sync(properties: [makeProperty(unavailableDateRanges: [range])], forSaleProperties: [])
        let meta = client.updatedPayloads[0].payload.meta["manual_blocked_dates"]
        #expect(meta == "[{\"end\":\"2026-09-12\",\"start\":\"2026-09-10\"}]")
    }

    @Test func sync_rental_noBlockedDates_sendsEmptyArray_notOmitted() async {
        let client = MockWordPressAPIClient()
        client.postsByType["rental-property"] = [WordPressPost(id: 24, meta: .init(mac_id: "prop-001"))]
        let service = WordPressSyncService(apiClient: client)
        _ = await service.sync(properties: [makeProperty(unavailableDateRanges: [])], forSaleProperties: [])
        let meta = client.updatedPayloads[0].payload.meta["manual_blocked_dates"]
        #expect(meta == "[]")
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project CozumelManager/CozumelManager.xcodeproj -scheme CozumelManager -destination 'platform=macOS' -only-testing:CozumelManagerTests/WordPressSyncServiceTests 2>&1 | tail -60`
Expected: FAIL — `meta["manual_blocked_dates"]` is `nil` in all three new cases (key doesn't exist yet).

- [ ] **Step 3: Implement `manual_blocked_dates` in `syncRentals`**

In `CozumelManager/CozumelManager/Support/WordPressSyncService.swift`, add a private nested type and two private helpers inside `final class WordPressSyncService`, and one new unconditional line in `syncRentals`.

Add near the top of the class body (after the `init`):

```swift
    private struct ManualBlockedDateEntry: Encodable {
        let start: String
        let end: String
        let note: String?
    }

    private func manualBlockedDatesJSON(for ranges: [DateRange]) -> String {
        let calendar = Calendar.current
        let entries = ranges.map { range in
            ManualBlockedDateEntry(
                start: dateString(range.start, calendar: calendar),
                end: dateString(range.end, calendar: calendar),
                note: (range.note?.isEmpty ?? true) ? nil : range.note
            )
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(entries),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    private func dateString(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
```

Then in `syncRentals`, add one line to the `meta` dictionary construction — it must be **unconditional**, not wrapped in an `if`, unlike every other field in this function:

```swift
        for property in properties {
            var meta: [String: String] = [
                "mac_id": property.id,
                "status": property.status.rawValue
            ]
            meta["manual_blocked_dates"] = manualBlockedDatesJSON(for: property.unavailableDateRanges)
            if !property.neighborhood.isEmpty {
```

(Insert the new line directly after the `meta` dictionary literal, before the existing `if !property.neighborhood.isEmpty` guard — the rest of `syncRentals` is unchanged.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project CozumelManager/CozumelManager.xcodeproj -scheme CozumelManager -destination 'platform=macOS' -only-testing:CozumelManagerTests/WordPressSyncServiceTests 2>&1 | tail -60`
Expected: PASS — all `WordPressSyncServiceTests` cases, including the 3 new ones and all pre-existing ones (confirms the `makeProperty` signature change didn't break existing tests).

- [ ] **Step 5: Commit**

```bash
git add CozumelManager/CozumelManager/Support/WordPressSyncService.swift CozumelManager/CozumelManagerTests/WordPressSyncServiceTests.swift
git commit -m "feat: sync manual_blocked_dates unconditionally in syncRentals"
```

---

### Task 3: Extract `WebsiteSyncCoordinator`, migrate `SidebarView` to use it

**Files:**
- Create: `CozumelManager/CozumelManager/Support/WebsiteSyncCoordinator.swift`
- Create: `CozumelManager/CozumelManagerTests/WebsiteSyncCoordinatorTests.swift`
- Modify: `CozumelManager/CozumelManager/Views/SidebarView.swift:127-150`

**Interfaces:**
- Consumes: `WordPressSyncCredentialsStore.load() -> WordPressSyncCredentials?` (existing), `WordPressSyncService.sync(properties:forSaleProperties:) async -> [SyncResult]` (existing), `MockWordPressAPIClient` (existing test double from `WordPressSyncServiceTests.swift`, internal visibility, reusable here).
- Produces: `protocol WordPressCredentialsProviding { func load() -> WordPressSyncCredentials? }`, `enum WebsiteSyncAttempt: Equatable { case success([SyncResult]); case missingCredentials }`, `enum WebsiteSyncCoordinator { static func sync(properties: [Property], forSaleProperties: [ForSaleProperty], credentialsStore: WordPressCredentialsProviding = WordPressSyncCredentialsStore(), makeClient: (WordPressSyncCredentials, URL) -> WordPressAPIClient = <default>) async -> WebsiteSyncAttempt }` — Task 4 calls this exact function.

- [ ] **Step 1: Write the failing tests**

Create `CozumelManager/CozumelManagerTests/WebsiteSyncCoordinatorTests.swift`:

```swift
import Foundation
import Testing
@testable import CozumelManager

private struct StubCredentialsStore: WordPressCredentialsProviding {
    let credentials: WordPressSyncCredentials?
    func load() -> WordPressSyncCredentials? { credentials }
}

struct WebsiteSyncCoordinatorTests {
    @Test func sync_returnsMissingCredentials_whenStoreHasNone() async {
        let store = StubCredentialsStore(credentials: nil)
        let attempt = await WebsiteSyncCoordinator.sync(
            properties: [], forSaleProperties: [], credentialsStore: store
        )
        #expect(attempt == .missingCredentials)
    }

    @Test func sync_returnsMissingCredentials_whenSiteURLIsInvalid() async {
        let store = StubCredentialsStore(
            credentials: WordPressSyncCredentials(siteURL: "", username: "u", applicationPassword: "p")
        )
        let attempt = await WebsiteSyncCoordinator.sync(
            properties: [], forSaleProperties: [], credentialsStore: store
        )
        #expect(attempt == .missingCredentials)
    }

    @Test func sync_delegatesToService_andReturnsResults() async {
        let credentials = WordPressSyncCredentials(siteURL: "https://example.com", username: "u", applicationPassword: "p")
        let store = StubCredentialsStore(credentials: credentials)
        let client = MockWordPressAPIClient()
        client.postsByType["rental-property"] = []
        client.postsByType["forsale-property"] = []
        let property = Property(id: "prop-001", name: "Nah Ha 101", neighborhood: "N", address: "A", baseRate: 100, status: .active)
        let attempt = await WebsiteSyncCoordinator.sync(
            properties: [property],
            forSaleProperties: [],
            credentialsStore: store,
            makeClient: { _, _ in client }
        )
        guard case .success(let results) = attempt else {
            Issue.record("Expected .success outcome")
            return
        }
        #expect(results == [SyncResult(propertyName: "Nah Ha 101", outcome: .created)])
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project CozumelManager/CozumelManager.xcodeproj -scheme CozumelManager -destination 'platform=macOS' -only-testing:CozumelManagerTests/WebsiteSyncCoordinatorTests 2>&1 | tail -60`
Expected: FAIL to build — `WordPressCredentialsProviding`, `WebsiteSyncAttempt`, and `WebsiteSyncCoordinator` don't exist yet.

- [ ] **Step 3: Create `WebsiteSyncCoordinator.swift`**

Create `CozumelManager/CozumelManager/Support/WebsiteSyncCoordinator.swift`:

```swift
import Foundation

protocol WordPressCredentialsProviding {
    func load() -> WordPressSyncCredentials?
}

extension WordPressSyncCredentialsStore: WordPressCredentialsProviding {}

enum WebsiteSyncAttempt: Equatable {
    case success([SyncResult])
    case missingCredentials
}

enum WebsiteSyncCoordinator {
    static func sync(
        properties: [Property],
        forSaleProperties: [ForSaleProperty],
        credentialsStore: WordPressCredentialsProviding = WordPressSyncCredentialsStore(),
        makeClient: (WordPressSyncCredentials, URL) -> WordPressAPIClient = { credentials, baseURL in
            URLSessionWordPressAPIClient(
                baseURL: baseURL,
                username: credentials.username,
                applicationPassword: credentials.applicationPassword
            )
        }
    ) async -> WebsiteSyncAttempt {
        guard let credentials = credentialsStore.load(),
              let baseURL = URL(string: credentials.siteURL) else {
            return .missingCredentials
        }
        let client = makeClient(credentials, baseURL)
        let service = WordPressSyncService(apiClient: client)
        let results = await service.sync(properties: properties, forSaleProperties: forSaleProperties)
        return .success(results)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project CozumelManager/CozumelManager.xcodeproj -scheme CozumelManager -destination 'platform=macOS' -only-testing:CozumelManagerTests/WebsiteSyncCoordinatorTests 2>&1 | tail -60`
Expected: PASS — all 3 cases.

- [ ] **Step 5: Migrate `SidebarView.performSync()` to use the coordinator**

In `CozumelManager/CozumelManager/Views/SidebarView.swift`, replace the entire `performSync()` function (currently lines 127-150):

```swift
    private func performSync() {
        guard let credentials = WordPressSyncCredentialsStore().load(),
              let baseURL = URL(string: credentials.siteURL) else {
            showSyncSettings = true
            return
        }
        isSyncing = true
        let client = URLSessionWordPressAPIClient(
            baseURL: baseURL,
            username: credentials.username,
            applicationPassword: credentials.applicationPassword
        )
        let service = WordPressSyncService(apiClient: client)
        let propertiesSnapshot = store.properties
        let forSalePropertiesSnapshot = forSaleStore.properties
        Task {
            let results = await service.sync(properties: propertiesSnapshot, forSaleProperties: forSalePropertiesSnapshot)
            await MainActor.run {
                syncResults = results
                isSyncing = false
                showSyncResults = true
            }
        }
    }
```

with:

```swift
    private func performSync() {
        isSyncing = true
        let propertiesSnapshot = store.properties
        let forSalePropertiesSnapshot = forSaleStore.properties
        Task {
            let attempt = await WebsiteSyncCoordinator.sync(properties: propertiesSnapshot, forSaleProperties: forSalePropertiesSnapshot)
            await MainActor.run {
                isSyncing = false
                switch attempt {
                case .success(let results):
                    syncResults = results
                    showSyncResults = true
                case .missingCredentials:
                    showSyncSettings = true
                }
            }
        }
    }
```

This preserves the exact same observable behavior (missing credentials opens the settings sheet, otherwise shows the results sheet) — it's a pure delegation refactor.

- [ ] **Step 6: Build and manually verify Sidebar sync still works**

Run: `xcodebuild -project CozumelManager/CozumelManager.xcodeproj -scheme CozumelManager -configuration Debug -derivedDataPath /tmp/cozumel_build_check build 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`

Then launch the built app (`open -n /tmp/cozumel_build_check/Build/Products/Debug/CozumelManager.app`), click the toolbar Sync menu → "Sync to Website", and confirm it behaves exactly as before this task (opens Website Sync Settings if no credentials are configured on this Mac, otherwise shows the sync results sheet).

- [ ] **Step 7: Commit**

```bash
git add CozumelManager/CozumelManager/Support/WebsiteSyncCoordinator.swift CozumelManager/CozumelManagerTests/WebsiteSyncCoordinatorTests.swift CozumelManager/CozumelManager/Views/SidebarView.swift
git commit -m "refactor: extract WebsiteSyncCoordinator, migrate SidebarView to use it"
```

---

### Task 4: `PropertyInspectorView` — note field, auto-sync on block change, failure banner

**Files:**
- Modify: `CozumelManager/CozumelManager/Views/PropertyInspectorView.swift`

**Interfaces:**
- Consumes: `DateRange.init(id:start:end:note:)` (Task 1), `WebsiteSyncCoordinator.sync(properties:forSaleProperties:) async -> WebsiteSyncAttempt` (Task 3), `ForSaleStore` (existing, already provided as an environment object at the app root — confirmed reachable from this view's position in `MainDashboardView`).

- [ ] **Step 1: Add the `ForSaleStore` environment object and banner state**

In `CozumelManager/CozumelManager/Views/PropertyInspectorView.swift`, in the property declarations at the top of `PropertyInspectorView` (currently lines 6-11), add:

```swift
struct PropertyInspectorView: View {
    @EnvironmentObject private var store: PropertyStore
    @EnvironmentObject private var forSaleStore: ForSaleStore
    let property: Property
    @State private var draft: Property
    @State private var showAddBlock = false
    @State private var blockStart = Date()
    @State private var blockEnd = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
    @State private var blockNote = ""
    @State private var syncFailureMessage: String?
```

(Only `forSaleStore`, `blockNote`, and `syncFailureMessage` are new — the rest is existing code shown for placement context.)

- [ ] **Step 2: Add the note field to the "Add Block" popover**

Locate the popover body (currently around lines 203-224):

```swift
            .popover(isPresented: $showAddBlock, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Block Dates").font(.headline)
                    DatePicker("From", selection: $blockStart, displayedComponents: .date)
                    DatePicker("To", selection: $blockEnd, displayedComponents: .date)
                    HStack {
                        Spacer()
                        Button("Cancel") { showAddBlock = false }
                        Button("Add") {
                            draft.unavailableDateRanges.append(
                                DateRange(start: blockStart, end: blockEnd)
                            )
                            commit()
                            showAddBlock = false
                        }
                        .disabled(blockEnd <= blockStart)
                        .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(16)
                .frame(width: 280)
            }
```

Replace it with:

```swift
            .popover(isPresented: $showAddBlock, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Block Dates").font(.headline)
                    DatePicker("From", selection: $blockStart, displayedComponents: .date)
                    DatePicker("To", selection: $blockEnd, displayedComponents: .date)
                    TextField("Reason (optional)", text: $blockNote)
                    HStack {
                        Spacer()
                        Button("Cancel") { showAddBlock = false }
                        Button("Add") {
                            let note = blockNote.trimmingCharacters(in: .whitespaces)
                            draft.unavailableDateRanges.append(
                                DateRange(start: blockStart, end: blockEnd, note: note.isEmpty ? nil : note)
                            )
                            commit()
                            blockNote = ""
                            showAddBlock = false
                            triggerAutoSync()
                        }
                        .disabled(blockEnd <= blockStart)
                        .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(16)
                .frame(width: 280)
            }
```

- [ ] **Step 3: Show the note in the blocked-dates list, and auto-sync on removal**

Locate the list rendering (currently around lines 180-196):

```swift
                ForEach(draft.unavailableDateRanges) { range in
                    HStack {
                        Text("\(range.start.formatted(date: .abbreviated, time: .omitted)) – \(range.end.formatted(date: .abbreviated, time: .omitted))")
                            .font(.callout)
                        Spacer()
                        Button {
                            draft.unavailableDateRanges.removeAll { $0.id == range.id }
                            commit()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
```

Replace it with:

```swift
                ForEach(draft.unavailableDateRanges) { range in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(range.start.formatted(date: .abbreviated, time: .omitted)) – \(range.end.formatted(date: .abbreviated, time: .omitted))")
                                .font(.callout)
                            if let note = range.note, !note.isEmpty {
                                Text(note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button {
                            draft.unavailableDateRanges.removeAll { $0.id == range.id }
                            commit()
                            triggerAutoSync()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
```

- [ ] **Step 4: Show the failure banner, and add `triggerAutoSync()`**

In `availabilitySection` (starts around line 174), add the banner as the first element inside `Section("Availability")`:

```swift
    private var availabilitySection: some View {
        Section("Availability") {
            if let message = syncFailureMessage {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
            if draft.unavailableDateRanges.isEmpty {
```

(Only the new `if let message = syncFailureMessage { ... }` block is added — everything from `if draft.unavailableDateRanges.isEmpty` onward is existing code, unchanged.)

Then add the `triggerAutoSync()` method near `commit()` (currently line 36-38):

```swift
    private func commit() {
        store.update(draft)
    }

    private func triggerAutoSync() {
        let propertiesSnapshot = store.properties
        let forSalePropertiesSnapshot = forSaleStore.properties
        let propertyName = draft.name
        Task {
            let attempt = await WebsiteSyncCoordinator.sync(properties: propertiesSnapshot, forSaleProperties: forSalePropertiesSnapshot)
            await MainActor.run {
                switch attempt {
                case .success(let results):
                    if let failure = results.first(where: { $0.propertyName == propertyName }),
                       case .failed(let message) = failure.outcome {
                        syncFailureMessage = "Saved locally — not yet synced to the website (\(message)). Try Sync to Website again once you're online."
                    } else {
                        syncFailureMessage = nil
                    }
                case .missingCredentials:
                    syncFailureMessage = "Saved locally — not yet synced to the website (no sync credentials configured on this Mac). Open Website Sync Settings, then try Sync to Website again."
                }
            }
        }
    }
```

- [ ] **Step 5: Build**

Run: `xcodebuild -project CozumelManager/CozumelManager.xcodeproj -scheme CozumelManager -configuration Debug -derivedDataPath /tmp/cozumel_build_check build 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Run the full test suite**

Run: `xcodebuild test -project CozumelManager/CozumelManager.xcodeproj -scheme CozumelManager -destination 'platform=macOS' 2>&1 | tail -80`
Expected: All tests pass, including every test added in Tasks 1-3 plus all pre-existing tests (confirms nothing in this task's changes broke prior behavior).

- [ ] **Step 7: Manual GUI verification**

This view's behavior (popover interaction, banner visibility) isn't covered by this codebase's test suite — no other `PropertyInspectorView`-level UI tests exist, consistent with this project's established manual-verification convention (see `CLAUDE.md`, "Manual GUI Verification"). Launch the built app (`open -n /tmp/cozumel_build_check/Build/Products/Debug/CozumelManager.app`) and confirm, on a property with valid sync credentials configured:

1. Open a rental property, go to its Availability section, click "Add Block".
2. Fill in dates and a reason, click "Add" — the block appears in the list with the note shown beneath the date range, and no failure banner appears (assuming credentials are valid and the site is reachable).
3. Click the trash icon on that block — it's removed from the list, and no failure banner appears.
4. Temporarily clear this Mac's sync credentials (toolbar Sync menu → Website Sync Settings…, clear the fields, save), then add another block — confirm the orange failure banner appears with the "no sync credentials configured" message, and the block still shows in the local list. Restore the credentials afterward.

- [ ] **Step 8: Commit**

```bash
git add CozumelManager/CozumelManager/Views/PropertyInspectorView.swift
git commit -m "feat: add note field and auto-sync to manual date blocking"
```

---

## Post-Implementation

Once all 4 tasks are committed, this closes the gap described in the spec: the app's existing "Add Block" feature now actually reaches the website and (via the existing hourly cron) Airbnb. Remaining spec-listed prerequisite, not part of this plan: confirming Kelley's own Mac has valid Website Sync Settings credentials saved — that's a one-time manual step on her machine, not a code change.
