import SwiftUI

struct ContentView: View {
    @StateObject private var store = PropertyStore()
    @State private var selectedProperty: Property?

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store, selectedProperty: $selectedProperty)
        } detail: {
            MainDashboardView(property: selectedProperty)
        }
    }
}
