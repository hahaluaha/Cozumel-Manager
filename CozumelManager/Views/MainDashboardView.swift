import SwiftUI

struct MainDashboardView: View {
    let property: Property?

    var body: some View {
        if let property {
            VStack(alignment: .leading, spacing: 12) {
                Text(property.name)
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                Text(property.neighborhood)
                    .font(.title2)
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
