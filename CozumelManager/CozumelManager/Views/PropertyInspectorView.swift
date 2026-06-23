import SwiftUI

struct PropertyInspectorView: View {
    @EnvironmentObject private var store: PropertyStore
    let property: Property
    @State private var draft: Property

    // Used by Task 5 (Availability section)
    @State private var showAddBlock: Bool = false
    @State private var blockStart: Date = Date()
    @State private var blockEnd: Date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()

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
