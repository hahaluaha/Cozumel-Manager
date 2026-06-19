import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var store: PropertyStore
    @Binding var selectedID: Property.ID?

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
