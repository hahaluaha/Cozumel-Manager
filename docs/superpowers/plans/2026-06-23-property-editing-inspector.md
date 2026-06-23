# Property Editing — Inspector Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a native macOS inspector panel so Kelley can edit property details, block unavailable date ranges, and manage photos — with all changes persisting to disk immediately.

**Architecture:** Replace the bundle-only JSON load with an Application Support store that supports read/write. Add `update()` and `add()` methods to `PropertyStore`. Wire SwiftUI's `.inspector()` modifier into `MainDashboardView` with a three-section inspector: Details, Availability, Photos.

**Tech Stack:** SwiftUI (macOS 14+), Swift Testing, `NSOpenPanel`, `FileManager`, `JSONEncoder`/`JSONDecoder`

## Global Constraints

- macOS 14+ minimum target (already set in project)
- App Sandbox is enabled — use `NSOpenPanel` for file picking, write only to Application Support
- `Property.==` and `Property.hash` use `id` only — do not change this (per CLAUDE.md)
- `monthlyRevenue` returns 0 for `.inactive` and `.maintenance` — do not change this
- `PropertyStore` is injected once via `.environmentObject` at app entry — do not recreate in views
- No auto-booking, no guest messaging, no staff scheduling
- All tests use Swift Testing (`@Test`, `#expect`) — not XCTest

---

## File Map

**Modified:**
- `CozumelManager/CozumelManager/Models/Property.swift` — add `DateRange`, make `Property` fully `Codable` with new fields and defaults
- `CozumelManager/CozumelManager/Models/PropertyModel.swift` — replace DTO pattern with direct `Property` decode, add `update()`, `add()`, `saveToDisk()`, Application Support persistence
- `CozumelManager/CozumelManager/Views/MainDashboardView.swift` — add inspector toggle state, toolbar Edit button, `.inspector()` modifier, add-property wiring
- `CozumelManager/CozumelManager/Views/SidebarView.swift` — add `onAdd` callback parameter, "+" toolbar button, present `AddPropertySheet`
- `CozumelManager/CozumelManagerTests/CozumelManagerTests.swift` — replace stub with real tests

**Created:**
- `CozumelManager/CozumelManager/Views/PropertyInspectorView.swift` — inspector panel (Details, Availability, Photos sections)
- `CozumelManager/CozumelManager/Views/AddPropertySheet.swift` — new property creation form

---

### Task 1: Property & DateRange data model

**Files:**
- Modify: `CozumelManager/CozumelManager/Models/Property.swift`
- Modify: `CozumelManager/CozumelManagerTests/CozumelManagerTests.swift`

**Interfaces:**
- Produces: `DateRange(id:start:end:)`, `Property(id:name:neighborhood:address:baseRate:status:unavailableDateRanges:photos:)`, `Property` fully `Codable` with `CodingKeys` that maps `base_rate`, `unavailable_date_ranges`, `photos`; new fields default to empty when absent from JSON

- [ ] **Step 1: Write failing tests**

Replace the entire contents of `CozumelManager/CozumelManagerTests/CozumelManagerTests.swift`:

```swift
import Testing
@testable import CozumelManager

struct PropertyModelTests {

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
    }

    @Test func property_roundtrips_throughCodable() throws {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let end   = Date(timeIntervalSinceReferenceDate: 86400)
        let original = Property(
            id: "p1", name: "Casa", neighborhood: "Centro", address: "Calle 1",
            baseRate: 250.0, status: .active,
            unavailableDateRanges: [DateRange(start: start, end: end)],
            photos: []
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Property.self, from: data)
        #expect(decoded.id == "p1")
        #expect(decoded.baseRate == 250.0)
        #expect(decoded.unavailableDateRanges.count == 1)
        #expect(decoded.status == .active)
    }

    @Test func dateRange_preserves_startAndEnd() {
        let start = Date(timeIntervalSinceReferenceDate: 1000)
        let end   = Date(timeIntervalSinceReferenceDate: 2000)
        let r = DateRange(start: start, end: end)
        #expect(r.start == start)
        #expect(r.end == end)
    }
}
```

- [ ] **Step 2: Run tests — expect failure**

Press **Cmd+U** in Xcode. Tests fail because `DateRange` doesn't exist and `Property` isn't `Codable`.

- [ ] **Step 3: Rewrite `Property.swift`**

Replace the entire file:

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
    var status: PropertyStatus
    var unavailableDateRanges: [DateRange]
    var photos: [URL]

    init(id: String, name: String, neighborhood: String, address: String,
         baseRate: Double, status: PropertyStatus,
         unavailableDateRanges: [DateRange] = [], photos: [URL] = []) {
        self.id = id
        self.name = name
        self.neighborhood = neighborhood
        self.address = address
        self.baseRate = baseRate
        self.status = status
        self.unavailableDateRanges = unavailableDateRanges
        self.photos = photos
    }

    var monthlyRevenue: Double { status == .active ? baseRate * 22 : 0 }

    static func == (lhs: Property, rhs: Property) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    enum CodingKeys: String, CodingKey {
        case id, name, neighborhood, address, status, photos
        case baseRate = "base_rate"
        case unavailableDateRanges = "unavailable_date_ranges"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        neighborhood = try c.decode(String.self, forKey: .neighborhood)
        address = try c.decode(String.self, forKey: .address)
        baseRate = try c.decode(Double.self, forKey: .baseRate)
        status = try c.decode(PropertyStatus.self, forKey: .status)
        unavailableDateRanges = (try? c.decode([DateRange].self, forKey: .unavailableDateRanges)) ?? []
        photos = (try? c.decode([URL].self, forKey: .photos)) ?? []
    }
}
```

- [ ] **Step 4: Run tests — expect pass**

Press **Cmd+U**. All three tests in `PropertyModelTests` pass.

- [ ] **Step 5: Commit**

```bash
git add CozumelManager/CozumelManager/Models/Property.swift \
        CozumelManager/CozumelManagerTests/CozumelManagerTests.swift
git commit -m "feat: extend Property model with DateRange, photos, full Codable"
```

---

### Task 2: PropertyStore persistence

**Files:**
- Modify: `CozumelManager/CozumelManager/Models/PropertyModel.swift`
- Modify: `CozumelManager/CozumelManagerTests/CozumelManagerTests.swift`

**Interfaces:**
- Consumes: `Property` (Codable, from Task 1)
- Produces:
  - `PropertyStore(storeURL: URL? = nil)` — `nil` uses Application Support default
  - `store.update(_ property: Property)` — replaces by id, then saves
  - `store.add(_ property: Property)` — appends, then saves
  - `store.saveToDisk()` — writes full array to `storeURL`
  - `store.totalMonthlyRevenue: Double` — sum of all `monthlyRevenue`

- [ ] **Step 1: Write failing tests**

Add these tests to `CozumelManagerTests.swift` (append to the file, inside the `PropertyModelTests` struct or as a new struct):

```swift
struct PropertyStoreTests {

    private func makeStore(properties: [Property]) -> PropertyStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("properties.json")

        struct Wrapper: Encodable { let properties: [Property] }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try? encoder.encode(Wrapper(properties: properties)).write(to: url)

        return PropertyStore(storeURL: url)
    }

    @Test func store_loadsProperties_fromURL() {
        let p = Property(id: "p1", name: "Casa", neighborhood: "N", address: "A", baseRate: 100, status: .active)
        let store = makeStore(properties: [p])
        #expect(store.properties.count == 1)
        #expect(store.properties[0].name == "Casa")
    }

    @Test func store_update_replacesProperty() {
        let p = Property(id: "p1", name: "Old", neighborhood: "N", address: "A", baseRate: 100, status: .active)
        let store = makeStore(properties: [p])
        var updated = store.properties[0]
        updated.name = "New"
        store.update(updated)
        #expect(store.properties[0].name == "New")
    }

    @Test func store_add_appendsProperty() {
        let store = makeStore(properties: [])
        let p = Property(id: "p2", name: "New", neighborhood: "N", address: "A", baseRate: 200, status: .active)
        store.add(p)
        #expect(store.properties.count == 1)
        #expect(store.properties[0].id == "p2")
    }

    @Test func store_saveToDisk_persistsAcrossReload() throws {
        let p = Property(id: "p1", name: "Persist", neighborhood: "N", address: "A", baseRate: 100, status: .active)
        let store = makeStore(properties: [p])
        var updated = store.properties[0]
        updated.name = "Saved"
        store.update(updated)

        let store2 = PropertyStore(storeURL: store.storeURL)
        #expect(store2.properties[0].name == "Saved")
    }

    @Test func store_totalMonthlyRevenue_excludesInactive() {
        let active = Property(id: "p1", name: "A", neighborhood: "N", address: "A", baseRate: 100, status: .active)
        let inactive = Property(id: "p2", name: "B", neighborhood: "N", address: "B", baseRate: 200, status: .inactive)
        let store = makeStore(properties: [active, inactive])
        #expect(store.totalMonthlyRevenue == 100 * 22)
    }
}
```

- [ ] **Step 2: Run tests — expect failure**

**Cmd+U** — fails because `PropertyStore` has no `storeURL` parameter and no `update`/`add` methods.

- [ ] **Step 3: Rewrite `PropertyModel.swift`**

Replace the entire file:

```swift
import Foundation
import Combine

private struct PropertyList: Codable {
    var properties: [Property]
}

class PropertyStore: ObservableObject {
    @Published var properties: [Property] = []
    @Published var loadError: String?

    let storeURL: URL

    var totalMonthlyRevenue: Double {
        properties.reduce(0) { $0 + $1.monthlyRevenue }
    }

    init(storeURL: URL? = nil) {
        self.storeURL = storeURL ?? PropertyStore.defaultStoreURL()
        load()
    }

    private static func defaultStoreURL() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let appDir = appSupport.appendingPathComponent("CozumelManager")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("properties.json")
    }

    private func load() {
        if !FileManager.default.fileExists(atPath: storeURL.path) {
            migrateFromBundle()
        }
        guard let data = try? Data(contentsOf: storeURL) else {
            loadError = "Could not load properties data."
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let list = try? decoder.decode(PropertyList.self, from: data) else {
            loadError = "Could not parse properties data."
            return
        }
        properties = list.properties
    }

    private func migrateFromBundle() {
        guard let src = Bundle.main.url(forResource: "properties", withExtension: "json") else { return }
        try? FileManager.default.copyItem(at: src, to: storeURL)
    }

    func update(_ property: Property) {
        guard let i = properties.firstIndex(where: { $0.id == property.id }) else { return }
        properties[i] = property
        saveToDisk()
    }

    func add(_ property: Property) {
        properties.append(property)
        saveToDisk()
    }

    func saveToDisk() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(PropertyList(properties: properties)) else { return }
        try? data.write(to: storeURL)
    }
}
```

- [ ] **Step 4: Run tests — expect pass**

**Cmd+U** — all tests in `PropertyStoreTests` pass. Existing `PropertyModelTests` from Task 1 still pass.

- [ ] **Step 5: Build the app — verify it runs**

**Cmd+R** — app launches, all three properties appear in the sidebar. No load error.

- [ ] **Step 6: Commit**

```bash
git add CozumelManager/CozumelManager/Models/PropertyModel.swift \
        CozumelManager/CozumelManagerTests/CozumelManagerTests.swift
git commit -m "feat: add PropertyStore persistence with update/add/saveToDisk"
```

---

### Task 3: Inspector scaffold

**Files:**
- Create: `CozumelManager/CozumelManager/Views/PropertyInspectorView.swift`
- Modify: `CozumelManager/CozumelManager/Views/MainDashboardView.swift`

**Interfaces:**
- Consumes: `Property` (Task 1), `PropertyStore` (Task 2)
- Produces: `PropertyInspectorView(property: Property)` — stub that shows the property name; wired into `MainDashboardView` via `.inspector(isPresented:)`; toggled by an "Edit" toolbar button

- [ ] **Step 1: Create stub `PropertyInspectorView.swift`**

Create `CozumelManager/CozumelManager/Views/PropertyInspectorView.swift`:

```swift
import SwiftUI

struct PropertyInspectorView: View {
    @EnvironmentObject private var store: PropertyStore
    let property: Property
    @State private var draft: Property

    init(property: Property) {
        self.property = property
        _draft = State(initialValue: property)
    }

    var body: some View {
        Text(draft.name)
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func commit() {
        store.update(draft)
    }
}
```

- [ ] **Step 2: Update `MainDashboardView.swift`**

Replace the entire file:

```swift
import SwiftUI

struct MainDashboardView: View {
    @EnvironmentObject private var store: PropertyStore
    @State private var selectedID: Property.ID?
    @State private var showInspector = false

    private var selectedProperty: Property? {
        store.properties.first { $0.id == selectedID }
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedID: $selectedID, onAdd: { property in
                selectedID = property.id
                showInspector = true
            })
        } detail: {
            detailContent
                .inspector(isPresented: $showInspector) {
                    if let property = selectedProperty {
                        PropertyInspectorView(property: property)
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
                        .disabled(selectedProperty == nil)
                    }
                }
        }
        .onAppear {
            if selectedID == nil {
                selectedID = store.properties.first?.id
            }
        }
        .onChange(of: store.properties) { _, newProperties in
            if let current = selectedID,
               !newProperties.contains(where: { $0.id == current }) {
                selectedID = newProperties.first?.id
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if let property = selectedProperty {
            VStack(alignment: .leading, spacing: 12) {
                Text(property.name)
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                Text(property.neighborhood)
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("$\(Int(property.baseRate.rounded())) / night")
                    .font(.title3)
                Text("Est. $\(Int(property.monthlyRevenue.rounded())) / month")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            ContentUnavailableView("Select a Property", systemImage: "building.2")
        }
    }
}
```

- [ ] **Step 3: Update `SidebarView.swift` — add `onAdd` parameter**

Replace the entire file:

```swift
import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var store: PropertyStore
    @Binding var selectedID: Property.ID?
    var onAdd: (Property) -> Void

    var body: some View {
        List(store.properties, selection: $selectedID) { property in
            VStack(alignment: .leading, spacing: 2) {
                Text(property.name)
                    .fontWeight(.medium)
                Text(property.neighborhood)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Properties")
    }
}
```

(The "+" button and `AddPropertySheet` wiring come in Task 7.)

- [ ] **Step 4: Build and verify**

**Cmd+R** — app launches. Select a property. Click the pencil toolbar button. A panel slides in from the right showing the property name. Click the button again — panel closes. No crashes.

- [ ] **Step 5: Commit**

```bash
git add CozumelManager/CozumelManager/Views/PropertyInspectorView.swift \
        CozumelManager/CozumelManager/Views/MainDashboardView.swift \
        CozumelManager/CozumelManager/Views/SidebarView.swift
git commit -m "feat: scaffold inspector panel wired to detail view"
```

---

### Task 4: Inspector Details section

**Files:**
- Modify: `CozumelManager/CozumelManager/Views/PropertyInspectorView.swift`

**Interfaces:**
- Consumes: `store.update(_ property: Property)` (Task 2), `draft: Property` @State (Task 3)
- Produces: `PropertyInspectorView` with a Details section showing editable fields for name, neighborhood, address, nightly rate, status; calling `commit()` on each change

- [ ] **Step 1: Replace `PropertyInspectorView.swift` with Details section**

```swift
import SwiftUI

struct PropertyInspectorView: View {
    @EnvironmentObject private var store: PropertyStore
    let property: Property
    @State private var draft: Property
    @State private var showAddBlock = false
    @State private var blockStart = Date()
    @State private var blockEnd = Calendar.current.date(byAdding: .day, value: 1, to: Date())!

    init(property: Property) {
        self.property = property
        _draft = State(initialValue: property)
    }

    var body: some View {
        Form {
            detailsSection
        }
        .formStyle(.grouped)
        .navigationTitle("Edit Property")
    }

    private func commit() {
        store.update(draft)
    }

    // MARK: - Details

    private var detailsSection: some View {
        Section("Details") {
            LabeledContent("Name") {
                TextField("", text: $draft.name)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: draft.name) { _, _ in commit() }
            }
            LabeledContent("Neighborhood") {
                TextField("", text: $draft.neighborhood)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: draft.neighborhood) { _, _ in commit() }
            }
            LabeledContent("Address") {
                TextField("", text: $draft.address)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: draft.address) { _, _ in commit() }
            }
            LabeledContent("Nightly Rate") {
                TextField("", value: $draft.baseRate, format: .currency(code: "USD"))
                    .multilineTextAlignment(.trailing)
                    .onChange(of: draft.baseRate) { _, _ in commit() }
            }
            Picker("Status", selection: $draft.status) {
                Text("Active").tag(PropertyStatus.active)
                Text("Inactive").tag(PropertyStatus.inactive)
                Text("Maintenance").tag(PropertyStatus.maintenance)
            }
            .onChange(of: draft.status) { _, _ in commit() }
        }
    }
}
```

- [ ] **Step 2: Build and verify**

**Cmd+R** — open the inspector. You see a grouped form with Details fields. Edit the nightly rate. Switch to another property and back — the change persisted. Quit and relaunch — change still there.

- [ ] **Step 3: Commit**

```bash
git add CozumelManager/CozumelManager/Views/PropertyInspectorView.swift
git commit -m "feat: inspector Details section — editable property fields"
```

---

### Task 5: Inspector Availability section

**Files:**
- Modify: `CozumelManager/CozumelManager/Views/PropertyInspectorView.swift`

**Interfaces:**
- Consumes: `draft.unavailableDateRanges: [DateRange]`, `commit()`, `blockStart`, `blockEnd`, `showAddBlock`
- Produces: Availability section in the inspector with a date range list, delete per row, and an "Add Block" popover with DatePickers that disables Add when end ≤ start

- [ ] **Step 1: Add `availabilitySection` to `PropertyInspectorView`**

Add the following property to `PropertyInspectorView` (after `detailsSection`):

```swift
private var availabilitySection: some View {
    Section("Availability") {
        if draft.unavailableDateRanges.isEmpty {
            Text("No blocked dates")
                .foregroundStyle(.secondary)
                .font(.callout)
        } else {
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
        }

        Button("Add Block") {
            blockStart = Date()
            blockEnd = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
            showAddBlock = true
        }
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
    }
}
```

Then update `body` to include `availabilitySection` in the `Form`:

```swift
var body: some View {
    Form {
        detailsSection
        availabilitySection
    }
    .formStyle(.grouped)
    .navigationTitle("Edit Property")
}
```

- [ ] **Step 2: Build and verify**

**Cmd+R** — open inspector for a property. The Availability section shows "No blocked dates". Click "Add Block" — a popover appears with date pickers. Set end date before start — Add button is disabled. Set valid range — Add is enabled. Click Add — range appears in the list. Click the trash icon — range removed. Quit and relaunch — changes persist.

- [ ] **Step 3: Commit**

```bash
git add CozumelManager/CozumelManager/Views/PropertyInspectorView.swift
git commit -m "feat: inspector Availability section — block date ranges"
```

---

### Task 6: Inspector Photos section

**Files:**
- Modify: `CozumelManager/CozumelManager/Views/PropertyInspectorView.swift`

**Interfaces:**
- Consumes: `draft.photos: [URL]`, `commit()`, `NSOpenPanel`, `FileManager`
- Produces: Photos section with 3-column thumbnail grid; "+" opens `NSOpenPanel`; picked files copied to `~/Library/Application Support/CozumelManager/Photos/<property-id>/`; missing files show placeholder; tap overlay to remove

- [ ] **Step 1: Add `photosSection` and helpers to `PropertyInspectorView`**

Add the following to `PropertyInspectorView`:

```swift
private var photosSection: some View {
    Section("Photos") {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(draft.photos, id: \.self) { url in
                photoThumbnail(for: url)
            }
        }
        .padding(.vertical, 4)

        Button {
            pickPhotos()
        } label: {
            Label("Add Photos", systemImage: "plus")
        }
    }
}

@ViewBuilder
private func photoThumbnail(for url: URL) -> some View {
    ZStack(alignment: .topTrailing) {
        if let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .quaternaryLabelColor))
                .frame(width: 80, height: 80)
                .overlay {
                    Image(systemName: "photo.badge.exclamationmark")
                        .foregroundStyle(.secondary)
                }
        }

        Button {
            draft.photos.removeAll { $0 == url }
            commit()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.white, .black)
                .padding(4)
        }
        .buttonStyle(.plain)
    }
}

private func pickPhotos() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.image]
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = true
    guard panel.runModal() == .OK else { return }
    for url in panel.urls {
        copyPhoto(from: url)
    }
}

private func copyPhoto(from source: URL) {
    let appSupport = FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let dest = appSupport
        .appendingPathComponent("CozumelManager/Photos/\(draft.id)")
    try? FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
    let destFile = dest.appendingPathComponent(source.lastPathComponent)
    if !FileManager.default.fileExists(atPath: destFile.path) {
        try? FileManager.default.copyItem(at: source, to: destFile)
    }
    if !draft.photos.contains(destFile) {
        draft.photos.append(destFile)
        commit()
    }
}
```

Update `body` to include `photosSection`:

```swift
var body: some View {
    Form {
        detailsSection
        availabilitySection
        photosSection
    }
    .formStyle(.grouped)
    .navigationTitle("Edit Property")
}
```

- [ ] **Step 2: Build and verify**

**Cmd+R** — open inspector. Photos section shows "Add Photos". Click it — file picker opens. Select images — thumbnails appear in a 3-column grid. Move an original file to Trash — that thumbnail shows the placeholder icon. Click the X on a thumbnail — it's removed. Quit and relaunch — remaining photos still there.

- [ ] **Step 3: Commit**

```bash
git add CozumelManager/CozumelManager/Views/PropertyInspectorView.swift
git commit -m "feat: inspector Photos section — thumbnail grid with add/remove"
```

---

### Task 7: Add new property

**Files:**
- Create: `CozumelManager/CozumelManager/Views/AddPropertySheet.swift`
- Modify: `CozumelManager/CozumelManager/Views/SidebarView.swift`
- Modify: `CozumelManager/CozumelManager/Views/MainDashboardView.swift` (no change needed — `onAdd` already wired)

**Interfaces:**
- Consumes: `store.add(_ property: Property)` (Task 2), `onAdd: (Property) -> Void` callback on `SidebarView` (Task 3)
- Produces: `AddPropertySheet(onCreated: (Property) -> Void)` — form sheet; on Create, calls `store.add()` then `onCreated`

- [ ] **Step 1: Create `AddPropertySheet.swift`**

```swift
import SwiftUI

struct AddPropertySheet: View {
    @EnvironmentObject private var store: PropertyStore
    @Environment(\.dismiss) private var dismiss

    var onCreated: (Property) -> Void

    @State private var name = ""
    @State private var neighborhood = ""
    @State private var address = ""
    @State private var rateText = ""

    private var rate: Double? {
        Double(rateText.filter { $0.isNumber || $0 == "." })
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !neighborhood.trimmingCharacters(in: .whitespaces).isEmpty &&
        !address.trimmingCharacters(in: .whitespaces).isEmpty &&
        (rate ?? 0) > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Property")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                TextField("Name", text: $name)
                TextField("Neighborhood", text: $neighborhood)
                TextField("Address", text: $address)
                TextField("Nightly Rate (USD)", text: $rateText)
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Create") {
                    let property = Property(
                        id: UUID().uuidString,
                        name: name.trimmingCharacters(in: .whitespaces),
                        neighborhood: neighborhood.trimmingCharacters(in: .whitespaces),
                        address: address.trimmingCharacters(in: .whitespaces),
                        baseRate: rate!,
                        status: .active
                    )
                    store.add(property)
                    onCreated(property)
                    dismiss()
                }
                .disabled(!isValid)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
}
```

- [ ] **Step 2: Wire "+" button in `SidebarView.swift`**

Replace the entire file:

```swift
import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var store: PropertyStore
    @Binding var selectedID: Property.ID?
    var onAdd: (Property) -> Void

    @State private var showAddProperty = false

    var body: some View {
        List(store.properties, selection: $selectedID) { property in
            VStack(alignment: .leading, spacing: 2) {
                Text(property.name)
                    .fontWeight(.medium)
                Text(property.neighborhood)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Properties")
        .toolbar {
            ToolbarItem {
                Button {
                    showAddProperty = true
                } label: {
                    Label("Add Property", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddProperty) {
            AddPropertySheet { property in
                onAdd(property)
            }
        }
    }
}
```

- [ ] **Step 3: Build and verify**

**Cmd+R** — a "+" button appears in the sidebar toolbar. Click it — a sheet opens with Name, Neighborhood, Address, Nightly Rate fields. Leave Name blank — Create is disabled. Fill all fields — Create is enabled. Press Create (or Return) — sheet closes, new property appears in the sidebar selected, inspector opens automatically showing its details. Quit and relaunch — new property still there.

- [ ] **Step 4: Commit**

```bash
git add CozumelManager/CozumelManager/Views/AddPropertySheet.swift \
        CozumelManager/CozumelManager/Views/SidebarView.swift
git commit -m "feat: add new property sheet wired to sidebar + inspector"
```

---

## Manual Test Checklist

Run through these before considering the feature done:

- [ ] Edit nightly rate, quit, relaunch — change persists
- [ ] Change property status to Inactive — sidebar still shows it, monthlyRevenue excluded from total
- [ ] Add a date block with valid range — appears in list
- [ ] Try to add block with end ≤ start — Add button is disabled
- [ ] Delete a date block — removed immediately and persisted
- [ ] Add photos via file picker — thumbnails appear
- [ ] Move a picked photo to Trash — placeholder shown, no crash
- [ ] Remove a photo via X button — gone from grid and persisted
- [ ] Add a new property via "+" — appears in sidebar, inspector opens
- [ ] Switch between properties — inspector updates to show selected property's data
- [ ] Close and reopen inspector with pencil button
