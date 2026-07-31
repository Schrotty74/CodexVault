import Foundation
import XCTest
@testable import CodexVaultApp

final class BackupEngineTests: XCTestCase {
    func testSelectedAppLanguageControlsManualPromptAndLocalizedText() {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: CodexVaultLanguage.storageKey)
        defer {
            if let previous {
                defaults.set(previous, forKey: CodexVaultLanguage.storageKey)
            } else {
                defaults.removeObject(forKey: CodexVaultLanguage.storageKey)
            }
        }

        defaults.set(CodexVaultLanguage.english.rawValue, forKey: CodexVaultLanguage.storageKey)
        XCTAssertEqual(CodexVaultLanguage.current, .english)
        XCTAssertTrue(CodexVaultHelpLinks.manualURL(for: .english).absoluteString.hasSuffix("CodexVault-Manual-EN.pdf"))

        defaults.set(CodexVaultLanguage.german.rawValue, forKey: CodexVaultLanguage.storageKey)
        XCTAssertEqual(CodexVaultLanguage.current, .german)
        XCTAssertEqual(CodexVaultLocalization.text("Settings"), "Einstellungen")
        XCTAssertTrue(CodexVaultHelpLinks.aiPrompt(for: .german).contains("Ich habe CodexVault"))
    }

    func testAIHelpUsesOnlyTheThreeExpectedServiceURLs() {
        let expectedHosts = ["chatgpt.com", "gemini.google.com", "claude.ai"]
        XCTAssertEqual(CodexVaultAIHelpService.allCases.compactMap(\.url.host), expectedHosts)
        XCTAssertEqual(CodexVaultAIHelpService.allCases.compactMap(\.url.scheme), ["https", "https", "https"])
    }

    func testAIHelpPromptIsGeneralAndDoesNotContainLocalOrSensitiveData() {
        for language in CodexVaultLanguage.allCases {
            let prompt = CodexVaultHelpLinks.aiPrompt(for: language)
            XCTAssertTrue(prompt.contains(CodexVaultHelpLinks.manualURL(for: language).absoluteString))
            XCTAssertTrue(prompt.contains("CodexVault"))
            XCTAssertTrue(prompt.localizedCaseInsensitiveContains("do not invent") || prompt.localizedCaseInsensitiveContains("erfinde keine"))
            XCTAssertTrue(prompt.localizedCaseInsensitiveContains(language == .german ? "lokale macOS" : "local macOS"))
            for prohibitedFragment in ["/Users/", "~/.codex", "token", "password", "credential", "license"] {
                XCTAssertFalse(prompt.localizedCaseInsensitiveContains(prohibitedFragment))
            }
        }
    }

    func testAIHelpUsesTheManualForTheSelectedLanguage() {
        XCTAssertTrue(CodexVaultHelpLinks.manualURL(for: .german).absoluteString.hasSuffix("CodexVault-Handbuch-DE.pdf"))
        XCTAssertTrue(CodexVaultHelpLinks.manualURL(for: .english).absoluteString.hasSuffix("CodexVault-Manual-EN.pdf"))
    }

    func testCompleteBackupCreatesOneVerifiedArchiveForEachProjectFolder() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let firstProject = root.appendingPathComponent("FirstProject", isDirectory: true)
        let secondProject = root.appendingPathComponent("SecondProject", isDirectory: true)
        let destination = root.appendingPathComponent("destination", isDirectory: true)
        try FileManager.default.createDirectory(at: firstProject, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: secondProject, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try Data("first".utf8).write(to: firstProject.appendingPathComponent("first.txt"))
        try Data("second".utf8).write(to: secondProject.appendingPathComponent("second.txt"))

        let summary = try BackupEngine().createCompleteBackup(
            sources: [
                CompleteBackupSource(url: firstProject, archiveBase: "first_project_backup", kind: .ordnung),
                CompleteBackupSource(url: secondProject, archiveBase: "second_project_backup", kind: .ordnung),
            ],
            destination: destination
        )

        XCTAssertEqual(summary.zipURLs.count, 2)
        XCTAssertEqual(summary.fileCount, 2)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.appendingPathComponent("first_project_backup_latest.zip").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.appendingPathComponent("second_project_backup_latest.zip").path))
    }

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

    func testArchiveHistoryRetainsOnlyExistingPackages() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let existingPackage = root.appendingPathComponent("kept.codexvault", isDirectory: true)
        let missingPackage = root.appendingPathComponent("missing.codexvault", isDirectory: true)
        try FileManager.default.createDirectory(at: existingPackage, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let retained = ArchiveSummary(
            id: UUID(),
            packageURL: existingPackage,
            createdAt: .now,
            fileCount: 2,
            byteCount: 42,
            verified: true
        )
        let removed = ArchiveSummary(
            id: UUID(),
            packageURL: missingPackage,
            createdAt: .distantPast,
            fileCount: 1,
            byteCount: 1,
            verified: true
        )

        let encoded = try XCTUnwrap(ArchiveHistory.encode([removed, retained]))
        XCTAssertEqual(ArchiveHistory.decode(encoded), [retained])
    }

    func testProjectDiscoveryFindsOnlyProjectMarkersAndSkipsBuildFolders() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let swiftProject = root.appendingPathComponent("SwiftProject", isDirectory: true)
        let nodeProject = root.appendingPathComponent("NodeProject", isDirectory: true)
        let generated = root.appendingPathComponent("node_modules/ignored", isDirectory: true)
        try FileManager.default.createDirectory(at: swiftProject, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nodeProject, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: generated, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("// Swift".utf8).write(to: swiftProject.appendingPathComponent("Package.swift"))
        try Data("{}".utf8).write(to: nodeProject.appendingPathComponent("package.json"))
        try Data("{}".utf8).write(to: generated.appendingPathComponent("package.json"))

        let candidates = try ProjectDiscovery.candidates(in: root)
        XCTAssertEqual(Set(candidates.map(\.displayName)), ["SwiftProject", "NodeProject"])
        XCTAssertTrue(candidates.first { $0.displayName == "SwiftProject" }?.signals.contains("Swift package") == true)
        XCTAssertTrue(candidates.first { $0.displayName == "NodeProject" }?.signals.contains("Node project") == true)
    }

    func testChatGPTExportFileCanBeIncludedAndVerifiedInNormalBackup() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let destination = root.appendingPathComponent("destination", isDirectory: true)
        let export = root.appendingPathComponent("conversations.json")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("[]".utf8).write(to: export)

        let source = BackupSource(kind: .chatGPTExport, url: export)
        let preview = try BackupEngine().preview(source: source)
        XCTAssertEqual(preview.fileCount, 1)
        let backup = try BackupEngine().createBackup(sources: [source], destination: destination)
        XCTAssertTrue(try BackupEngine().verify(packageURL: backup.packageURL))
        XCTAssertTrue(FileManager.default.fileExists(atPath: backup.packageURL.appendingPathComponent("conversations.json/conversations.json").path))
    }

    func testEncryptedBackupCanBeDecryptedVerifiedAndRestored() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let source = root.appendingPathComponent("source", isDirectory: true)
        let destination = root.appendingPathComponent("destination", isDirectory: true)
        let restoreDestination = root.appendingPathComponent("restore", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: restoreDestination, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("protected".utf8).write(to: source.appendingPathComponent("notes.txt"))

        let engine = BackupEngine()
        let backup = try engine.createBackup(sources: [BackupSource(kind: .project, url: source)], destination: destination, password: "test-password")
        XCTAssertTrue(EncryptedArchive.isEncrypted(packageURL: backup.packageURL))
        let decrypted = try EncryptedArchive.decryptedPackage(from: backup.packageURL, password: "test-password")
        XCTAssertTrue(try engine.verify(packageURL: decrypted))
        let restored = try engine.restore(packageURL: decrypted, sourceIDs: ["source-001"], destination: restoreDestination)
        XCTAssertTrue(FileManager.default.fileExists(atPath: restored.destinationURL.appendingPathComponent("source/notes.txt").path))
        XCTAssertThrowsError(try EncryptedArchive.decryptedPackage(from: backup.packageURL, password: "wrong-password"))
    }
}
