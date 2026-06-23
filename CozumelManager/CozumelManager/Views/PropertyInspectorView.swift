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
