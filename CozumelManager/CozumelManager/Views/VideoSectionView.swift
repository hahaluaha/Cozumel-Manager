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
        if let existing = videoURL {
            try? FileManager.default.removeItem(at: existing)
        }
        guard let destFile = try? VideoImporter.copy(from: source, into: destinationDirectory) else {
            videoURL = nil
            onCommit()
            return
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

private struct InlineVideoPlayer: View {
    let url: URL
    @State private var player: AVPlayer

    init(url: URL) {
        self.url = url
        _player = State(initialValue: AVPlayer(url: url))
    }

    var body: some View {
        VideoPlayer(player: player)
            .frame(height: 200)
    }
}
