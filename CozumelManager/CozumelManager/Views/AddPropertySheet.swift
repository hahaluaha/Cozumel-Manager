import SwiftUI

struct AddPropertySheet: View {
    @EnvironmentObject private var store: PropertyStore
    @Environment(\.dismiss) private var dismiss

    var onCreated: (Property) -> Void

    @State private var name = ""
    @State private var neighborhood = ""
    @State private var address = ""
    @State private var rateText = ""

    private var rate: Double? {
        Double(rateText.filter { $0.isNumber || $0 == "." })
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !neighborhood.trimmingCharacters(in: .whitespaces).isEmpty &&
        !address.trimmingCharacters(in: .whitespaces).isEmpty &&
        (rate ?? 0) > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Property")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                TextField("Name", text: $name)
                TextField("Neighborhood", text: $neighborhood)
                TextField("Address", text: $address)
                TextField("Nightly Rate (USD)", text: $rateText)
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Create") {
                    let property = Property(
                        id: UUID().uuidString,
                        name: name.trimmingCharacters(in: .whitespaces),
                        neighborhood: neighborhood.trimmingCharacters(in: .whitespaces),
                        address: address.trimmingCharacters(in: .whitespaces),
                        baseRate: rate!,
                        status: .active
                    )
                    store.add(property)
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
