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
