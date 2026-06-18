import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: PropertyStore
    @Binding var selectedID: String?

    var body: some View {
        List(store.properties, id: \.id, selection: $selectedID) { property in
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
