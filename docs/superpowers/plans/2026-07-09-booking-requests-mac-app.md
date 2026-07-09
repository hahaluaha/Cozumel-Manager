# Booking Requests — Mac App Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "Booking Requests" section to the Mac app — nav restructure, list/detail views, invoice line-item calculation, approve/deny actions, and a local `booking-requests.json` data store — as the Mac-app-only slice of the full booking workflow spec.

**Architecture:** Mirrors the existing `PropertyStore`/`ForSaleStore` pattern: a new `BookingRequestStore: ObservableObject` loads/saves `booking-requests.json` in the sandboxed Application Support directory and watches it for external writes via `DispatchSource`. The main nav restructures from a single `NavigationSplitView` into a top-level `AppSection` picker (Properties / Booking Requests) feeding a 3-column split. This slice defines the `booking-requests.json` schema as the contract the future WordPress CPT + Python sync daemon (separate, out-of-repo plans) must write to — no daemon exists yet, so `invoiced`/`paid`/Stripe-link states can be displayed but nothing outside this app will ever produce them until that daemon ships.

**Tech Stack:** SwiftUI (macOS 14+), Swift Testing (`import Testing`, `@Test`, `#expect`) for unit tests, JSONEncoder/Decoder with `.iso8601` date strategy, Xcode 16 file-system-synchronized project groups (no manual `.pbxproj` edits needed for new files).

## Global Constraints

- Target macOS 14+, native SwiftUI — no new dependencies.
- All new unit tests use the **Swift Testing** framework (`import Testing`, `@Test func ...()`, `#expect(...)`) — matches `CozumelManagerTests.swift`; do not use XCTest for model/store tests.
- JSON keys are snake_case via explicit `CodingKeys`; dates encode/decode with `JSONEncoder/Decoder.dateEncodingStrategy/dateDecodingStrategy = .iso8601` — matches `Property.swift` and `PropertyModel.swift`.
- `.onChange(of:)` does not fire on this Xcode 26 beta / macOS 26.5 SDK toolchain (confirmed project-wide bug). Never rely on it for logic in new code — use `Button` actions or two-way `Binding` mutation instead (this plan does not introduce any `.onChange` usage).
- New Swift/JSON files just need to be created inside the existing `CozumelManager/CozumelManager/` (or `.../Models/`, `.../Views/`) and `CozumelManager/CozumelManagerTests/` folders — the project uses Xcode's file-system-synchronized groups, so files are picked up automatically; no `.pbxproj` editing.
- This plan is **Mac-app-only**. It does not touch WordPress, the Python sync daemon, or Stripe — those are separate plans, not yet scheduled, living outside this repo. `booking-requests.json`'s schema (defined in Task 1) is the interface contract they must eventually match.
- No auto-booking, auto-routing, guest messaging, or staff scheduling beyond what's explicitly built here (per root `CLAUDE.md`) — not a concern for this slice since it has no outbound guest communication except a manually-triggered, Kelley-authored `mailto:` draft on deny.

---

## File Structure

**Create:**
- `CozumelManager/CozumelManager/Models/BookingRequest.swift` — `BookingStatus`, `InvoiceLineItem`, `BookingRequest` model + pure static helpers (date-overlap check, list sorting, invoice auto-fill).
- `CozumelManager/CozumelManager/Models/BookingRequestStore.swift` — `ObservableObject` store: load/save, hold-expiry reversion, conflict detection, file watching, approve/deny/send actions.
- `CozumelManager/CozumelManager/booking-requests.json` — bundled empty-array fixture, seeds a fresh container on first launch (same pattern as `properties.json`).
- `CozumelManager/CozumelManager/Views/BookingRequestsListView.swift` — list column, pending-first ordering, status badges.
- `CozumelManager/CozumelManager/Views/BookingRequestDetailView.swift` — guest info, conflict warnings, approve/deny actions.
- `CozumelManager/CozumelManager/Views/InvoiceEditorView.swift` — editable line-item table, live total, send action.
- `CozumelManager/CozumelManagerTests/BookingRequestTests.swift` — model + pure-function tests.
- `CozumelManager/CozumelManagerTests/BookingRequestStoreTests.swift` — store tests.

**Modify:**
- `CozumelManager/CozumelManager/CozumelManagerApp.swift` — add `BookingRequestStore` as a `@StateObject`/`environmentObject`.
- `CozumelManager/CozumelManager/Views/MainDashboardView.swift` — restructure into a 3-column `NavigationSplitView` with a top-level `AppSection` (Properties / Booking Requests) sidebar.

---

## Task 1: BookingRequest data model

**Files:**
- Create: `CozumelManager/CozumelManager/Models/BookingRequest.swift`
- Test: `CozumelManager/CozumelManagerTests/BookingRequestTests.swift`

**Interfaces:**
- Produces: `enum BookingStatus: String, Codable { pending, approved, denied, invoiceSending = "invoice_sending", invoiced, paid }`; `struct InvoiceLineItem: Identifiable, Codable, Hashable` (`id: UUID`, `itemDescription: String`, `quantity: Int`, `unitAmount: Double`, computed `total: Double`); `struct BookingRequest: Identifiable, Codable, Hashable` with fields listed below; `BookingRequest.dateRangesOverlap(_:_:_:_:) -> Bool`; `BookingRequest.sortedForList(_:) -> [BookingRequest]`; `BookingRequest.autoLineItems(for:property:) -> [InvoiceLineItem]`.

**Deviation from spec, called out explicitly:** adds a `submittedAt: Date` field (`submitted_at` in JSON) not listed in the spec's Data Model section. It's required to give "oldest-pending first" / "most recent first" (Mac App UI section) any meaning — there's no other timestamp to sort by. This is a single submission timestamp for queue ordering, not the per-status-transition timestamps the spec's Out of Scope section explicitly rejected ("a simple status enum was chosen over status + timestamps" refers to response-time analytics, a different concern). The future WordPress CPT should populate this from the post's creation date.

- [ ] **Step 1: Write the failing tests**

Create `CozumelManager/CozumelManagerTests/BookingRequestTests.swift`:

```swift
import Foundation
import Testing
@testable import CozumelManager

private func makeRequest(
    id: String = "r1",
    propertyId: String = "prop-003",
    start: Date = Date(timeIntervalSinceReferenceDate: 0),
    end: Date = Date(timeIntervalSinceReferenceDate: 86400 * 3),
    guestCount: Int = 2,
    submittedAt: Date = Date(timeIntervalSinceReferenceDate: 0),
    status: BookingStatus = .pending
) -> BookingRequest {
    BookingRequest(
        id: id, fullName: "Guest", email: "guest@example.com",
        state: "CA", country: "USA", propertyId: propertyId,
        startDate: start, endDate: end, guestCount: guestCount,
        notes: "", submittedAt: submittedAt, status: status
    )
}

struct BookingRequestTests {

    @Test func bookingRequest_roundtrips_throughCodable() throws {
        let original = makeRequest()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(BookingRequest.self, from: data)
        #expect(decoded.id == "r1")
        #expect(decoded.fullName == "Guest")
        #expect(decoded.status == .pending)
        #expect(decoded.invoiceLineItems.isEmpty)
        #expect(decoded.holdExpiresAt == nil)
    }

    @Test func bookingRequest_decodesSnakeCaseKeys() throws {
        let json = """
        {"id":"r1","full_name":"Guest","email":"g@example.com","state":"CA","country":"USA",
         "property_id":"prop-003","start_date":"2026-08-01T00:00:00Z","end_date":"2026-08-04T00:00:00Z",
         "guest_count":2,"notes":"","submitted_at":"2026-07-01T00:00:00Z","status":"invoice_sending"}
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(BookingRequest.self, from: json)
        #expect(decoded.propertyId == "prop-003")
        #expect(decoded.guestCount == 2)
        #expect(decoded.status == .invoiceSending)
    }

    @Test func invoiceLineItem_total_multipliesQuantityByAmount() {
        let item = InvoiceLineItem(itemDescription: "Nightly rate", quantity: 3, unitAmount: 325.0)
        #expect(item.total == 975.0)
    }

    @Test func dateRangesOverlap_trueForOverlappingRanges() {
        let aStart = Date(timeIntervalSinceReferenceDate: 0)
        let aEnd = Date(timeIntervalSinceReferenceDate: 10)
        let bStart = Date(timeIntervalSinceReferenceDate: 5)
        let bEnd = Date(timeIntervalSinceReferenceDate: 15)
        #expect(BookingRequest.dateRangesOverlap(aStart, aEnd, bStart, bEnd))
    }

    @Test func dateRangesOverlap_falseForAdjacentRanges() {
        let aStart = Date(timeIntervalSinceReferenceDate: 0)
        let aEnd = Date(timeIntervalSinceReferenceDate: 10)
        let bStart = Date(timeIntervalSinceReferenceDate: 10)
        let bEnd = Date(timeIntervalSinceReferenceDate: 20)
        #expect(!BookingRequest.dateRangesOverlap(aStart, aEnd, bStart, bEnd))
    }

    @Test func sortedForList_pendingFirst_oldestPendingOnTop_restNewestFirst() {
        let oldPending = makeRequest(id: "p-old", submittedAt: Date(timeIntervalSinceReferenceDate: 0), status: .pending)
        let newPending = makeRequest(id: "p-new", submittedAt: Date(timeIntervalSinceReferenceDate: 1000), status: .pending)
        let oldApproved = makeRequest(id: "a-old", submittedAt: Date(timeIntervalSinceReferenceDate: 100), status: .approved)
        let newApproved = makeRequest(id: "a-new", submittedAt: Date(timeIntervalSinceReferenceDate: 2000), status: .approved)

        let sorted = BookingRequest.sortedForList([newApproved, oldPending, oldApproved, newPending])
        #expect(sorted.map(\.id) == ["p-old", "p-new", "a-new", "a-old"])
    }

    @Test func autoLineItems_computesNightsTimesNightlyRate() {
        let property = Property(
            id: "prop-003", name: "Nah Ha 101", neighborhood: "N", address: "A",
            baseRate: 325.0, baseGuests: 2, maxGuests: 6, extraGuestFee: 25.0, status: .active
        )
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let end = start.addingTimeInterval(86400 * 3)
        let request = makeRequest(start: start, end: end, guestCount: 4)
        let items = BookingRequest.autoLineItems(for: request, property: property)
        #expect(items.count == 1)
        #expect(items[0].quantity == 3)
        #expect(items[0].unitAmount == 375.0)
        #expect(items[0].total == 1125.0)
    }

    @Test func autoLineItems_returnsEmpty_whenNightsIsZeroOrNegative() {
        let property = Property(id: "p1", name: "Casa", neighborhood: "N", address: "A", baseRate: 250.0, status: .active)
        let sameDay = Date(timeIntervalSinceReferenceDate: 0)
        let request = makeRequest(start: sameDay, end: sameDay)
        #expect(BookingRequest.autoLineItems(for: request, property: property).isEmpty)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project CozumelManager/CozumelManager.xcodeproj -scheme CozumelManager -destination 'platform=macOS' -only-testing:CozumelManagerTests/BookingRequestTests`
Expected: FAIL — `BookingRequest`, `BookingStatus`, `InvoiceLineItem` not found in scope.

- [ ] **Step 3: Implement the model**

Create `CozumelManager/CozumelManager/Models/BookingRequest.swift`:

```swift
import Foundation

enum BookingStatus: String, Codable {
    case pending
    case approved
    case denied
    case invoiceSending = "invoice_sending"
    case invoiced
    case paid
}

struct InvoiceLineItem: Identifiable, Codable, Hashable {
    var id: UUID
    var itemDescription: String
    var quantity: Int
    var unitAmount: Double

    init(id: UUID = UUID(), itemDescription: String, quantity: Int, unitAmount: Double) {
        self.id = id
        self.itemDescription = itemDescription
        self.quantity = quantity
        self.unitAmount = unitAmount
    }

    var total: Double { Double(quantity) * unitAmount }

    enum CodingKeys: String, CodingKey {
        case id
        case itemDescription = "description"
        case quantity
        case unitAmount = "unit_amount"
    }
}

struct BookingRequest: Identifiable, Codable, Hashable {
    var id: String
    var fullName: String
    var email: String
    var state: String
    var country: String
    var propertyId: String
    var startDate: Date
    var endDate: Date
    var guestCount: Int
    var notes: String
    var submittedAt: Date
    var status: BookingStatus
    var invoiceAmount: Double?
    var invoiceLineItems: [InvoiceLineItem]
    var stripePaymentLink: String?
    var stripePaymentStatus: String?
    var invoiceError: String?
    var holdExpiresAt: Date?

    init(
        id: String, fullName: String, email: String, state: String, country: String,
        propertyId: String, startDate: Date, endDate: Date, guestCount: Int, notes: String,
        submittedAt: Date, status: BookingStatus = .pending,
        invoiceAmount: Double? = nil, invoiceLineItems: [InvoiceLineItem] = [],
        stripePaymentLink: String? = nil, stripePaymentStatus: String? = nil,
        invoiceError: String? = nil, holdExpiresAt: Date? = nil
    ) {
        self.id = id
        self.fullName = fullName
        self.email = email
        self.state = state
        self.country = country
        self.propertyId = propertyId
        self.startDate = startDate
        self.endDate = endDate
        self.guestCount = guestCount
        self.notes = notes
        self.submittedAt = submittedAt
        self.status = status
        self.invoiceAmount = invoiceAmount
        self.invoiceLineItems = invoiceLineItems
        self.stripePaymentLink = stripePaymentLink
        self.stripePaymentStatus = stripePaymentStatus
        self.invoiceError = invoiceError
        self.holdExpiresAt = holdExpiresAt
    }

    enum CodingKeys: String, CodingKey {
        case id, email, state, country, notes, status
        case fullName = "full_name"
        case propertyId = "property_id"
        case startDate = "start_date"
        case endDate = "end_date"
        case guestCount = "guest_count"
        case submittedAt = "submitted_at"
        case invoiceAmount = "invoice_amount"
        case invoiceLineItems = "invoice_line_items"
        case stripePaymentLink = "stripe_payment_link"
        case stripePaymentStatus = "stripe_payment_status"
        case invoiceError = "invoice_error"
        case holdExpiresAt = "hold_expires_at"
    }

    static func dateRangesOverlap(_ aStart: Date, _ aEnd: Date, _ bStart: Date, _ bEnd: Date) -> Bool {
        aStart < bEnd && bStart < aEnd
    }

    static func sortedForList(_ requests: [BookingRequest]) -> [BookingRequest] {
        let pending = requests.filter { $0.status == .pending }
            .sorted { $0.submittedAt < $1.submittedAt }
        let rest = requests.filter { $0.status != .pending }
            .sorted { $0.submittedAt > $1.submittedAt }
        return pending + rest
    }

    static func autoLineItems(for request: BookingRequest, property: Property) -> [InvoiceLineItem] {
        let nights = Calendar.current.dateComponents([.day], from: request.startDate, to: request.endDate).day ?? 0
        guard nights > 0 else { return [] }
        let rate = property.nightlyRate(forGuests: request.guestCount)
        return [InvoiceLineItem(itemDescription: "Nightly rate", quantity: nights, unitAmount: rate)]
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project CozumelManager/CozumelManager.xcodeproj -scheme CozumelManager -destination 'platform=macOS' -only-testing:CozumelManagerTests/BookingRequestTests`
Expected: PASS (8 tests)

- [ ] **Step 5: Commit**

```bash
git add CozumelManager/CozumelManager/Models/BookingRequest.swift CozumelManager/CozumelManagerTests/BookingRequestTests.swift
git commit -m "feat: add BookingRequest data model"
```

---

## Task 2: BookingRequestStore — load/save

**Files:**
- Create: `CozumelManager/CozumelManager/Models/BookingRequestStore.swift`
- Create: `CozumelManager/CozumelManager/booking-requests.json`
- Test: `CozumelManager/CozumelManagerTests/BookingRequestStoreTests.swift`

**Interfaces:**
- Consumes: `BookingRequest` (Task 1).
- Produces: `class BookingRequestStore: ObservableObject` with `@Published var requests: [BookingRequest]`, `let storeURL: URL`, `init(storeURL: URL? = nil)`, `func load()`, `func saveToDisk()`.

- [ ] **Step 1: Create the bundled empty fixture**

Create `CozumelManager/CozumelManager/booking-requests.json`:

```json
{
  "requests": []
}
```

- [ ] **Step 2: Write the failing tests**

Create `CozumelManager/CozumelManagerTests/BookingRequestStoreTests.swift`:

```swift
import Foundation
import Testing
@testable import CozumelManager

func makeStoreRequest(
    id: String = "r1",
    propertyId: String = "prop-003",
    start: Date = Date(timeIntervalSinceReferenceDate: 0),
    end: Date = Date(timeIntervalSinceReferenceDate: 86400 * 3),
    guestCount: Int = 2,
    submittedAt: Date = Date(timeIntervalSinceReferenceDate: 0),
    status: BookingStatus = .pending,
    holdExpiresAt: Date? = nil
) -> BookingRequest {
    BookingRequest(
        id: id, fullName: "Guest", email: "guest@example.com",
        state: "CA", country: "USA", propertyId: propertyId,
        startDate: start, endDate: end, guestCount: guestCount,
        notes: "", submittedAt: submittedAt, status: status,
        holdExpiresAt: holdExpiresAt
    )
}

private struct BookingRequestListWire: Encodable {
    var requests: [BookingRequest]
}

private func writeFixture(_ requests: [BookingRequest], to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(BookingRequestListWire(requests: requests))
    try data.write(to: url)
}

private func makeTempStoreURL() -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("booking-requests.json")
}

struct BookingRequestStoreTests {

    @Test func store_loadsRequests_fromURL() throws {
        let url = makeTempStoreURL()
        try writeFixture([makeStoreRequest()], to: url)
        let store = BookingRequestStore(storeURL: url)
        #expect(store.requests.count == 1)
        #expect(store.requests[0].id == "r1")
    }

    @Test func store_saveToDisk_persistsAcrossReload() throws {
        let url = makeTempStoreURL()
        try writeFixture([], to: url)
        let store = BookingRequestStore(storeURL: url)
        store.requests = [makeStoreRequest()]
        store.saveToDisk()

        let reloaded = BookingRequestStore(storeURL: url)
        #expect(reloaded.requests.count == 1)
        #expect(reloaded.requests[0].id == "r1")
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `xcodebuild test -project CozumelManager/CozumelManager.xcodeproj -scheme CozumelManager -destination 'platform=macOS' -only-testing:CozumelManagerTests/BookingRequestStoreTests`
Expected: FAIL — `BookingRequestStore` not found in scope.

- [ ] **Step 4: Implement the store's load/save**

Create `CozumelManager/CozumelManager/Models/BookingRequestStore.swift`:

```swift
import Foundation
import Combine

private struct BookingRequestList: Codable {
    var requests: [BookingRequest]
}

class BookingRequestStore: ObservableObject {
    @Published var requests: [BookingRequest] = []

    let storeURL: URL

    init(storeURL: URL? = nil) {
        self.storeURL = storeURL ?? BookingRequestStore.defaultStoreURL()
        load()
    }

    private static func defaultStoreURL() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let appDir = appSupport.appendingPathComponent("CozumelManager")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("booking-requests.json")
    }

    private func migrateFromBundle() {
        guard let src = Bundle.main.url(forResource: "booking-requests", withExtension: "json") else { return }
        try? FileManager.default.copyItem(at: src, to: storeURL)
    }

    func load() {
        if !FileManager.default.fileExists(atPath: storeURL.path) {
            migrateFromBundle()
        }
        guard let data = try? Data(contentsOf: storeURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let list = try? decoder.decode(BookingRequestList.self, from: data) else { return }
        requests = list.requests
    }

    func saveToDisk() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(BookingRequestList(requests: requests)) else { return }
        try? data.write(to: storeURL)
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `xcodebuild test -project CozumelManager/CozumelManager.xcodeproj -scheme CozumelManager -destination 'platform=macOS' -only-testing:CozumelManagerTests/BookingRequestStoreTests`
Expected: PASS (2 tests)

- [ ] **Step 6: Commit**

```bash
git add CozumelManager/CozumelManager/Models/BookingRequestStore.swift CozumelManager/CozumelManager/booking-requests.json CozumelManager/CozumelManagerTests/BookingRequestStoreTests.swift
git commit -m "feat: add BookingRequestStore load/save"
```

---

## Task 3: Hold-expiry reversion

**Files:**
- Modify: `CozumelManager/CozumelManager/Models/BookingRequestStore.swift`
- Test: `CozumelManager/CozumelManagerTests/BookingRequestStoreTests.swift`

**Interfaces:**
- Consumes: `BookingRequest.holdExpiresAt`, `.status` (Task 1).
- Produces: `BookingRequestStore.revertExpiredHolds()`, called automatically at the end of `load()`.

- [ ] **Step 1: Write the failing tests**

Append to `CozumelManager/CozumelManagerTests/BookingRequestStoreTests.swift`, inside `struct BookingRequestStoreTests { ... }`:

```swift
    @Test func store_revertsExpiredHold_toPending_onLoad() throws {
        let url = makeTempStoreURL()
        let expired = makeStoreRequest(status: .approved, holdExpiresAt: Date(timeIntervalSinceNow: -3600))
        try writeFixture([expired], to: url)
        let store = BookingRequestStore(storeURL: url)
        #expect(store.requests[0].status == .pending)
        #expect(store.requests[0].holdExpiresAt == nil)
    }

    @Test func store_keepsActiveHold_untilExpiry() throws {
        let url = makeTempStoreURL()
        let active = makeStoreRequest(status: .approved, holdExpiresAt: Date(timeIntervalSinceNow: 3600))
        try writeFixture([active], to: url)
        let store = BookingRequestStore(storeURL: url)
        #expect(store.requests[0].status == .approved)
        #expect(store.requests[0].holdExpiresAt != nil)
    }

    @Test func store_revertedHold_persistsToDisk() throws {
        let url = makeTempStoreURL()
        let expired = makeStoreRequest(status: .approved, holdExpiresAt: Date(timeIntervalSinceNow: -3600))
        try writeFixture([expired], to: url)
        _ = BookingRequestStore(storeURL: url)

        let reloaded = BookingRequestStore(storeURL: url)
        #expect(reloaded.requests[0].status == .pending)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project CozumelManager/CozumelManager.xcodeproj -scheme CozumelManager -destination 'platform=macOS' -only-testing:CozumelManagerTests/BookingRequestStoreTests`
Expected: FAIL — expired hold still shows `.approved` since nothing reverts it yet.

- [ ] **Step 3: Implement hold-expiry reversion**

In `CozumelManager/CozumelManager/Models/BookingRequestStore.swift`, find this in `load()`:

```swift
        guard let list = try? decoder.decode(BookingRequestList.self, from: data) else { return }
        requests = list.requests
    }
```

Replace it with:

```swift
        guard let list = try? decoder.decode(BookingRequestList.self, from: data) else { return }
        requests = list.requests
        revertExpiredHolds()
    }

    func revertExpiredHolds() {
        let now = Date()
        var changed = false
        for i in requests.indices {
            if requests[i].status == .approved,
               let expiry = requests[i].holdExpiresAt,
               expiry < now {
                requests[i].status = .pending
                requests[i].holdExpiresAt = nil
                changed = true
            }
        }
        if changed { saveToDisk() }
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project CozumelManager/CozumelManager.xcodeproj -scheme CozumelManager -destination 'platform=macOS' -only-testing:CozumelManagerTests/BookingRequestStoreTests`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add CozumelManager/CozumelManager/Models/BookingRequestStore.swift CozumelManager/CozumelManagerTests/BookingRequestStoreTests.swift
git commit -m "feat: revert expired soft holds back to pending on load"
```

---

## Task 4: Conflict detection

**Files:**
- Modify: `CozumelManager/CozumelManager/Models/BookingRequestStore.swift`
- Test: `CozumelManager/CozumelManagerTests/BookingRequestStoreTests.swift`

**Interfaces:**
- Consumes: `BookingRequest.dateRangesOverlap` (Task 1).
- Produces: `BookingRequestStore.conflictingRequests(for: BookingRequest) -> [BookingRequest]`.

- [ ] **Step 1: Write the failing tests**

Append to `BookingRequestStoreTests`:

```swift
    @Test func conflictingRequests_findsOverlap_withHeldRequest_sameProperty() {
        let store = BookingRequestStore(storeURL: makeTempStoreURL())
        let held = makeStoreRequest(id: "held", status: .approved)
        let candidate = makeStoreRequest(id: "candidate", status: .pending)
        store.requests = [held, candidate]
        let conflicts = store.conflictingRequests(for: candidate)
        #expect(conflicts.map(\.id) == ["held"])
    }

    @Test func conflictingRequests_ignoresDifferentProperty() {
        let store = BookingRequestStore(storeURL: makeTempStoreURL())
        let held = makeStoreRequest(id: "held", propertyId: "prop-999", status: .approved)
        let candidate = makeStoreRequest(id: "candidate", propertyId: "prop-003", status: .pending)
        store.requests = [held, candidate]
        #expect(store.conflictingRequests(for: candidate).isEmpty)
    }

    @Test func conflictingRequests_ignoresPendingRequests() {
        let store = BookingRequestStore(storeURL: makeTempStoreURL())
        let otherPending = makeStoreRequest(id: "other-pending", status: .pending)
        let candidate = makeStoreRequest(id: "candidate", status: .pending)
        store.requests = [otherPending, candidate]
        #expect(store.conflictingRequests(for: candidate).isEmpty)
    }

    @Test func conflictingRequests_excludesSelf() {
        let store = BookingRequestStore(storeURL: makeTempStoreURL())
        let candidate = makeStoreRequest(id: "candidate", status: .approved)
        store.requests = [candidate]
        #expect(store.conflictingRequests(for: candidate).isEmpty)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project CozumelManager/CozumelManager.xcodeproj -scheme CozumelManager -destination 'platform=macOS' -only-testing:CozumelManagerTests/BookingRequestStoreTests`
Expected: FAIL — `conflictingRequests(for:)` not found in scope.

- [ ] **Step 3: Implement conflict detection**

In `CozumelManager/CozumelManager/Models/BookingRequestStore.swift`, add after `revertExpiredHolds()`:

```swift
    func conflictingRequests(for request: BookingRequest) -> [BookingRequest] {
        let holdingStatuses: Set<BookingStatus> = [.approved, .invoiceSending, .invoiced, .paid]
        return requests.filter { other in
            other.id != request.id &&
            other.propertyId == request.propertyId &&
            holdingStatuses.contains(other.status) &&
            BookingRequest.dateRangesOverlap(request.startDate, request.endDate, other.startDate, other.endDate)
        }
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project CozumelManager/CozumelManager.xcodeproj -scheme CozumelManager -destination 'platform=macOS' -only-testing:CozumelManagerTests/BookingRequestStoreTests`
Expected: PASS (9 tests)

- [ ] **Step 5: Commit**

```bash
git add CozumelManager/CozumelManager/Models/BookingRequestStore.swift CozumelManager/CozumelManagerTests/BookingRequestStoreTests.swift
git commit -m "feat: add overlap conflict detection to BookingRequestStore"
```

---

## Task 5: File watching (auto-reload on external write)

**Files:**
- Modify: `CozumelManager/CozumelManager/Models/BookingRequestStore.swift`
- Test: `CozumelManager/CozumelManagerTests/BookingRequestStoreTests.swift`

**Interfaces:**
- Produces: `BookingRequestStore.startWatching()`, `.stopWatching()` — `init` now calls `startWatching()` automatically after the initial `load()`, so no caller (views, App) needs to invoke it. This is the hook the future sync daemon relies on: any external process that overwrites `booking-requests.json` gets picked up without the app restarting.

- [ ] **Step 1: Write the failing test**

Append to `BookingRequestStoreTests`:

```swift
    @Test func store_reloadsAutomatically_whenFileChangesExternally() async throws {
        let url = makeTempStoreURL()
        try writeFixture([], to: url)
        let store = BookingRequestStore(storeURL: url)
        #expect(store.requests.isEmpty)

        try writeFixture([makeStoreRequest(id: "external")], to: url)

        var found = false
        for _ in 0..<30 {
            try await Task.sleep(nanoseconds: 100_000_000)
            if store.requests.count == 1 {
                found = true
                break
            }
        }
        #expect(found)
        #expect(store.requests.first?.id == "external")
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project CozumelManager/CozumelManager.xcodeproj -scheme CozumelManager -destination 'platform=macOS' -only-testing:CozumelManagerTests/BookingRequestStoreTests/store_reloadsAutomatically_whenFileChangesExternally`
Expected: FAIL — times out with `found == false`, nothing is watching the file yet.

- [ ] **Step 3: Implement file watching**

In `CozumelManager/CozumelManager/Models/BookingRequestStore.swift`:

1. Add a property below `let storeURL: URL`:

```swift
    private var watcherSource: DispatchSourceFileSystemObject?
```

2. Change `init` to start watching after the initial load:

```swift
    init(storeURL: URL? = nil) {
        self.storeURL = storeURL ?? BookingRequestStore.defaultStoreURL()
        load()
        startWatching()
    }
```

3. Add these methods after `saveToDisk()`:

```swift
    func startWatching() {
        stopWatching()
        let fd = open(storeURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: .main)
        source.setEventHandler { [weak self] in
            self?.load()
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        watcherSource = source
    }

    func stopWatching() {
        watcherSource?.cancel()
        watcherSource = nil
    }

    deinit {
        watcherSource?.cancel()
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project CozumelManager/CozumelManager.xcodeproj -scheme CozumelManager -destination 'platform=macOS' -only-testing:CozumelManagerTests/BookingRequestStoreTests`
Expected: PASS (10 tests)

- [ ] **Step 5: Commit**

```bash
git add CozumelManager/CozumelManager/Models/BookingRequestStore.swift CozumelManager/CozumelManagerTests/BookingRequestStoreTests.swift
git commit -m "feat: auto-reload BookingRequestStore when booking-requests.json changes externally"
```

---

## Task 6: Approve / deny / send-invoice actions

**Files:**
- Modify: `CozumelManager/CozumelManager/Models/BookingRequestStore.swift`
- Test: `CozumelManager/CozumelManagerTests/BookingRequestStoreTests.swift`

**Interfaces:**
- Produces: `BookingRequestStore.approve(_ requestID: String)`, `.deny(_ requestID: String)`, `.sendInvoice(for requestID: String, lineItems: [InvoiceLineItem])`.

- [ ] **Step 1: Write the failing tests**

Append to `BookingRequestStoreTests`:

```swift
    @Test func approve_setsStatusApproved_andHoldExpiry48HoursOut() {
        let store = BookingRequestStore(storeURL: makeTempStoreURL())
        store.requests = [makeStoreRequest(id: "r1", status: .pending)]
        store.approve("r1")
        let updated = store.requests[0]
        #expect(updated.status == .approved)
        let hoursOut = updated.holdExpiresAt!.timeIntervalSinceNow / 3600
        #expect(hoursOut > 47.9 && hoursOut < 48.1)
    }

    @Test func deny_setsStatusDenied() {
        let store = BookingRequestStore(storeURL: makeTempStoreURL())
        store.requests = [makeStoreRequest(id: "r1", status: .pending)]
        store.deny("r1")
        #expect(store.requests[0].status == .denied)
    }

    @Test func sendInvoice_setsLineItems_totalsAmount_andStatusInvoiceSending() {
        let store = BookingRequestStore(storeURL: makeTempStoreURL())
        store.requests = [makeStoreRequest(id: "r1", status: .approved)]
        let items = [
            InvoiceLineItem(itemDescription: "Nightly rate", quantity: 3, unitAmount: 325.0),
            InvoiceLineItem(itemDescription: "Cleaning fee", quantity: 1, unitAmount: 75.0)
        ]
        store.sendInvoice(for: "r1", lineItems: items)
        let updated = store.requests[0]
        #expect(updated.status == .invoiceSending)
        #expect(updated.invoiceAmount == 1050.0)
        #expect(updated.invoiceLineItems.count == 2)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project CozumelManager/CozumelManager.xcodeproj -scheme CozumelManager -destination 'platform=macOS' -only-testing:CozumelManagerTests/BookingRequestStoreTests`
Expected: FAIL — `approve`, `deny`, `sendInvoice` not found in scope.

- [ ] **Step 3: Implement the actions**

In `CozumelManager/CozumelManager/Models/BookingRequestStore.swift`, add after `conflictingRequests(for:)`:

```swift
    func approve(_ requestID: String) {
        guard let i = requests.firstIndex(where: { $0.id == requestID }) else { return }
        requests[i].status = .approved
        requests[i].holdExpiresAt = Date().addingTimeInterval(48 * 3600)
        saveToDisk()
    }

    func deny(_ requestID: String) {
        guard let i = requests.firstIndex(where: { $0.id == requestID }) else { return }
        requests[i].status = .denied
        saveToDisk()
    }

    func sendInvoice(for requestID: String, lineItems: [InvoiceLineItem]) {
        guard let i = requests.firstIndex(where: { $0.id == requestID }) else { return }
        requests[i].invoiceLineItems = lineItems
        requests[i].invoiceAmount = lineItems.reduce(0) { $0 + $1.total }
        requests[i].status = .invoiceSending
        saveToDisk()
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project CozumelManager/CozumelManager.xcodeproj -scheme CozumelManager -destination 'platform=macOS' -only-testing:CozumelManagerTests/BookingRequestStoreTests`
Expected: PASS (13 tests)

- [ ] **Step 5: Commit**

```bash
git add CozumelManager/CozumelManager/Models/BookingRequestStore.swift CozumelManager/CozumelManagerTests/BookingRequestStoreTests.swift
git commit -m "feat: add approve/deny/sendInvoice actions to BookingRequestStore"
```

---

## Task 7: Wire BookingRequestStore into the app

**Files:**
- Modify: `CozumelManager/CozumelManager/CozumelManagerApp.swift`

**Interfaces:**
- Consumes: `BookingRequestStore` (Task 2).
- Produces: `bookingStore` available via `@EnvironmentObject` to every view under `MainDashboardView`.

- [ ] **Step 1: Add the store as a StateObject and inject it**

In `CozumelManager/CozumelManager/CozumelManagerApp.swift`, change:

```swift
    @StateObject private var store = PropertyStore()
    @StateObject private var forSaleStore = ForSaleStore()
```

to:

```swift
    @StateObject private var store = PropertyStore()
    @StateObject private var forSaleStore = ForSaleStore()
    @StateObject private var bookingStore = BookingRequestStore()
```

And change:

```swift
            MainDashboardView()
                .environmentObject(store)
                .environmentObject(forSaleStore)
```

to:

```swift
            MainDashboardView()
                .environmentObject(store)
                .environmentObject(forSaleStore)
                .environmentObject(bookingStore)
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -project CozumelManager/CozumelManager.xcodeproj -scheme CozumelManager -configuration Debug -derivedDataPath /tmp/cozumel-build build`
Expected: BUILD SUCCEEDED (MainDashboardView doesn't consume `bookingStore` yet, but the app compiles and launches with it in the environment).

- [ ] **Step 3: Commit**

```bash
git add CozumelManager/CozumelManager/CozumelManagerApp.swift
git commit -m "feat: inject BookingRequestStore into the app environment"
```

---

## Task 8: Nav bar restructure — AppSection top-level split

**Files:**
- Modify: `CozumelManager/CozumelManager/Views/MainDashboardView.swift`

**Interfaces:**
- Consumes: `SidebarView` (existing, unchanged), `BookingRequestsListView` (Task 9 — this task references it, so build/manual-verify after Task 9 lands; if executed in strict order, stub it temporarily or do Tasks 8–9 back-to-back before verifying).
- Produces: `enum AppSection: String, CaseIterable, Identifiable, Hashable { properties, bookingRequests }`; `MainDashboardView` becomes a 3-column `NavigationSplitView` (top-level section list → content list → detail).

**Note:** This task and Task 9 are interdependent (this task's `content:` column switches to `BookingRequestsListView`, which Task 9 creates). Implement both before attempting to build/run; the step-by-step order below still applies for review purposes.

- [ ] **Step 1: Replace MainDashboardView.swift**

Replace the full contents of `CozumelManager/CozumelManager/Views/MainDashboardView.swift` with:

```swift
import SwiftUI

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case properties
    case bookingRequests

    var id: String { rawValue }

    var label: String {
        switch self {
        case .properties: return "Properties"
        case .bookingRequests: return "Booking Requests"
        }
    }

    var systemImage: String {
        switch self {
        case .properties: return "building.2"
        case .bookingRequests: return "tray"
        }
    }
}

struct MainDashboardView: View {
    @EnvironmentObject private var store: PropertyStore
    @EnvironmentObject private var forSaleStore: ForSaleStore
    @EnvironmentObject private var bookingStore: BookingRequestStore
    @State private var section: AppSection = .properties
    @State private var selection: SidebarSelection?
    @State private var bookingSelection: String?
    @State private var showInspector = false

    private var selectedProperty: Property? {
        guard case .rental(let id) = selection else { return nil }
        return store.properties.first { $0.id == id }
    }

    private var selectedForSaleProperty: ForSaleProperty? {
        guard case .forSale(let id) = selection else { return nil }
        return forSaleStore.properties.first { $0.id == id }
    }

    private var selectedBookingRequest: BookingRequest? {
        guard let bookingSelection else { return nil }
        return bookingStore.requests.first { $0.id == bookingSelection }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $section) {
                ForEach(AppSection.allCases) { item in
                    Label(item.label, systemImage: item.systemImage)
                        .tag(item)
                }
            }
            .navigationTitle("Cozumel Manager")
        } content: {
            switch section {
            case .properties:
                SidebarView(
                    selection: $selection,
                    onAdd: { property in
                        selection = .rental(property.id)
                        showInspector = true
                    },
                    onAddForSale: { property in
                        selection = .forSale(property.id)
                        showInspector = true
                    }
                )
            case .bookingRequests:
                BookingRequestsListView(selection: $bookingSelection)
            }
        } detail: {
            switch section {
            case .properties:
                propertyDetailContent
                    .inspector(isPresented: $showInspector) {
                        if let property = selectedProperty {
                            PropertyInspectorView(property: property)
                                .id(property.id)
                                .inspectorColumnWidth(min: 280, ideal: 320, max: 400)
                        } else if let property = selectedForSaleProperty {
                            ForSaleInspectorView(property: property)
                                .id(property.id)
                                .inspectorColumnWidth(min: 280, ideal: 320, max: 400)
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                showInspector.toggle()
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .disabled(selection == nil)
                        }
                    }
            case .bookingRequests:
                if let request = selectedBookingRequest,
                   let property = store.properties.first(where: { $0.id == request.propertyId }) {
                    BookingRequestDetailView(request: request, property: property)
                } else {
                    ContentUnavailableView("Select a Request", systemImage: "tray")
                }
            }
        }
        .onAppear {
            if selection == nil, let first = store.properties.first {
                selection = .rental(first.id)
            }
        }
        .onChange(of: store.properties) { _, newProperties in
            if case .rental(let id) = selection,
               !newProperties.contains(where: { $0.id == id }) {
                selection = newProperties.first.map { .rental($0.id) }
            }
        }
        .onChange(of: forSaleStore.properties) { _, newProperties in
            if case .forSale(let id) = selection,
               !newProperties.contains(where: { $0.id == id }) {
                selection = store.properties.first.map { .rental($0.id) }
            }
        }
    }

    @ViewBuilder
    private var propertyDetailContent: some View {
        if let property = selectedProperty {
            VStack(alignment: .leading, spacing: 12) {
                Text(property.name)
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                Text(property.neighborhood)
                    .font(.title2)
                    .foregroundStyle(.secondary)
                statusBadge(for: property.status)
                Text("$\(Int(property.baseRate.rounded())) / night")
                    .font(.title3)
                if let monthlyPrice = property.monthlyPrice {
                    Text("$\(Int(monthlyPrice.rounded())) / month")
                        .font(.title3)
                } else {
                    Text("Est. $\(Int(property.monthlyRevenue.rounded())) / month")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if let property = selectedForSaleProperty {
            VStack(alignment: .leading, spacing: 12) {
                Text(property.name)
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                Text(property.askingPrice, format: .currency(code: "USD"))
                    .font(.title2)
                    .foregroundStyle(.secondary)
                if !property.listingURL.isEmpty, let url = URL(string: property.listingURL) {
                    Link("View Listing", destination: url)
                        .font(.title3)
                }
                Spacer()
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            ContentUnavailableView("Select a Property", systemImage: "building.2")
        }
    }

    private func statusBadge(for status: PropertyStatus) -> some View {
        let (label, color): (String, Color) = switch status {
        case .active: ("Active", .green)
        case .inactive: ("Inactive", .secondary)
        case .maintenance: ("Maintenance", .orange)
        }
        return Text(label)
            .font(.callout)
            .fontWeight(.medium)
            .foregroundStyle(color)
    }
}
```

- [ ] **Step 2: Do not build yet — proceed to Task 9, which creates `BookingRequestsListView` and `BookingRequestDetailView` that this file references.**

---

## Task 9: BookingRequestsListView

**Files:**
- Create: `CozumelManager/CozumelManager/Views/BookingRequestsListView.swift`

**Interfaces:**
- Consumes: `BookingRequestStore` (Task 2), `PropertyStore` (existing), `BookingRequest.sortedForList` (Task 1).
- Produces: `struct BookingRequestsListView: View` with `@Binding var selection: String?`.

- [ ] **Step 1: Create the view**

Create `CozumelManager/CozumelManager/Views/BookingRequestsListView.swift`:

```swift
import SwiftUI

struct BookingRequestsListView: View {
    @EnvironmentObject private var bookingStore: BookingRequestStore
    @EnvironmentObject private var store: PropertyStore
    @Binding var selection: String?

    var body: some View {
        List(selection: $selection) {
            ForEach(BookingRequest.sortedForList(bookingStore.requests)) { request in
                VStack(alignment: .leading, spacing: 2) {
                    Text(request.fullName).fontWeight(.medium)
                    Text(propertyName(for: request.propertyId))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    statusBadge(for: request.status)
                }
                .tag(request.id)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Booking Requests")
    }

    private func propertyName(for propertyId: String) -> String {
        store.properties.first { $0.id == propertyId }?.name ?? "Unknown Property"
    }

    private func statusBadge(for status: BookingStatus) -> some View {
        let (label, color): (String, Color) = switch status {
        case .pending: ("Pending", .orange)
        case .approved: ("Approved", .blue)
        case .denied: ("Denied", .secondary)
        case .invoiceSending: ("Sending Invoice…", .blue)
        case .invoiced: ("Invoiced", .purple)
        case .paid: ("Paid", .green)
        }
        return Text(label)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(color)
    }
}
```

- [ ] **Step 2: Do not build yet — proceed to Task 10, which creates `BookingRequestDetailView` referenced by Task 8's `MainDashboardView`.**

---

## Task 10: BookingRequestDetailView + InvoiceEditorView

**Files:**
- Create: `CozumelManager/CozumelManager/Views/BookingRequestDetailView.swift`
- Create: `CozumelManager/CozumelManager/Views/InvoiceEditorView.swift`

**Interfaces:**
- Consumes: `BookingRequestStore.conflictingRequests(for:)`, `.approve(_:)`, `.deny(_:)`, `.sendInvoice(for:lineItems:)` (Tasks 4, 6); `BookingRequest.dateRangesOverlap`, `.autoLineItems(for:property:)` (Task 1); `Property.unavailableDateRanges` (existing).
- Produces: `struct BookingRequestDetailView: View { let request: BookingRequest; let property: Property }`; `struct InvoiceEditorView: View { let request: BookingRequest; let property: Property }`.

- [ ] **Step 1: Create the invoice editor**

Create `CozumelManager/CozumelManager/Views/InvoiceEditorView.swift`:

```swift
import SwiftUI

struct InvoiceEditorView: View {
    @EnvironmentObject private var bookingStore: BookingRequestStore
    let request: BookingRequest
    let property: Property

    @State private var lineItems: [InvoiceLineItem]
    @State private var newDescription = ""
    @State private var newAmount = ""

    init(request: BookingRequest, property: Property) {
        self.request = request
        self.property = property
        let initial = request.invoiceLineItems.isEmpty
            ? BookingRequest.autoLineItems(for: request, property: property)
            : request.invoiceLineItems
        _lineItems = State(initialValue: initial)
    }

    private var total: Double {
        lineItems.reduce(0) { $0 + $1.total }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Invoice").font(.headline)

            ForEach($lineItems) { $item in
                HStack {
                    TextField("Description", text: $item.itemDescription)
                    TextField("Qty", value: $item.quantity, format: .number)
                        .frame(width: 50)
                    TextField("Amount", value: $item.unitAmount, format: .currency(code: "USD"))
                        .frame(width: 100)
                    Text(item.total, format: .currency(code: "USD"))
                        .frame(width: 90, alignment: .trailing)
                }
            }

            HStack {
                TextField("New line description", text: $newDescription)
                TextField("Amount", text: $newAmount)
                    .frame(width: 100)
                Button("Add Line") {
                    guard !newDescription.isEmpty, let amount = Double(newAmount) else { return }
                    lineItems.append(InvoiceLineItem(itemDescription: newDescription, quantity: 1, unitAmount: amount))
                    newDescription = ""
                    newAmount = ""
                }
            }

            HStack {
                Text("Total").fontWeight(.semibold)
                Spacer()
                Text(total, format: .currency(code: "USD")).fontWeight(.semibold)
            }

            Button("Send Invoice") {
                bookingStore.sendInvoice(for: request.id, lineItems: lineItems)
            }
            .disabled(request.status != .approved || lineItems.isEmpty)
        }
    }
}
```

- [ ] **Step 2: Create the detail view**

Create `CozumelManager/CozumelManager/Views/BookingRequestDetailView.swift`:

```swift
import SwiftUI
import AppKit

struct BookingRequestDetailView: View {
    @EnvironmentObject private var bookingStore: BookingRequestStore
    let request: BookingRequest
    let property: Property

    private var conflicts: [BookingRequest] {
        bookingStore.conflictingRequests(for: request)
    }

    private var blockedDateConflict: Bool {
        property.unavailableDateRanges.contains {
            BookingRequest.dateRangesOverlap(request.startDate, request.endDate, $0.start, $0.end)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(request.fullName)
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                Text(property.name)
                    .font(.title2)
                    .foregroundStyle(.secondary)

                Group {
                    labeledRow("Email", request.email)
                    labeledRow("Location", "\(request.state), \(request.country)")
                    labeledRow("Dates", dateRangeText)
                    labeledRow("Guests", "\(request.guestCount)")
                    if !request.notes.isEmpty {
                        labeledRow("Notes", request.notes)
                    }
                }

                if blockedDateConflict {
                    conflictBanner("These dates overlap the property's blocked calendar.")
                }
                if !conflicts.isEmpty {
                    conflictBanner("These dates overlap \(conflicts.count) other held/paid request(s).")
                }

                if request.status == .pending {
                    HStack {
                        Button("Approve") {
                            bookingStore.approve(request.id)
                        }
                        Button("Deny", role: .destructive) {
                            denyAndDraftEmail()
                        }
                    }
                } else if request.status == .approved {
                    if let error = request.invoiceError {
                        Text("Invoice error: \(error)")
                            .foregroundStyle(.red)
                    }
                    InvoiceEditorView(request: request, property: property)
                }

                Spacer()
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: request.startDate)) – \(formatter.string(from: request.endDate))"
    }

    private func labeledRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
        }
    }

    private func conflictBanner(_ message: String) -> some View {
        Text(message)
            .font(.callout)
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func denyAndDraftEmail() {
        bookingStore.deny(request.id)
        let subject = "Regarding your booking request at \(property.name)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "mailto:\(request.email)?subject=\(subject)") else { return }
        NSWorkspace.shared.open(url)
    }
}
```

- [ ] **Step 3: Build the app**

Run: `xcodebuild -project CozumelManager/CozumelManager.xcodeproj -scheme CozumelManager -configuration Debug -derivedDataPath /tmp/cozumel-build build`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Run the full test suite**

Run: `xcodebuild test -project CozumelManager/CozumelManager.xcodeproj -scheme CozumelManager -destination 'platform=macOS'`
Expected: PASS — all existing tests plus the 13 new `BookingRequest`/`BookingRequestStore` tests.

- [ ] **Step 5: Manual verification**

`.onChange(of:)` does not fire on this toolchain and there's no ViewInspector/UI-test harness in this project for SwiftUI content — verify the following manually per `CLAUDE.md`'s accessibility-scripting approach (`osascript` + System Events), since `screencapture` may not be available:
1. Launch a debug build with `open -n`.
2. Confirm the leftmost column shows "Properties" and "Booking Requests" and clicking each switches the content/detail columns.
3. Manually place a fixture request into the sandboxed `booking-requests.json` (`~/Library/Containers/Team-Paraiso.CozumelManager/Data/Library/Application Support/CozumelManager/booking-requests.json`) with one `pending` request for `prop-003`, confirm it appears in the Booking Requests list and the app picks it up live (file-watch from Task 5) without restarting.
4. Select it, confirm guest fields render, click Approve, confirm the invoice editor appears pre-filled from `Property.nightlyRate(forGuests:)`, edit a line, click Send Invoice, confirm status badge updates to "Sending Invoice…".
5. Add a second fixture request for the same property with overlapping dates, confirm the conflict banner appears on its detail screen.
6. On a fresh `pending` request, click Deny, confirm a blank Mail.app draft opens addressed to the guest and the list shows "Denied".
7. Edit the fixture JSON directly to set one request's `status` to `"approved"` and `invoice_error` to a test message, confirm the detail screen shows the red error text above the (still-editable, still-sendable) invoice editor.

- [ ] **Step 6: Commit**

```bash
git add CozumelManager/CozumelManager/Views/MainDashboardView.swift CozumelManager/CozumelManager/Views/BookingRequestsListView.swift CozumelManager/CozumelManager/Views/BookingRequestDetailView.swift CozumelManager/CozumelManager/Views/InvoiceEditorView.swift
git commit -m "feat: add Booking Requests nav section, list/detail views, and invoice editor"
```

---

## Testing Summary

- Unit tests (Swift Testing, `xcodebuild test`): model Codable/coding-key round-trips, date-overlap logic, list-sort ordering, invoice auto-fill math, store load/save, hold-expiry reversion, conflict detection, file-watch auto-reload, approve/deny/sendInvoice state transitions — 13+ new tests across `BookingRequestTests.swift` and `BookingRequestStoreTests.swift`.
- No automated SwiftUI view tests — this project has no ViewInspector/UI-test harness (`CozumelManagerUITests` is unused boilerplate); Task 10 Step 5 is a manual verification pass following the existing accessibility-scripting approach from `CLAUDE.md`.

## Out of Scope (deferred to future, separate plans)

- WordPress `booking-request` CPT and REST endpoints.
- Python sync daemon bidirectional polling, iMessage alert, and `booking-requests.json` production from a real external source.
- WordPress-side Stripe Payment Link PHP code.
- Anything that writes `invoiced`, `paid`, `stripe_payment_link`, or `stripe_payment_status` into `booking-requests.json` — this plan only builds the Mac app's ability to *display* those states once something else starts writing them.
