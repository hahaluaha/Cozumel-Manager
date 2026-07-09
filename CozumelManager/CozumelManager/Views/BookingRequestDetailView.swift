import SwiftUI
import AppKit

struct BookingRequestDetailView: View {
    @EnvironmentObject private var bookingStore: BookingRequestStore
    let request: BookingRequest
    let property: Property

    private var conflicts: [BookingRequest] {
        bookingStore.conflictingRequests(for: request)
    }

    private var blockedDateConflict: Bool {
        property.unavailableDateRanges.contains {
            BookingRequest.dateRangesOverlap(request.startDate, request.endDate, $0.start, $0.end)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(request.fullName)
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                Text(property.name)
                    .font(.title2)
                    .foregroundStyle(.secondary)

                Group {
                    labeledRow("Email", request.email)
                    labeledRow("Location", "\(request.state), \(request.country)")
                    labeledRow("Dates", dateRangeText)
                    labeledRow("Guests", "\(request.guestCount)")
                    if !request.notes.isEmpty {
                        labeledRow("Notes", request.notes)
                    }
                }

                if blockedDateConflict {
                    conflictBanner("These dates overlap the property's blocked calendar.")
                }
                if !conflicts.isEmpty {
                    conflictBanner("These dates overlap \(conflicts.count) other held/paid request(s).")
                }

                if request.status == .pending {
                    HStack {
                        Button("Approve") {
                            bookingStore.approve(request.id)
                        }
                        Button("Deny", role: .destructive) {
                            denyAndDraftEmail()
                        }
                    }
                } else if request.status == .approved {
                    if let error = request.invoiceError {
                        Text("Invoice error: \(error)")
                            .foregroundStyle(.red)
                    }
                    InvoiceEditorView(request: request, property: property)
                }

                Spacer()
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: request.startDate)) – \(formatter.string(from: request.endDate))"
    }

    private func labeledRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
        }
    }

    private func conflictBanner(_ message: String) -> some View {
        Text(message)
            .font(.callout)
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func denyAndDraftEmail() {
        bookingStore.deny(request.id)
        let subject = "Regarding your booking request at \(property.name)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "mailto:\(request.email)?subject=\(subject)") else { return }
        NSWorkspace.shared.open(url)
    }
}
