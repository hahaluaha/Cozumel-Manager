import SwiftUI

struct PropertyInspectorView: View {
    @EnvironmentObject private var store: PropertyStore
    let property: Property
    @State private var draft: Property
    @State private var showAddBlock = false
    @State private var blockStart = Date()
    @State private var blockEnd = Calendar.current.date(byAdding: .day, value: 1, to: Date())!

    init(property: Property) {
        self.property = property
        _draft = State(initialValue: property)
    }

    var body: some View {
        Form {
            detailsSection
            availabilitySection
        }
        .formStyle(.grouped)
        .navigationTitle("Edit Property")
    }

    private func commit() {
        store.update(draft)
    }

    // MARK: - Availability

    private var availabilitySection: some View {
        Section("Availability") {
            if draft.unavailableDateRanges.isEmpty {
                Text("No blocked dates")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                ForEach(draft.unavailableDateRanges) { range in
                    HStack {
                        Text("\(range.start.formatted(date: .abbreviated, time: .omitted)) – \(range.end.formatted(date: .abbreviated, time: .omitted))")
                            .font(.callout)
                        Spacer()
                        Button {
                            draft.unavailableDateRanges.removeAll { $0.id == range.id }
                            commit()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button("Add Block") {
                blockStart = Date()
                blockEnd = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
                showAddBlock = true
            }
            .popover(isPresented: $showAddBlock, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Block Dates").font(.headline)
                    DatePicker("From", selection: $blockStart, displayedComponents: .date)
                    DatePicker("To", selection: $blockEnd, displayedComponents: .date)
                    HStack {
                        Spacer()
                        Button("Cancel") { showAddBlock = false }
                        Button("Add") {
                            draft.unavailableDateRanges.append(
                                DateRange(start: blockStart, end: blockEnd)
                            )
                            commit()
                            showAddBlock = false
                        }
                        .disabled(blockEnd <= blockStart)
                        .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(16)
                .frame(width: 280)
            }
        }
    }

    // MARK: - Details

    private var detailsSection: some View {
        Section("Details") {
            LabeledContent("Name") {
                TextField("", text: $draft.name)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: draft.name) { _, _ in commit() }
            }
            LabeledContent("Neighborhood") {
                TextField("", text: $draft.neighborhood)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: draft.neighborhood) { _, _ in commit() }
            }
            LabeledContent("Address") {
                TextField("", text: $draft.address)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: draft.address) { _, _ in commit() }
            }
            LabeledContent("Nightly Rate") {
                TextField("", value: $draft.baseRate, format: .currency(code: "USD"))
                    .multilineTextAlignment(.trailing)
                    .onChange(of: draft.baseRate) { _, _ in commit() }
            }
            Picker("Status", selection: $draft.status) {
                Text("Active").tag(PropertyStatus.active)
                Text("Inactive").tag(PropertyStatus.inactive)
                Text("Maintenance").tag(PropertyStatus.maintenance)
            }
            .onChange(of: draft.status) { _, _ in commit() }
        }
    }
}
