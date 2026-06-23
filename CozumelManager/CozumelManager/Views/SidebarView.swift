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
