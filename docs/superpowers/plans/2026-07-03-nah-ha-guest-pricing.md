# Nah Ha 101 Guest-Tiered Pricing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add editable guest-count pricing (2-guest base rate + per-extra-guest fee) to `Property`, scoped in the UI to Nah Ha 101 only.

**Architecture:** `Property` gains three optional fields (`baseGuests`, `maxGuests`, `extraGuestFee`) and a `nightlyRate(forGuests:)` helper (model layer). `PropertyInspectorView` gains a "Guest Pricing" section that renders only when the selected property's id is `prop-003` (view layer). `properties.json` seed data is updated so Nah Ha 101 ships with the new pricing pre-filled. No other files change.

**Tech Stack:** SwiftUI (macOS 14+), Swift Testing framework (`import Testing`, `@Test`, `#expect`), local JSON persistence via `PropertyStore`.

## Global Constraints

- Target: macOS 14+, Mac Silicon
- Test framework: Swift Testing (`import Testing`, `@Test`, `#expect`) — not XCTest
- No new dependencies
- `.onChange(of:)` does not fire on this toolchain — use `.onSubmit { commit() }` or explicit `Button` actions for all field commits, never `.onChange`
- `Property.Hashable` uses `id` only — do not change
- `PropertyStore` is injected via `.environmentObject` — never recreated in views
- New `Property` fields must be optional and decode via `try?`, matching the existing `monthlyPrice` pattern, so properties without these JSON keys (every property except Nah Ha 101) decode cleanly to `nil`
- Guest Pricing UI must be gated on `draft.id == "prop-003"` (id, not name — name is user-editable)

---

### Task 1: Add guest-pricing fields and `nightlyRate(forGuests:)` to `Property`

**Files:**
- Modify: `CozumelManager/CozumelManager/Models/Property.swift`
- Test: `CozumelManager/CozumelManagerTests/CozumelManagerTests.swift`

**Interfaces:**
- Produces: `Property.baseGuests: Int?`, `Property.maxGuests: Int?`, `Property.extraGuestFee: Double?` (stored properties)
- Produces: `Property.nightlyRate(forGuests: Int) -> Double` — returns `baseRate` unmodified when any of the three guest fields is `nil` or `guests <= baseGuests`; otherwise `baseRate + extraGuestFee * min(guests, maxGuests ?? guests) - baseGuests` guests beyond base, capped at `maxGuests`

- [ ] **Step 1: Write the failing tests**

Open `CozumelManager/CozumelManagerTests/CozumelManagerTests.swift`. Inside the `PropertyModelTests` struct, replace the existing `property_decodesLegacyJSON_withEmptyDefaults` test with this version (adds three assertions for the new fields):

```swift
@Test func property_decodesLegacyJSON_withEmptyDefaults() throws {
    let json = """
    {"id":"p1","name":"Test","neighborhood":"N","address":"A","base_rate":100.0,"status":"active"}
    """.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let p = try decoder.decode(Property.self, from: json)
    #expect(p.unavailableDateRanges.isEmpty)
    #expect(p.photos.isEmpty)
    #expect(p.baseRate == 100.0)
    #expect(p.baseGuests == nil)
    #expect(p.maxGuests == nil)
    #expect(p.extraGuestFee == nil)
}
```

Then, still inside `PropertyModelTests`, add these new tests right after `dateRange_preserves_startAndEnd` and before the struct's closing `}`:

```swift
@Test func property_roundtrips_guestPricingFields() throws {
    let original = Property(
        id: "prop-003", name: "Nah Ha 101", neighborhood: "North Shore", address: "Km 3.3",
        baseRate: 325.0, baseGuests: 2, maxGuests: 6, extraGuestFee: 25.0,
        status: .active
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(original)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(Property.self, from: data)
    #expect(decoded.baseGuests == 2)
    #expect(decoded.maxGuests == 6)
    #expect(decoded.extraGuestFee == 25.0)
}

@Test func nightlyRate_returnsBaseRate_whenGuestFieldsNil() {
    let p = Property(id: "p1", name: "Casa", neighborhood: "N", address: "A", baseRate: 250.0, status: .active)
    #expect(p.nightlyRate(forGuests: 4) == 250.0)
}

@Test func nightlyRate_returnsBaseRate_whenGuestsAtOrBelowBase() {
    let p = Property(
        id: "prop-003", name: "Nah Ha 101", neighborhood: "N", address: "A",
        baseRate: 325.0, baseGuests: 2, maxGuests: 6, extraGuestFee: 25.0, status: .active
    )
    #expect(p.nightlyRate(forGuests: 2) == 325.0)
    #expect(p.nightlyRate(forGuests: 1) == 325.0)
}

@Test func nightlyRate_addsExtraGuestFee_forGuestsAboveBase() {
    let p = Property(
        id: "prop-003", name: "Nah Ha 101", neighborhood: "N", address: "A",
        baseRate: 325.0, baseGuests: 2, maxGuests: 6, extraGuestFee: 25.0, status: .active
    )
    #expect(p.nightlyRate(forGuests: 4) == 375.0)
    #expect(p.nightlyRate(forGuests: 6) == 425.0)
}

@Test func nightlyRate_capsAtMaxGuests() {
    let p = Property(
        id: "prop-003", name: "Nah Ha 101", neighborhood: "N", address: "A",
        baseRate: 325.0, baseGuests: 2, maxGuests: 6, extraGuestFee: 25.0, status: .active
    )
    #expect(p.nightlyRate(forGuests: 8) == 425.0)
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test \
  -project CozumelManager/CozumelManager.xcodeproj \
  -scheme CozumelManager \
  -destination 'platform=macOS' 2>&1 | grep -E "Test.*failed|error:|Build FAILED"
```

Expected: compiler errors — `incorrect argument label` / `extra arguments` on the new `Property(...)` calls (no `baseGuests`/`maxGuests`/`extraGuestFee` params yet), and `value of type 'Property' has no member 'nightlyRate'`.

- [ ] **Step 3: Add the fields, init params, CodingKeys, decoding, and `nightlyRate` helper**

Open `CozumelManager/CozumelManager/Models/Property.swift`. Replace the entire file with:

```swift
import Foundation

enum PropertyStatus: String, Codable {
    case active
    case inactive
    case maintenance
}

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

struct Property: Identifiable, Hashable, Codable {
    var id: String
    var name: String
    var neighborhood: String
    var address: String
    var baseRate: Double
    var monthlyPrice: Double?
    var baseGuests: Int?
    var maxGuests: Int?
    var extraGuestFee: Double?
    var status: PropertyStatus
    var unavailableDateRanges: [DateRange]
    var photos: [URL]

    init(id: String, name: String, neighborhood: String, address: String,
         baseRate: Double, monthlyPrice: Double? = nil,
         baseGuests: Int? = nil, maxGuests: Int? = nil, extraGuestFee: Double? = nil,
         status: PropertyStatus,
         unavailableDateRanges: [DateRange] = [], photos: [URL] = []) {
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
    }

    var monthlyRevenue: Double {
        guard status == .active else { return 0 }
        return monthlyPrice ?? baseRate * 22
    }

    func nightlyRate(forGuests guests: Int) -> Double {
        guard let baseGuests, let extraGuestFee, guests > baseGuests else { return baseRate }
        let cappedGuests = min(guests, maxGuests ?? guests)
        let extra = max(0, cappedGuests - baseGuests)
        return baseRate + Double(extra) * extraGuestFee
    }

    static func == (lhs: Property, rhs: Property) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    enum CodingKeys: String, CodingKey {
        case id, name, neighborhood, address, status, photos
        case baseRate = "base_rate"
        case monthlyPrice = "monthly_price"
        case baseGuests = "base_guests"
        case maxGuests = "max_guests"
        case extraGuestFee = "extra_guest_fee"
        case unavailableDateRanges = "unavailable_date_ranges"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        neighborhood = try c.decode(String.self, forKey: .neighborhood)
        address = try c.decode(String.self, forKey: .address)
        baseRate = try c.decode(Double.self, forKey: .baseRate)
        monthlyPrice = try? c.decode(Double.self, forKey: .monthlyPrice)
        baseGuests = try? c.decode(Int.self, forKey: .baseGuests)
        maxGuests = try? c.decode(Int.self, forKey: .maxGuests)
        extraGuestFee = try? c.decode(Double.self, forKey: .extraGuestFee)
        status = try c.decode(PropertyStatus.self, forKey: .status)
        unavailableDateRanges = (try? c.decode([DateRange].self, forKey: .unavailableDateRanges)) ?? []
        photos = (try? c.decode([URL].self, forKey: .photos)) ?? []
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test \
  -project CozumelManager/CozumelManager.xcodeproj \
  -scheme CozumelManager \
  -destination 'platform=macOS' 2>&1 | grep -E "Test.*failed|error:|Build FAILED|Test Suite 'All tests' passed"
```

Expected: all tests pass, including the 5 new/modified ones in `PropertyModelTests`.

- [ ] **Step 5: Commit**

```bash
git add CozumelManager/CozumelManager/Models/Property.swift \
        CozumelManager/CozumelManagerTests/CozumelManagerTests.swift
git commit -m "feat: add guest-tiered pricing fields and nightlyRate(forGuests:) to Property"
```

---

### Task 2: Update seed data for Nah Ha 101

**Files:**
- Modify: `CozumelManager/CozumelManager/properties.json`

**Interfaces:**
- Consumes: `Property` CodingKeys `base_rate`, `base_guests`, `max_guests`, `extra_guest_fee` from Task 1

- [ ] **Step 1: Update `prop-003` in the seed JSON**

Open `CozumelManager/CozumelManager/properties.json`. Replace the `prop-003` object:

```json
    {
      "id": "prop-003",
      "name": "Cozumel's Nah Ha Condominium 101",
      "neighborhood": "North Shore",
      "address": "North Shore Highway Km 3.3",
      "base_rate": 425.0,
      "status": "active"
    }
```

with:

```json
    {
      "id": "prop-003",
      "name": "Cozumel's Nah Ha Condominium 101",
      "neighborhood": "North Shore",
      "address": "North Shore Highway Km 3.3",
      "base_rate": 325.0,
      "base_guests": 2,
      "max_guests": 6,
      "extra_guest_fee": 25.0,
      "status": "active"
    }
```

- [ ] **Step 2: Verify the JSON is well-formed**

```bash
plutil -lint CozumelManager/CozumelManager/properties.json
```

Expected: `CozumelManager/CozumelManager/properties.json: OK`

- [ ] **Step 3: Commit**

```bash
git add CozumelManager/CozumelManager/properties.json
git commit -m "data: set Nah Ha 101 to 2-guest base rate with extra-guest pricing"
```

---

### Task 3: Add "Guest Pricing" section to the inspector, scoped to Nah Ha 101

**Files:**
- Modify: `CozumelManager/CozumelManager/Views/PropertyInspectorView.swift`

**Interfaces:**
- Consumes: `Property.baseGuests`, `Property.maxGuests`, `Property.extraGuestFee`, `Property.nightlyRate(forGuests:)` from Task 1
- Consumes: `draft: Property` (existing `@State` on `PropertyInspectorView`), `commit()` (existing method)

- [ ] **Step 1: Add the three guest-pricing bindings**

Open `CozumelManager/CozumelManager/Views/PropertyInspectorView.swift`. Immediately after the existing `monthlyPriceBinding` computed property (after its closing `}`, before `private func statusLabel`), add:

```swift
private var baseGuestsBinding: Binding<Int> {
    Binding(
        get: { draft.baseGuests ?? 0 },
        set: { draft.baseGuests = $0 == 0 ? nil : $0 }
    )
}

private var maxGuestsBinding: Binding<Int> {
    Binding(
        get: { draft.maxGuests ?? 0 },
        set: { draft.maxGuests = $0 == 0 ? nil : $0 }
    )
}

private var extraGuestFeeBinding: Binding<Double> {
    Binding(
        get: { draft.extraGuestFee ?? 0 },
        set: { draft.extraGuestFee = $0 == 0 ? nil : $0 }
    )
}
```

- [ ] **Step 2: Add the Guest Pricing section and summary text**

In the same file, add this new `// MARK: - Guest Pricing` block right after the `// MARK: - Details` block's `detailsSection` closing `}` (i.e. after line 228 in the original file, before the struct's final closing `}`):

```swift
    // MARK: - Guest Pricing

    private var guestPricingSection: some View {
        Section("Guest Pricing") {
            LabeledContent("Base Guests") {
                TextField("", value: baseGuestsBinding, format: .number)
                    .multilineTextAlignment(.trailing)
                    .onSubmit { commit() }
            }
            LabeledContent("Max Guests") {
                TextField("", value: maxGuestsBinding, format: .number)
                    .multilineTextAlignment(.trailing)
                    .onSubmit { commit() }
            }
            LabeledContent("Extra Guest Fee") {
                TextField("Not set", value: extraGuestFeeBinding, format: .currency(code: "USD"))
                    .multilineTextAlignment(.trailing)
                    .onSubmit { commit() }
            }
            Text(guestPricingSummary)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var guestPricingSummary: String {
        guard let baseGuests = draft.baseGuests,
              let maxGuests = draft.maxGuests,
              let extraGuestFee = draft.extraGuestFee else {
            return "Set base guests, max guests, and extra guest fee to see a summary."
        }
        let baseRateText = draft.baseRate.formatted(.currency(code: "USD"))
        let maxRateText = draft.nightlyRate(forGuests: maxGuests).formatted(.currency(code: "USD"))
        let feeText = extraGuestFee.formatted(.currency(code: "USD"))
        return "Up to \(baseGuests) guests: \(baseRateText)/night. \(baseGuests + 1)–\(maxGuests) guests: +\(feeText)/guest (up to \(maxRateText)/night at \(maxGuests))."
    }
```

- [ ] **Step 3: Wire the section into `body`, gated to Nah Ha 101**

Find this in the same file:

```swift
    var body: some View {
        Form {
            detailsSection
            availabilitySection
            photosSection
        }
```

Replace with:

```swift
    var body: some View {
        Form {
            detailsSection
            if draft.id == "prop-003" {
                guestPricingSection
            }
            availabilitySection
            photosSection
        }
```

- [ ] **Step 4: Build and manually verify**

Build with `Cmd+B` — no compiler errors expected.

Run with `Cmd+R` and verify:

1. Select "Cozumel's Nah Ha Condominium 101" in the sidebar, open the inspector — a "Guest Pricing" section appears between Details and Availability, showing Base Guests: 2, Max Guests: 6, Extra Guest Fee: $25.00, and the summary line "Up to 2 guests: $325.00/night. 3–6 guests: +$25.00/guest (up to $425.00/night at 6)."
2. Select either of the other two properties — no "Guest Pricing" section appears.
3. On Nah Ha 101, change Extra Guest Fee to 30, press Return — summary line updates to reflect the new fee.
4. Quit and relaunch the app — the change persists (Extra Guest Fee still shows $30.00).
5. Confirm the Nightly Rate field (Details section) still shows $325.00 and the dashboard's "$/night" for Nah Ha 101 reads $325 (or your Step 3 test value, if unchanged).

- [ ] **Step 5: Commit**

```bash
git add CozumelManager/CozumelManager/Views/PropertyInspectorView.swift
git commit -m "feat: add Guest Pricing section to inspector, scoped to Nah Ha 101"
```
