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
            availabilitySection
            photosSection
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
