import Foundation
import XCTest
@testable import CodexVaultApp

final class BackupEngineTests: XCTestCase {
    func testCompleteBackupCreatesVerifiedZipAndKeepsConfigurationFiles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let source = root.appendingPathComponent("Codex", isDirectory: true)
        let generated = source.appendingPathComponent(".build", isDirectory: true)
        let destination = root.appendingPathComponent("destination", isDirectory: true)
        try FileManager.default.createDirectory(at: generated, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try Data("configuration".utf8).write(to: source.appendingPathComponent("auth.json"))
        try Data("generated".utf8).write(to: generated.appendingPathComponent("object.o"))

        let summary = try BackupEngine().createCompleteBackup(
            sources: [CompleteBackupSource(url: source, archiveBase: "ordnung_backup", kind: .ordnung)],
            destination: destination
        )
        let zipURL = try XCTUnwrap(summary.zipURLs.first)
        XCTAssertTrue(FileManager.default.fileExists(atPath: zipURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.appendingPathComponent("ordnung_backup_latest.zip").path))

        let extraction = root.appendingPathComponent("extraction", isDirectory: true)
        try FileManager.default.createDirectory(at: extraction, withIntermediateDirectories: true)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        task.arguments = ["-q", zipURL.path, "-d", extraction.path]
        try task.run()
        task.waitUntilExit()
        XCTAssertEqual(task.terminationStatus, 0)

        let extractedPaths = (FileManager.default.enumerator(at: extraction, includingPropertiesForKeys: nil)?.allObjects as? [URL] ?? [])
            .map(\.path)
        XCTAssertTrue(extractedPaths.contains { $0.hasSuffix("/Codex/auth.json") })
        XCTAssertFalse(extractedPaths.contains { $0.hasSuffix("/Codex/.build/object.o") })
    }

    func testBackupExcludesSensitiveFilesAndVerifiesCopiedContent() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let source = root.appendingPathComponent("source", isDirectory: true)
        let destination = root.appendingPathComponent("destination", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try Data("safe content".utf8).write(to: source.appendingPathComponent("notes.txt"))
        try Data("do not copy".utf8).write(to: source.appendingPathComponent(".env"))

        let engine = BackupEngine()
        let sourceDefinition = BackupSource(kind: .project, url: source)
        let preview = try engine.preview(source: sourceDefinition)
        XCTAssertEqual(preview.fileCount, 1)
        XCTAssertEqual(preview.sensitiveExclusionCount, 1)

        let summary = try engine.createBackup(sources: [sourceDefinition], destination: destination)
        XCTAssertTrue(summary.verified)
        XCTAssertTrue(try engine.verify(packageURL: summary.packageURL))

        let manifestURL = summary.packageURL.appendingPathComponent("manifest.json")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(ArchiveManifest.self, from: Data(contentsOf: manifestURL))
        XCTAssertEqual(manifest.entries.count, 1)
        XCTAssertEqual(manifest.sources?.first?.archiveRootName, "source")
        XCTAssertEqual(manifest.entries.first?.relativePath, "notes.txt")
        XCTAssertEqual(manifest.entries.first?.archiveRelativePath, "source/notes.txt")
        XCTAssertFalse(manifest.entries.contains { $0.relativePath.contains(source.path) })
        XCTAssertEqual(manifest.exclusionCounts["sensitive-files"], 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: summary.packageURL.appendingPathComponent("source/.env").path))

        let restoreDestination = root.appendingPathComponent("restore", isDirectory: true)
        try FileManager.default.createDirectory(at: restoreDestination, withIntermediateDirectories: true)
        let restore = try engine.restore(
            packageURL: summary.packageURL,
            sourceIDs: ["source-001"],
            destination: restoreDestination
        )
        XCTAssertTrue(restore.verified)
        XCTAssertEqual(restore.restoredFileCount, 1)
        let restoredFile = restore.destinationURL
            .appendingPathComponent("source", isDirectory: true)
            .appendingPathComponent("notes.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: restoredFile.path))
    }
}
