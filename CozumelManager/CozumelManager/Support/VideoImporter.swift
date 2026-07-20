import Foundation
import AVFoundation

enum VideoImporter {
    static let warnDurationSeconds: Double = 8.0

    /// Copies `source` into `directory` (creating it if needed) and returns the destination URL.
    /// If a file with the same name already exists at the destination, it is left untouched.
    static func copy(from source: URL, into directory: URL) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destFile = directory.appendingPathComponent(source.lastPathComponent)
        if !FileManager.default.fileExists(atPath: destFile.path) {
            try FileManager.default.copyItem(at: source, to: destFile)
        }
        return destFile
    }

    static func duration(of url: URL) async -> Double? {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration) else { return nil }
        let seconds = CMTimeGetSeconds(duration)
        return seconds.isFinite ? seconds : nil
    }

    static func isOverLimit(_ seconds: Double) -> Bool {
        seconds > warnDurationSeconds
    }
}
