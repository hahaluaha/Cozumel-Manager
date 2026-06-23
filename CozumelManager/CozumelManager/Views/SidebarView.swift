import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var store: PropertyStore
    @Binding var selectedID: Property.ID?
    var onAdd: (Property) -> Void

    @State private var showAddProperty = false
    @State private var showAddUser = false

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
                Menu {
                    Button("Add Property") { showAddProperty = true }
                    Button("Add User") { showAddUser = true }
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddProperty) {
            AddPropertySheet { property in
                onAdd(property)
            }
        }
        .sheet(isPresented: $showAddUser) {
            AddUserPlaceholderSheet()
        }
    }
}
