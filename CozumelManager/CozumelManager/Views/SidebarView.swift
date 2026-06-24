import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var store: PropertyStore
    @Binding var selectedID: Property.ID?
    var onAdd: (Property) -> Void

    @State private var showAddProperty = false
    @State private var showAddUser = false
    @State private var showDeleteAlert = false

    private var selectedProperty: Property? {
        store.properties.first { $0.id == selectedID }
    }

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
