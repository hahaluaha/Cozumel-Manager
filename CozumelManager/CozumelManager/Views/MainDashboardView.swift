import SwiftUI

struct MainDashboardView: View {
    @StateObject private var store = PropertyStore()
    @State private var selectedID: String?

    private var selectedProperty: Property? {
        store.properties.first { $0.id == selectedID }
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store, selectedID: $selectedID)
        } detail: {
            if let property = selectedProperty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(property.name)
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                    Text(property.neighborhood)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("$\(Int(property.baseRate)) / night")
                        .font(.title3)
                    Text("Est. $\(Int(property.monthlyRevenue)) / month")
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
}
