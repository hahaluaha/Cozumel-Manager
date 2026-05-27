import SwiftUI

struct MainDashboardView: View {
    var property: Property? = nil
    var totalMonthlyRevenue: Double = 0

    private var revenueFormatted: String {
        totalMonthlyRevenue.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Portfolio revenue header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Portfolio Revenue")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(revenueFormatted + " / mo")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }
                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
            .background(.bar)

            Divider()

            // Property detail
            if let property {
                VStack(alignment: .leading, spacing: 8) {
                    Text(property.name)
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                    Text(property.neighborhood)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text(property.address)
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ContentUnavailableView("Select a Property", systemImage: "building.2")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
