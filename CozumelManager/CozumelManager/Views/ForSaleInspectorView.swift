import SwiftUI
import UniformTypeIdentifiers

struct ForSaleInspectorView: View {
    @EnvironmentObject private var forSaleStore: ForSaleStore
    let property: ForSaleProperty
    @State private var draft: ForSaleProperty

    init(property: ForSaleProperty) {
        self.property = property
        _draft = State(initialValue: property)
    }

    var body: some View {
        Form {
            detailsSection
            Section("Description") {
                TextEditor(text: $draft.description)
                    .frame(minHeight: 80)
                Button("Save Description") { commit() }
            }
            Section("Notes") {
                TextEditor(text: $draft.notes)
                    .frame(minHeight: 80)
                Button("Save Notes") { commit() }
            }
            photosSection
        }
        .formStyle(.grouped)
        .navigationTitle("Edit Property")
        .onReceive(forSaleStore.$properties) { newProperties in
            guard let fresh = newProperties.first(where: { $0.id == draft.id }) else { return }
            draft = fresh
        }
    }

    private func commit() {
        forSaleStore.update(draft)
    }

    // MARK: - Details

    private var detailsSection: some View {
        Section("Details") {
            LabeledContent("Name") {
                TextField("", text: $draft.name)
                    .multilineTextAlignment(.trailing)
                    .onSubmit { commit() }
            }
            LabeledContent("Asking Price") {
                TextField("", value: $draft.askingPrice, format: .currency(code: "USD"))
                    .multilineTextAlignment(.trailing)
                    .onSubmit { commit() }
            }
            LabeledContent("Listing URL") {
                HStack {
                    TextField("https://", text: $draft.listingURL)
                        .multilineTextAlignment(.trailing)
                        .onSubmit { commit() }
                    if !draft.listingURL.isEmpty, let url = URL(string: draft.listingURL) {
                        Link(destination: url) {
                            Image(systemName: "arrow.up.right.square")
                        }
                    }
                }
            }
        }
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
        for url in panel.urls { copyPhoto(from: url) }
    }

    private func copyPhoto(from source: URL) {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dest = appSupport
            .appendingPathComponent("CozumelManager/Photos/forsale/\(draft.id)")
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
}
