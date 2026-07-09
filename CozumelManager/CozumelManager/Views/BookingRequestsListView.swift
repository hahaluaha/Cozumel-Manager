import SwiftUI

struct BookingRequestsListView: View {
    @EnvironmentObject private var bookingStore: BookingRequestStore
    @EnvironmentObject private var store: PropertyStore
    @Binding var selection: String?

    var body: some View {
        List(selection: $selection) {
            ForEach(BookingRequest.sortedForList(bookingStore.requests)) { request in
                VStack(alignment: .leading, spacing: 2) {
                    Text(request.fullName).fontWeight(.medium)
                    Text(propertyName(for: request.propertyId))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    statusBadge(for: request.status)
                }
                .tag(request.id)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Booking Requests")
    }

    private func propertyName(for propertyId: String) -> String {
        store.properties.first { $0.id == propertyId }?.name ?? "Unknown Property"
    }

    private func statusBadge(for status: BookingStatus) -> some View {
        let (label, color): (String, Color) = switch status {
        case .pending: ("Pending", .orange)
        case .approved: ("Approved", .blue)
        case .denied: ("Denied", .secondary)
        case .invoiceSending: ("Sending Invoice…", .blue)
        case .invoiced: ("Invoiced", .purple)
        case .paid: ("Paid", .green)
        }
        return Text(label)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(color)
    }
}
