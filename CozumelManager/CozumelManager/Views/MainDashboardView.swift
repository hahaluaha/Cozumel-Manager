import SwiftUI

struct MainDashboardView: View {
    @EnvironmentObject private var store: PropertyStore
    @State private var selectedID: Property.ID?
    @State private var showInspector = false

    private var selectedProperty: Property? {
        store.properties.first { $0.id == selectedID }
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedID: $selectedID, onAdd: { property in
                selectedID = property.id
                showInspector = true
            })
        } detail: {
            detailContent
                .inspector(isPresented: $showInspector) {
                    if let property = selectedProperty {
                        PropertyInspectorView(property: property)
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
                        .disabled(selectedProperty == nil)
                    }
                }
        }
        .onAppear {
            if selectedID == nil {
                selectedID = store.properties.first?.id
            }
        }
        .onChange(of: store.properties) { _, newProperties in
            if let current = selectedID,
               !newProperties.contains(where: { $0.id == current }) {
                selectedID = newProperties.first?.id
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
        } else {
            ContentUnavailableView("Select a Property", systemImage: "building.2")
        }
    }
}
