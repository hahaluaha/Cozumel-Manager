import SwiftUI
import UniformTypeIdentifiers
import Combine

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
            if draft.id == "prop-003" {
                guestPricingSection
            }
            availabilitySection
            photosSection
            videoSection
        }
        .formStyle(.grouped)
        .navigationTitle("Edit Property")
        .onReceive(store.$properties) { newProperties in
            guard let fresh = newProperties.first(where: { $0.id == draft.id }) else { return }
            draft = fresh
        }
    }

    private func commit() {
        store.update(draft)
    }

    private var monthlyPriceBinding: Binding<Double> {
        Binding(
            get: { draft.monthlyPrice ?? 0 },
            set: { draft.monthlyPrice = $0 == 0 ? nil : $0 }
        )
    }

    private var baseGuestsBinding: Binding<Int> {
        Binding(
            get: { draft.baseGuests ?? 0 },
            set: { draft.baseGuests = $0 == 0 ? nil : $0 }
        )
    }

    private var maxGuestsBinding: Binding<Int> {
        Binding(
            get: { draft.maxGuests ?? 0 },
            set: { draft.maxGuests = $0 == 0 ? nil : $0 }
        )
    }

    private var extraGuestFeeBinding: Binding<Double> {
        Binding(
            get: { draft.extraGuestFee ?? 0 },
            set: { draft.extraGuestFee = $0 == 0 ? nil : $0 }
        )
    }

    private func statusLabel(_ status: PropertyStatus) -> String {
        switch status {
        case .active: return "Active"
        case .inactive: return "Inactive"
        case .maintenance: return "Maintenance"
        }
    }

    private func setStatus(_ status: PropertyStatus) {
        draft.status = status
        commit()
    }

    // MARK: - Photos

    private var photosSection: some View {
        Section("Photos") {
            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(draft.photos, id: \.self) { url in
                    photoThumbnail(for: url)
                }
            }
            .padding(.vertical, 4)

            Button {
                pickPhotos()
            } label: {
                Label("Add Photos", systemImage: "plus")
            }
        }
    }

    @ViewBuilder
    private func photoThumbnail(for url: URL) -> some View {
        ZStack(alignment: .topTrailing) {
            if let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .quaternaryLabelColor))
                    .frame(width: 80, height: 80)
                    .overlay {
                        Image(systemName: "photo.badge.exclamationmark")
                            .foregroundStyle(.secondary)
                    }
            }

            Button {
                draft.photos.removeAll { $0 == url }
                commit()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white, .black)
                    .padding(4)
            }
            .buttonStyle(.plain)
        }
    }

    private func pickPhotos() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            copyPhoto(from: url)
        }
    }

    private func copyPhoto(from source: URL) {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dest = appSupport
            .appendingPathComponent("CozumelManager/Photos/\(draft.id)")
        try? FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        let destFile = dest.appendingPathComponent(source.lastPathComponent)
        if !FileManager.default.fileExists(atPath: destFile.path) {
            try? FileManager.default.copyItem(at: source, to: destFile)
        }
        if !draft.photos.contains(destFile) {
            draft.photos.append(destFile)
            commit()
        }
    }

    // MARK: - Video

    private var videoSection: some View {
        VideoSectionView(videoURL: $draft.videoURL, destinationDirectory: videoDirectory, onCommit: commit)
    }

    private var videoDirectory: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("CozumelManager/Videos/\(draft.id)")
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
                    .onSubmit { commit() }
            }
            LabeledContent("Neighborhood") {
                TextField("", text: $draft.neighborhood)
                    .multilineTextAlignment(.trailing)
                    .onSubmit { commit() }
            }
            LabeledContent("Address") {
                TextField("", text: $draft.address)
                    .multilineTextAlignment(.trailing)
                    .onSubmit { commit() }
            }
            LabeledContent("Nightly Rate") {
                TextField("", value: $draft.baseRate, format: .currency(code: "USD"))
                    .multilineTextAlignment(.trailing)
                    .onSubmit { commit() }
            }
            LabeledContent("Monthly Price") {
                TextField("Not set", value: monthlyPriceBinding, format: .currency(code: "USD"))
                    .multilineTextAlignment(.trailing)
                    .onSubmit { commit() }
            }
            LabeledContent("Status") {
                Menu(statusLabel(draft.status)) {
                    Button("Active") { setStatus(.active) }
                    Button("Inactive") { setStatus(.inactive) }
                    Button("Maintenance") { setStatus(.maintenance) }
                }
            }
        }
    }

    // MARK: - Guest Pricing

    private var guestPricingSection: some View {
        Section("Guest Pricing") {
            LabeledContent("Base Guests") {
                TextField("", value: baseGuestsBinding, format: .number)
                    .multilineTextAlignment(.trailing)
                    .onSubmit { commit() }
            }
            LabeledContent("Max Guests") {
                TextField("", value: maxGuestsBinding, format: .number)
                    .multilineTextAlignment(.trailing)
                    .onSubmit { commit() }
            }
            LabeledContent("Extra Guest Fee") {
                TextField("Not set", value: extraGuestFeeBinding, format: .currency(code: "USD"))
                    .multilineTextAlignment(.trailing)
                    .onSubmit { commit() }
            }
            Text(guestPricingSummary)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var guestPricingSummary: String {
        guard let baseGuests = draft.baseGuests,
              let maxGuests = draft.maxGuests,
              let extraGuestFee = draft.extraGuestFee else {
            return "Set base guests, max guests, and extra guest fee to see a summary."
        }
        let baseRateText = draft.baseRate.formatted(.currency(code: "USD"))
        let maxRateText = draft.nightlyRate(forGuests: maxGuests).formatted(.currency(code: "USD"))
        let feeText = extraGuestFee.formatted(.currency(code: "USD"))
        return "Up to \(baseGuests) guests: \(baseRateText)/night. \(baseGuests + 1)–\(maxGuests) guests: +\(feeText)/guest (up to \(maxRateText)/night at \(maxGuests))."
    }
}
