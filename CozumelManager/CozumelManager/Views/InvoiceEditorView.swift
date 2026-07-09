import SwiftUI

struct InvoiceEditorView: View {
    @EnvironmentObject private var bookingStore: BookingRequestStore
    let request: BookingRequest
    let property: Property

    @State private var lineItems: [InvoiceLineItem]
    @State private var newDescription = ""
    @State private var newAmount = ""

    init(request: BookingRequest, property: Property) {
        self.request = request
        self.property = property
        let initial = request.invoiceLineItems.isEmpty
            ? BookingRequest.autoLineItems(for: request, property: property)
            : request.invoiceLineItems
        _lineItems = State(initialValue: initial)
    }

    private var total: Double {
        lineItems.reduce(0) { $0 + $1.total }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Invoice").font(.headline)

            ForEach($lineItems) { $item in
                HStack {
                    TextField("Description", text: $item.itemDescription)
                    TextField("Qty", value: $item.quantity, format: .number)
                        .frame(width: 50)
                    TextField("Amount", value: $item.unitAmount, format: .currency(code: "USD"))
                        .frame(width: 100)
                    Text(item.total, format: .currency(code: "USD"))
                        .frame(width: 90, alignment: .trailing)
                }
            }

            HStack {
                TextField("New line description", text: $newDescription)
                TextField("Amount", text: $newAmount)
                    .frame(width: 100)
                Button("Add Line") {
                    guard !newDescription.isEmpty, let amount = Double(newAmount) else { return }
                    lineItems.append(InvoiceLineItem(itemDescription: newDescription, quantity: 1, unitAmount: amount))
                    newDescription = ""
                    newAmount = ""
                }
            }

            HStack {
                Text("Total").fontWeight(.semibold)
                Spacer()
                Text(total, format: .currency(code: "USD")).fontWeight(.semibold)
            }

            Button("Send Invoice") {
                bookingStore.sendInvoice(for: request.id, lineItems: lineItems)
            }
            .disabled(request.status != .approved || lineItems.isEmpty)
        }
    }
}
