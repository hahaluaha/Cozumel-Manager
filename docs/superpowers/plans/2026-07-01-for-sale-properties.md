# For Sale Properties Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "For Sale" section to the sidebar with its own model, store, inspector, and add sheet — fully independent from the rental properties system.

**Architecture:** New `ForSaleProperty` model + `ForSaleStore` mirror the existing `Property`/`PropertyStore` pattern exactly. `SidebarView` gains a second `Section` using a new `SidebarSelection` enum to unify rental and for-sale selection into a single `List` binding. `MainDashboardView` derives the selected entity from `SidebarSelection` and routes to either `PropertyInspectorView` or the new `ForSaleInspectorView`.

**Tech Stack:** SwiftUI, macOS 14+, `Combine` (`ObservableObject`/`@Published`), `Foundation` (`JSONEncoder`/`JSONDecoder`, `FileManager`)

## Global Constraints

- Target: macOS 14+. Use `onChange(of:) { _, newValue in }` two-argument form throughout.
- All new `ObservableObject` stores injected via `.environmentObject` — never recreated in views.
- `Hashable` conformance uses `id` only — never full-field synthesis.
- No status field on `ForSaleProperty` — presence in the section implies for sale.
- Seed JSON must be added to Xcode target AND the Copy Bundle Resources build phase.
- Build after every task with Cmd+B before committing.

---

### Task 1: `ForSaleProperty` model + seed JSON

**Files:**
- Create: `CozumelManager/CozumelManager/Models/ForSaleProperty.swift`
- Create: `CozumelManager/CozumelManager/forSaleProperties.json`

**Interfaces:**
- Produces: `ForSaleProperty` struct used by Tasks 2, 3, 4, 5

---

- [ ] **Step 1: Create `ForSaleProperty.swift`**

  Full content of `CozumelManager/CozumelManager/Models/ForSaleProperty.swift`:

  ```swift
  import Foundation

  struct ForSaleProperty: Identifiable, Hashable, Codable {
      var id: UUID
      var name: String
      var description: String
      var askingPrice: Double
      var listingURL: String
      var photos: [URL]
      var notes: String

      init(
          id: UUID = UUID(),
          name: String,
          description: String = "",
          askingPrice: Double,
          listingURL: String = "",
          photos: [URL] = [],
          notes: String = ""
      ) {
          self.id = id
          self.name = name
          self.description = description
          self.askingPrice = askingPrice
          self.listingURL = listingURL
          self.photos = photos
          self.notes = notes
      }

      static func == (lhs: ForSaleProperty, rhs: ForSaleProperty) -> Bool { lhs.id == rhs.id }
      func hash(into hasher: inout Hasher) { hasher.combine(id) }
  }
  ```

- [ ] **Step 2: Create `forSaleProperties.json`**

  Full content of `CozumelManager/CozumelManager/forSaleProperties.json`:

  ```json
  {
    "properties": [
      {
        "id": "550e8400-e29b-41d4-a716-446655440001",
        "name": "Cozumel House for Sale",
        "description": "",
        "askingPrice": 0.0,
        "listingURL": "https://cozumelhomes.net/en/4134544/cozumel-house-for-sale1",
        "photos": [],
        "notes": ""
      }
    ]
  }
  ```

- [ ] **Step 3: Add both files to the Xcode target**

  In Xcode's Project Navigator:
  - Right-click the `Models` group → **Add Files to "CozumelManager"** → select `ForSaleProperty.swift`. Ensure **Add to target: CozumelManager** is checked.
  - Right-click the `CozumelManager` (inner) group → **Add Files to "CozumelManager"** → select `forSaleProperties.json`. Ensure **Add to target: CozumelManager** is checked AND the file appears under **Copy Bundle Resources** in Build Phases.

- [ ] **Step 4: Build to verify**

  Press **Cmd+B** in Xcode.
  Expected: Build succeeded, no errors.

- [ ] **Step 5: Commit**

  ```bash
  git add CozumelManager/CozumelManager/Models/ForSaleProperty.swift \
          CozumelManager/CozumelManager/forSaleProperties.json
  git commit -m "feat: add ForSaleProperty model and seed JSON"
  ```

---

### Task 2: `ForSaleStore`

**Files:**
- Create: `CozumelManager/CozumelManager/Models/ForSaleModel.swift`

**Interfaces:**
- Consumes: `ForSaleProperty` from Task 1
- Produces: `ForSaleStore` class with `add(_:)`, `update(_:)`, `delete(id:)`, `saveToDisk()`, `@Published var properties: [ForSaleProperty]`

---

- [ ] **Step 1: Create `ForSaleModel.swift`**

  Full content of `CozumelManager/CozumelManager/Models/ForSaleModel.swift`:

  ```swift
  import Foundation
  import Combine

  private struct ForSalePropertyList: Codable {
      var properties: [ForSaleProperty]
  }

  class ForSaleStore: ObservableObject {
      @Published var properties: [ForSaleProperty] = []

      let storeURL: URL

      init(storeURL: URL? = nil) {
          self.storeURL = storeURL ?? ForSaleStore.defaultStoreURL()
          load()
      }

      private static func defaultStoreURL() -> URL {
          let appSupport = FileManager.default.urls(
              for: .applicationSupportDirectory, in: .userDomainMask)[0]
          let appDir = appSupport.appendingPathComponent("CozumelManager")
          try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
          return appDir.appendingPathComponent("forSaleProperties.json")
      }

      private func load() {
          if !FileManager.default.fileExists(atPath: storeURL.path) {
              migrateFromBundle()
          }
          guard let data = try? Data(contentsOf: storeURL) else { return }
          guard let list = try? JSONDecoder().decode(ForSalePropertyList.self, from: data) else { return }
          properties = list.properties
      }

      private func migrateFromBundle() {
          guard let src = Bundle.main.url(forResource: "forSaleProperties", withExtension: "json") else { return }
          try? FileManager.default.copyItem(at: src, to: storeURL)
      }

      func add(_ property: ForSaleProperty) {
          properties.append(property)
          saveToDisk()
      }

      func update(_ property: ForSaleProperty) {
          guard let i = properties.firstIndex(where: { $0.id == property.id }) else { return }
          properties[i] = property
          saveToDisk()
      }

      func delete(id: UUID) {
          properties.removeAll { $0.id == id }
          saveToDisk()
      }

      func saveToDisk() {
          let encoder = JSONEncoder()
          encoder.outputFormatting = .prettyPrinted
          guard let data = try? encoder.encode(ForSalePropertyList(properties: properties)) else { return }
          try? data.write(to: storeURL)
      }
  }
  ```

- [ ] **Step 2: Add to Xcode target**

  In Xcode: right-click the `Models` group → **Add Files to "CozumelManager"** → select `ForSaleModel.swift`. Ensure **Add to target: CozumelManager** is checked.

- [ ] **Step 3: Build to verify**

  Press **Cmd+B**. Expected: Build succeeded.

- [ ] **Step 4: Commit**

  ```bash
  git add CozumelManager/CozumelManager/Models/ForSaleModel.swift
  git commit -m "feat: add ForSaleStore"
  ```

---

### Task 3: `AddForSalePropertySheet`

**Files:**
- Create: `CozumelManager/CozumelManager/Views/AddForSalePropertySheet.swift`

**Interfaces:**
- Consumes: `ForSaleStore` (Task 2), `ForSaleProperty` (Task 1)
- Produces: `AddForSalePropertySheet` view with `onCreated: (ForSaleProperty) -> Void` callback

---

- [ ] **Step 1: Create `AddForSalePropertySheet.swift`**

  Full content of `CozumelManager/CozumelManager/Views/AddForSalePropertySheet.swift`:

  ```swift
  import SwiftUI

  struct AddForSalePropertySheet: View {
      @EnvironmentObject private var forSaleStore: ForSaleStore
      @Environment(\.dismiss) private var dismiss

      var onCreated: (ForSaleProperty) -> Void

      @State private var name = ""
      @State private var priceText = ""

      private var price: Double? {
          Double(priceText.filter { $0.isNumber || $0 == "." })
      }

      private var isValid: Bool {
          !name.trimmingCharacters(in: .whitespaces).isEmpty && (price ?? 0) > 0
      }

      var body: some View {
          VStack(alignment: .leading, spacing: 16) {
              Text("New For Sale Property")
                  .font(.title2)
                  .fontWeight(.semibold)

              Form {
                  TextField("Name", text: $name)
                  TextField("Asking Price (USD)", text: $priceText)
              }
              .formStyle(.grouped)

              HStack {
                  Spacer()
                  Button("Cancel") { dismiss() }
                  Button("Create") {
                      let property = ForSaleProperty(
                          name: name.trimmingCharacters(in: .whitespaces),
                          askingPrice: price!
                      )
                      forSaleStore.add(property)
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

- [ ] **Step 2: Add to Xcode target**

  In Xcode: right-click the `Views` group → **Add Files to "CozumelManager"** → select `AddForSalePropertySheet.swift`. Ensure **Add to target: CozumelManager** is checked.

- [ ] **Step 3: Build to verify**

  Press **Cmd+B**. Expected: Build succeeded.

- [ ] **Step 4: Commit**

  ```bash
  git add CozumelManager/CozumelManager/Views/AddForSalePropertySheet.swift
  git commit -m "feat: add AddForSalePropertySheet"
  ```

---

### Task 4: `ForSaleInspectorView`

**Files:**
- Create: `CozumelManager/CozumelManager/Views/ForSaleInspectorView.swift`

**Interfaces:**
- Consumes: `ForSaleStore` (Task 2), `ForSaleProperty` (Task 1)
- Produces: `ForSaleInspectorView` — init takes `property: ForSaleProperty`, reads/writes via `forSaleStore` environment object

---

- [ ] **Step 1: Create `ForSaleInspectorView.swift`**

  Full content of `CozumelManager/CozumelManager/Views/ForSaleInspectorView.swift`:

  ```swift
  import SwiftUI
  import UniformTypeIdentifiers

  struct ForSaleInspectorView: View {
      @EnvironmentObject private var forSaleStore: ForSaleStore
      let property: ForSaleProperty
      @State private var draft: ForSaleProperty

      init(property: ForSaleProperty) {
          self.property = property
          _draft = State(initialValue: property)
      }

      var body: some View {
          Form {
              detailsSection
              photosSection
          }
          .formStyle(.grouped)
          .navigationTitle("Edit Property")
          .onReceive(forSaleStore.$properties) { newProperties in
              guard let fresh = newProperties.first(where: { $0.id == draft.id }) else { return }
              draft = fresh
          }
      }

      private func commit() {
          forSaleStore.update(draft)
      }

      // MARK: - Details

      private var detailsSection: some View {
          Section("Details") {
              LabeledContent("Name") {
                  TextField("", text: $draft.name)
                      .multilineTextAlignment(.trailing)
                      .onChange(of: draft.name) { _, _ in commit() }
              }
              LabeledContent("Asking Price") {
                  TextField("", value: $draft.askingPrice, format: .currency(code: "USD"))
                      .multilineTextAlignment(.trailing)
                      .onChange(of: draft.askingPrice) { _, _ in commit() }
              }
              LabeledContent("Listing URL") {
                  HStack {
                      TextField("https://", text: $draft.listingURL)
                          .multilineTextAlignment(.trailing)
                          .onChange(of: draft.listingURL) { _, _ in commit() }
                      if !draft.listingURL.isEmpty, let url = URL(string: draft.listingURL) {
                          Link(destination: url) {
                              Image(systemName: "arrow.up.right.square")
                          }
                      }
                  }
              }
              LabeledContent("Description") {
                  TextEditor(text: $draft.description)
                      .frame(minHeight: 60)
                      .onChange(of: draft.description) { _, _ in commit() }
              }
              LabeledContent("Notes") {
                  TextEditor(text: $draft.notes)
                      .frame(minHeight: 60)
                      .onChange(of: draft.notes) { _, _ in commit() }
              }
          }
      }

      // MARK: - Photos

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
          for url in panel.urls { copyPhoto(from: url) }
      }

      private func copyPhoto(from source: URL) {
          let appSupport = FileManager.default.urls(
              for: .applicationSupportDirectory, in: .userDomainMask)[0]
          let dest = appSupport
              .appendingPathComponent("CozumelManager/Photos/forsale/\(draft.id)")
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
  }
  ```

- [ ] **Step 2: Add to Xcode target**

  In Xcode: right-click the `Views` group → **Add Files to "CozumelManager"** → select `ForSaleInspectorView.swift`. Ensure **Add to target: CozumelManager** is checked.

- [ ] **Step 3: Build to verify**

  Press **Cmd+B**. Expected: Build succeeded.

- [ ] **Step 4: Commit**

  ```bash
  git add CozumelManager/CozumelManager/Views/ForSaleInspectorView.swift
  git commit -m "feat: add ForSaleInspectorView"
  ```

---

### Task 5: Wire everything — app entry, `SidebarSelection`, `SidebarView`, `MainDashboardView`

**Files:**
- Modify: `CozumelManager/CozumelManager/CozumelManagerApp.swift`
- Modify: `CozumelManager/CozumelManager/Views/SidebarView.swift`
- Modify: `CozumelManager/CozumelManager/Views/MainDashboardView.swift`

**Interfaces:**
- Consumes: `ForSaleStore` (Task 2), `AddForSalePropertySheet` (Task 3), `ForSaleInspectorView` (Task 4)
- Produces: fully working two-section sidebar, for-sale detail panel, for-sale inspector

---

- [ ] **Step 1: Update `CozumelManagerApp.swift`**

  Replace the full file content:

  ```swift
  import SwiftUI
  import Sparkle

  @main
  struct CozumelManagerApp: App {
      @StateObject private var store = PropertyStore()
      @StateObject private var forSaleStore = ForSaleStore()
      private let updaterController = SPUStandardUpdaterController(
          startingUpdater: true,
          updaterDelegate: nil,
          userDriverDelegate: nil
      )

      var body: some Scene {
          Window("Cozumel Manager", id: "main") {
              MainDashboardView()
                  .environmentObject(store)
                  .environmentObject(forSaleStore)
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

- [ ] **Step 2: Replace `SidebarView.swift`**

  Replace the full file content:

  ```swift
  import SwiftUI

  enum SidebarSelection: Hashable {
      case rental(String)
      case forSale(UUID)
  }

  struct SidebarView: View {
      @EnvironmentObject var store: PropertyStore
      @EnvironmentObject var forSaleStore: ForSaleStore
      @Binding var selection: SidebarSelection?
      var onAdd: (Property) -> Void
      var onAddForSale: (ForSaleProperty) -> Void

      @State private var showAddProperty = false
      @State private var showAddUser = false
      @State private var showAddForSale = false
      @State private var showDeleteAlert = false
      @State private var showDeleteForSaleAlert = false

      private var selectedProperty: Property? {
          guard case .rental(let id) = selection else { return nil }
          return store.properties.first { $0.id == id }
      }

      private var selectedForSaleProperty: ForSaleProperty? {
          guard case .forSale(let id) = selection else { return nil }
          return forSaleStore.properties.first { $0.id == id }
      }

      var body: some View {
          List(selection: $selection) {
              Section("Rentals") {
                  ForEach(store.properties) { property in
                      VStack(alignment: .leading, spacing: 2) {
                          Text(property.name).fontWeight(.medium)
                          Text(property.neighborhood).font(.caption).foregroundStyle(.secondary)
                      }
                      .tag(SidebarSelection.rental(property.id))
                  }
              }
              Section("For Sale") {
                  ForEach(forSaleStore.properties) { property in
                      VStack(alignment: .leading, spacing: 2) {
                          Text(property.name).fontWeight(.medium)
                          Text(property.askingPrice, format: .currency(code: "USD"))
                              .font(.caption).foregroundStyle(.secondary)
                      }
                      .tag(SidebarSelection.forSale(property.id))
                  }
              }
          }
          .listStyle(.sidebar)
          .navigationTitle("Properties")
          .toolbar {
              ToolbarItem {
                  Button {
                      if selectedProperty != nil { showDeleteAlert = true }
                      else if selectedForSaleProperty != nil { showDeleteForSaleAlert = true }
                  } label: {
                      Image(systemName: "trash")
                  }
                  .disabled(selection == nil)
              }
              ToolbarItem {
                  Menu {
                      Button("Add Rental") { showAddProperty = true }
                      Button("Add For Sale") { showAddForSale = true }
                      Button("Add User") { showAddUser = true }
                  } label: {
                      Label("Add", systemImage: "plus")
                  }
              }
          }
          .alert("Delete \(selectedProperty?.name ?? "Property")?", isPresented: $showDeleteAlert) {
              Button("Delete", role: .destructive) {
                  if case .rental(let id) = selection {
                      store.delete(id: id)
                      selection = store.properties.first.map { .rental($0.id) }
                  }
              }
              Button("Cancel", role: .cancel) {}
          } message: { Text("This cannot be undone.") }
          .alert("Delete \(selectedForSaleProperty?.name ?? "Property")?", isPresented: $showDeleteForSaleAlert) {
              Button("Delete", role: .destructive) {
                  if case .forSale(let id) = selection {
                      forSaleStore.delete(id: id)
                      selection = forSaleStore.properties.first.map { .forSale($0.id) }
                  }
              }
              Button("Cancel", role: .cancel) {}
          } message: { Text("This cannot be undone.") }
          .sheet(isPresented: $showAddProperty) {
              AddPropertySheet { property in onAdd(property) }
          }
          .sheet(isPresented: $showAddForSale) {
              AddForSalePropertySheet { property in onAddForSale(property) }
          }
          .sheet(isPresented: $showAddUser) {
              AddUserPlaceholderSheet()
          }
      }
  }
  ```

- [ ] **Step 3: Replace `MainDashboardView.swift`**

  Replace the full file content:

  ```swift
  import SwiftUI

  struct MainDashboardView: View {
      @EnvironmentObject private var store: PropertyStore
      @EnvironmentObject private var forSaleStore: ForSaleStore
      @State private var selection: SidebarSelection?
      @State private var showInspector = false

      private var selectedProperty: Property? {
          guard case .rental(let id) = selection else { return nil }
          return store.properties.first { $0.id == id }
      }

      private var selectedForSaleProperty: ForSaleProperty? {
          guard case .forSale(let id) = selection else { return nil }
          return forSaleStore.properties.first { $0.id == id }
      }

      var body: some View {
          NavigationSplitView {
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
          } detail: {
              detailContent
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
  }
  ```

- [ ] **Step 4: Build to verify**

  Press **Cmd+B**. Expected: Build succeeded, no errors.

- [ ] **Step 5: Run and verify the golden path**

  Press **Cmd+R**. Verify:
  - Sidebar shows "Rentals" section with the 3 existing properties and "For Sale" section with "Cozumel House for Sale"
  - Selecting a rental property shows rental detail (name, neighborhood, nightly rate, est. monthly) and the pencil toolbar button opens the rental inspector
  - Selecting "Cozumel House for Sale" shows for-sale detail (name, $0.00, "View Listing" link) and the pencil button opens the for-sale inspector
  - In the for-sale inspector: enter a name, asking price, and notes — confirm they persist after quitting and relaunching the app
  - Tap "Add For Sale" from the `+` menu — confirm the add sheet appears, creates a property, selects it, and opens the inspector
  - Delete a for-sale property — confirm it disappears from the sidebar and selection falls back gracefully

- [ ] **Step 6: Commit**

  ```bash
  git add CozumelManager/CozumelManager/CozumelManagerApp.swift \
          CozumelManager/CozumelManager/Views/SidebarView.swift \
          CozumelManager/CozumelManager/Views/MainDashboardView.swift
  git commit -m "feat: wire ForSale section — sidebar, inspector, app entry"
  ```
