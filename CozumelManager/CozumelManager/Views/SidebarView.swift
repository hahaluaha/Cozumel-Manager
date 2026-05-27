import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: PropertyStore
    @Binding var selectedProperty: Property?

    var body: some View {
        List(store.properties, selection: $selectedProperty) { property in
            Text(property.name)
                .tag(property)
        }
        .listStyle(.sidebar)
        .navigationTitle("Properties")
    }
}
