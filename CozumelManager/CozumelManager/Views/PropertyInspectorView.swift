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
