# Delete Property Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a trash button to the sidebar toolbar that deletes the selected property after a confirmation alert.

**Architecture:** `PropertyStore` gains a `delete(id:)` method (model layer). `SidebarView` gains a trash `ToolbarItem` and a confirmation alert (view layer). No other files change.

**Tech Stack:** SwiftUI (macOS 14+), Swift Testing framework (`import Testing`, `#expect`), local JSON persistence via `PropertyStore`.

## Global Constraints

- Target: macOS 14+, Mac Silicon
- Test framework: Swift Testing (`import Testing`, `@Test`, `#expect`) — not XCTest
- No new dependencies
- `Property.Hashable` uses `id` only — do not change
- `PropertyStore` is injected via `.environmentObject` — never recreated in views

---

### Task 1: Add `delete(id:)` to PropertyStore

**Files:**
- Modify: `CozumelManager/CozumelManager/Models/PropertyModel.swift`
- Test: `CozumelManager/CozumelManagerTests/CozumelManagerTests.swift`

**Interfaces:**
- Produces: `PropertyStore.delete(id: String)` — removes property with matching id from `properties` array and persists to disk

- [ ] **Step 1: Write the failing tests**

Open `CozumelManager/CozumelManagerTests/CozumelManagerTests.swift`. At the end of the `PropertyStoreTests` struct (after the last `@Test` and before the closing `}`), add:

```swift
@Test func store_delete_removesPropertyById() {
    let p1 = Property(id: "p1", name: "A", neighborhood: "N", address: "A", baseRate: 100, status: .active)
    let p2 = Property(id: "p2", name: "B", neighborhood: "N", address: "B", baseRate: 200, status: .active)
    let store = makeStore(properties: [p1, p2])
    store.delete(id: "p1")
    #expect(store.properties.count == 1)
    #expect(store.properties[0].id == "p2")
}

@Test func store_delete_persistsRemovalToDisk() {
    let p1 = Property(id: "p1", name: "A", neighborhood: "N", address: "A", baseRate: 100, status: .active)
    let p2 = Property(id: "p2", name: "B", neighborhood: "N", address: "B", baseRate: 200, status: .active)
    let store = makeStore(properties: [p1, p2])
    store.delete(id: "p1")
    let reloaded = PropertyStore(storeURL: store.storeURL)
    #expect(reloaded.properties.count == 1)
    #expect(reloaded.properties[0].id == "p2")
}
```

- [ ] **Step 2: Run tests to verify they fail**

In Xcode: `Cmd+U`

Or from the terminal:
```bash
xcodebuild test \
  -project CozumelManager/CozumelManager.xcodeproj \
  -scheme CozumelManager \
  -destination 'platform=macOS' 2>&1 | grep -E "Test.*failed|error:|Build FAILED"
```

Expected: both new tests fail with a compiler error — `value of type 'PropertyStore' has no member 'delete'`

- [ ] **Step 3: Implement `delete(id:)` in PropertyStore**

Open `CozumelManager/CozumelManager/Models/PropertyModel.swift`. After the `add(_ property:)` method (around line 65), add:

```swift
func delete(id: String) {
    properties.removeAll { $0.id == id }
    saveToDisk()
}
```

- [ ] **Step 4: Run tests to verify they pass**

In Xcode: `Cmd+U`

Or from terminal (same command as Step 2).

Expected: all tests pass, including the two new ones.

- [ ] **Step 5: Commit**

```bash
git add CozumelManager/CozumelManager/Models/PropertyModel.swift \
        CozumelManager/CozumelManagerTests/CozumelManagerTests.swift
git commit -m "feat: add PropertyStore.delete(id:) with persistence"
```

---

### Task 2: Add trash button and confirmation alert to SidebarView

**Files:**
- Modify: `CozumelManager/CozumelManager/Views/SidebarView.swift`

**Interfaces:**
- Consumes: `PropertyStore.delete(id: String)` from Task 1
- Consumes: `selectedID: Binding<Property.ID?>` (already passed in from `MainDashboardView`)

- [ ] **Step 1: Add delete state and computed property**

Open `CozumelManager/CozumelManager/Views/SidebarView.swift`. Replace the existing `@State` block and add a computed property so the top of the struct reads:

```swift
@State private var showAddProperty = false
@State private var showAddUser = false
@State private var showDeleteAlert = false

private var selectedProperty: Property? {
    store.properties.first { $0.id == selectedID }
}
```

- [ ] **Step 2: Add the trash ToolbarItem**

Replace the existing `.toolbar` modifier with:

```swift
.toolbar {
    ToolbarItem {
        Button {
            showDeleteAlert = true
        } label: {
            Image(systemName: "trash")
        }
        .disabled(selectedID == nil)
    }
    ToolbarItem {
        Menu {
            Button("Add Property") { showAddProperty = true }
            Button("Add User") { showAddUser = true }
        } label: {
            Label("Add", systemImage: "plus")
        }
    }
}
```

- [ ] **Step 3: Add the confirmation alert**

Add the following modifier after the `.toolbar { }` block and before the `.sheet(isPresented: $showAddProperty)` modifier:

```swift
.alert("Delete \(selectedProperty?.name ?? "Property")?", isPresented: $showDeleteAlert) {
    Button("Delete", role: .destructive) {
        if let id = selectedID {
            store.delete(id: id)
        }
    }
    Button("Cancel", role: .cancel) {}
} message: {
    Text("This cannot be undone.")
}
```

- [ ] **Step 4: Build and manually verify**

Build with `Cmd+B` — no compiler errors expected.

Run with `Cmd+R` and verify:

1. With no property selected: trash button is grayed out and unclickable.
2. Select a property → trash button becomes active.
3. Click trash → alert appears with the property name in the title and "This cannot be undone." as the message.
4. Click **Cancel** → alert dismisses, property remains in sidebar.
5. Click trash again → click **Delete** → property is removed from the sidebar and the next property is auto-selected (or sidebar shows empty if none remain).
6. Quit and relaunch the app → deleted property does not reappear (confirms disk persistence).

- [ ] **Step 5: Commit**

```bash
git add CozumelManager/CozumelManager/Views/SidebarView.swift
git commit -m "feat: add trash button with confirmation alert to sidebar toolbar"
```
