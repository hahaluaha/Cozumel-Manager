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
