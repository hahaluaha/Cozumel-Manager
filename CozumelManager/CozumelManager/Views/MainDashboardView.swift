import SwiftUI

struct MainDashboardView: View {
    @EnvironmentObject private var store: PropertyStore
    @State private var selectedID: Property.ID?

    private var selectedProperty: Property? {
        store.properties.first { $0.id == selectedID }
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedID: $selectedID)
        } detail: {
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
        .onAppear {
            if selectedID == nil {
                selectedID = store.properties.first?.id
            }
        }
        .onChange(of: store.properties) { _, newProperties in
            if let current = selectedID, !newProperties.contains(where: { $0.id == current }) {
                selectedID = newProperties.first?.id
            }
        }
    }
}
