import Foundation
import Testing
@testable import CozumelManager

struct VideoImporterTests {

    private func makeTempFile(named name: String, contents: String = "fake video bytes") throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent(name)
        try contents.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test func copy_placesFileInDestinationDirectory() throws {
        let source = try makeTempFile(named: "clip.mp4")
        let destDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        let result = try VideoImporter.copy(from: source, into: destDir)

        #expect(result.lastPathComponent == "clip.mp4")
        #expect(FileManager.default.fileExists(atPath: result.path))
    }

    @Test func copy_createsDestinationDirectoryIfMissing() throws {
        let source = try makeTempFile(named: "clip.mp4")
        let destDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("nested")

        _ = try VideoImporter.copy(from: source, into: destDir)

        var isDir: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: destDir.path, isDirectory: &isDir))
        #expect(isDir.boolValue)
    }

    @Test func copy_doesNotOverwriteExistingFileWithSameName() throws {
        let source = try makeTempFile(named: "clip.mp4", contents: "new bytes")
        let destDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        let existing = destDir.appendingPathComponent("clip.mp4")
        try "original bytes".write(to: existing, atomically: true, encoding: .utf8)

        let result = try VideoImporter.copy(from: source, into: destDir)

        let resultContents = try String(contentsOf: result, encoding: .utf8)
        #expect(resultContents == "original bytes")
    }

    @Test func isOverLimit_trueWhenAboveEightSeconds() {
        #expect(VideoImporter.isOverLimit(8.1))
        #expect(!VideoImporter.isOverLimit(8.0))
        #expect(!VideoImporter.isOverLimit(3.5))
    }

    @Test func duration_returnsNilForNonVideoFile() async throws {
        let source = try makeTempFile(named: "not-a-video.mp4", contents: "definitely not a video")
        let result = await VideoImporter.duration(of: source)
        #expect(result == nil)
    }
}
