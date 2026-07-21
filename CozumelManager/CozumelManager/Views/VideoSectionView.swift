import SwiftUI
import UniformTypeIdentifiers
import AVKit

struct VideoSectionView: View {
    @Binding var videoURL: URL?
    let destinationDirectory: URL
    let onCommit: () -> Void

    @State private var showDurationWarning = false
    @State private var durationWarningText = ""
    @State private var videoImportToken = UUID()

    var body: some View {
        Section("Video") {
            if let videoURL {
                InlineVideoPlayer(url: videoURL)
                    .frame(height: 200)
                    .id("\(videoURL.absoluteString)#\(videoImportToken)")
                HStack {
                    Button("Replace Video") { pickVideo() }
                    Button(role: .destructive) {
                        removeVideo()
                    } label: {
                        Label("Remove Video", systemImage: "trash")
                    }
                }
            } else {
                Button {
                    pickVideo()
                } label: {
                    Label("Add Video", systemImage: "plus")
                }
            }
        }
        .alert("Video Longer Than 8 Seconds", isPresented: $showDurationWarning) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(durationWarningText)
        }
    }

    private func pickVideo() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let source = panel.urls.first else { return }
        importVideo(from: source)
    }

    private func importVideo(from source: URL) {
        let previous = videoURL
        guard let destFile = try? VideoImporter.copy(from: source, into: destinationDirectory) else {
            return
        }
        if let previous, previous != destFile {
            try? FileManager.default.removeItem(at: previous)
        }
        videoURL = destFile
        videoImportToken = UUID()
        onCommit()

        Task {
            if let seconds = await VideoImporter.duration(of: destFile), VideoImporter.isOverLimit(seconds) {
                await MainActor.run {
                    durationWarningText = "This video is \(Int(seconds))s — longer than the 8s AI Studio limit. It was uploaded anyway."
                    showDurationWarning = true
                }
            }
        }
    }

    private func removeVideo() {
        if let existing = videoURL {
            try? FileManager.default.removeItem(at: existing)
        }
        videoURL = nil
        onCommit()
    }
}

private struct InlineVideoPlayer: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = AVPlayer(url: url)
        view.controlsStyle = .inline
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {}
}
