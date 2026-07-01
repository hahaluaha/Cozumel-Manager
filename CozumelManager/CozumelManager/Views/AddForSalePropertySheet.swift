import SwiftUI

struct AddForSalePropertySheet: View {
    @EnvironmentObject private var forSaleStore: ForSaleStore
    @Environment(\.dismiss) private var dismiss

    var onCreated: (ForSaleProperty) -> Void

    @State private var name = ""
    @State private var priceText = ""

    private var price: Double? {
        Double(priceText.filter { $0.isNumber || $0 == "." })
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (price ?? 0) > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New For Sale Property")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                TextField("Name", text: $name)
                TextField("Asking Price (USD)", text: $priceText)
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Create") {
                    let property = ForSaleProperty(
                        name: name.trimmingCharacters(in: .whitespaces),
                        askingPrice: price!
                    )
                    forSaleStore.add(property)
                    onCreated(property)
                    dismiss()
                }
                .disabled(!isValid)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
}
