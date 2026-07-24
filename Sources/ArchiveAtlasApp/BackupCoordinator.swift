import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class BackupCoordinator {
    var sources: [BackupSource] = []
    var destinationURL: URL?
    var archives: [ArchiveSummary] = []
    var restorePackageURL: URL?
    var restoreManifest: ArchiveManifest?
    var selectedRestoreSourceIDs: Set<String> = []
    var restoreDestinationURL: URL?
    var restoreStatusMessage: String?
    var isWorking = false
    var statusMessage: String?
    var errorMessage: String?
    var pendingCompleteBackupCleanup: [URL] = []
    var completeBackupProgress: Double = 0
    var completeBackupProgressMessage: String?
    var sessionPreview: SessionCleanupPreview?
    var isAnalyzingSessions = false
    var isSessionPreviewExpanded = false
    var selectedUnassignedRecordIDs: Set<String> = []
    var isUnassignedDeletionConfirmationPresented = false

    var completeBackupDestinationURL: URL
    var fullBackupProjectRoots: [URL]

    private let fullBackupDestinationKey = "codexVault.fullBackup.destination"
    private let fullBackupProjectRootsKey = "codexVault.fullBackup.projectRoots"

    init() {
        let defaults = UserDefaults.standard
        let home = FileManager.default.homeDirectoryForCurrentUser
        let fallbackDestination = home.appendingPathComponent("Documents/CodexVault Backups", isDirectory: true)
        if let savedDestination = defaults.string(forKey: fullBackupDestinationKey) {
            completeBackupDestinationURL = URL(fileURLWithPath: savedDestination, isDirectory: true)
        } else {
            completeBackupDestinationURL = fallbackDestination
        }
        if let savedRoots = defaults.stringArray(forKey: fullBackupProjectRootsKey) {
            fullBackupProjectRoots = savedRoots.map { URL(fileURLWithPath: $0, isDirectory: true) }
        } else {
            fullBackupProjectRoots = Self.detectedProjectRoots(home: home)
        }
        let visibleCodexFolder = home.appendingPathComponent("Documents/Codex", isDirectory: true)
        if FileManager.default.fileExists(atPath: visibleCodexFolder.path),
           !fullBackupProjectRoots.contains(where: { $0.standardizedFileURL == visibleCodexFolder.standardizedFileURL }) {
            fullBackupProjectRoots.append(visibleCodexFolder)
            defaults.set(fullBackupProjectRoots.map(\.path), forKey: fullBackupProjectRootsKey)
        }
    }

    var totalFileCount: Int {
        sources.compactMap(\.preview?.fileCount).reduce(0, +)
    }

    var totalBytes: UInt64 {
        sources.compactMap(\.preview?.estimatedBytes).reduce(0, +)
    }

    var sensitiveExclusionCount: Int {
        sources.compactMap(\.preview?.sensitiveExclusionCount).reduce(0, +)
    }

    func chooseSource(kind: BackupSourceKind) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        panel.message = kind == .project
            ? "Choose the project folders you want to include."
            : "Choose the additional folders you want to include."

        guard panel.runModal() == .OK else { return }
        for url in panel.urls where !sources.contains(where: { $0.url.standardizedFileURL == url.standardizedFileURL }) {
            sources.append(BackupSource(kind: kind, url: url))
        }
        refreshPreviews()
    }

    func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Use destination"
        panel.message = "Choose the folder where CodexVault should create the backup."

        guard panel.runModal() == .OK, let url = panel.url else { return }
        destinationURL = url
        statusMessage = "Backup destination selected."
    }

    func createCompleteBackup() {
        isWorking = true
        errorMessage = nil
        completeBackupProgress = 0
        completeBackupProgressMessage = "Starting complete backup…"
        statusMessage = "Backing up Codex and configured project folders…"
        let projectRoots = fullBackupProjectRoots
        let destination = completeBackupDestinationURL

        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    let engine = BackupEngine()
                    let summary = try engine.createStandardCompleteBackup(projectRoots: projectRoots, destination: destination) { [weak self] update in
                        Task { @MainActor in
                            self?.completeBackupProgress = update.fractionCompleted
                            self?.completeBackupProgressMessage = update.message
                        }
                    }
                    let obsolete = try engine.datedCompleteBackups(in: destination, keeping: 3)
                    return (summary, obsolete)
                }.value
                let size = ByteCountFormatter.string(fromByteCount: Int64(result.0.byteCount), countStyle: .file)
                let skipped = result.0.skippedSourceNames.isEmpty ? "" : " Missing: \(result.0.skippedSourceNames.joined(separator: ", "))."
                statusMessage = "\(result.0.zipURLs.count) ZIP backups verified: \(result.0.fileCount) files · \(size).\(skipped)"
                pendingCompleteBackupCleanup = result.1
            } catch {
                errorMessage = error.localizedDescription
                statusMessage = nil
            }
            completeBackupProgressMessage = nil
            isWorking = false
        }
    }

    func chooseFullBackupProjectRoots() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Use project folders"
        panel.message = "Choose the project folders that CodexVault should include in every full backup. This choice is stored locally for this user."
        guard panel.runModal() == .OK else { return }
        fullBackupProjectRoots = panel.urls
        persistFullBackupSetup()
    }

    func chooseFullBackupDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Use destination"
        panel.message = "Choose where CodexVault should store full backups for this user."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        completeBackupDestinationURL = url
        persistFullBackupSetup()
    }

    private func persistFullBackupSetup() {
        UserDefaults.standard.set(completeBackupDestinationURL.path, forKey: fullBackupDestinationKey)
        UserDefaults.standard.set(fullBackupProjectRoots.map(\.path), forKey: fullBackupProjectRootsKey)
    }

    private static func detectedProjectRoots(home: URL) -> [URL] {
        let fileManager = FileManager.default
        let documents = home.appendingPathComponent("Documents", isDirectory: true)
        guard let children = try? fileManager.contentsOfDirectory(
            at: documents,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return children.filter { candidate in
            guard (try? candidate.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { return false }
            if fileManager.fileExists(atPath: candidate.appendingPathComponent("Package.swift").path) ||
                fileManager.fileExists(atPath: candidate.appendingPathComponent("package.json").path) ||
                fileManager.fileExists(atPath: candidate.appendingPathComponent(".git").path) {
                return true
            }
            return (try? fileManager.contentsOfDirectory(at: candidate, includingPropertiesForKeys: nil))?.contains {
                $0.pathExtension == "xcodeproj"
            } == true
        }
    }

    func removeOldCompleteBackups() {
        let urls = pendingCompleteBackupCleanup
        guard !urls.isEmpty else { return }
        isWorking = true
        errorMessage = nil
        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    try BackupEngine().removeCompleteBackups(urls)
                }.value
                pendingCompleteBackupCleanup = []
                statusMessage = "Older complete backups were removed."
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    func createSessionPreview() {
        isAnalyzingSessions = true
        errorMessage = nil
        Task {
            do {
                sessionPreview = try await Task.detached(priority: .userInitiated) {
                    try BackupEngine().sessionCleanupPreview()
                }.value
                isSessionPreviewExpanded = true
                selectedUnassignedRecordIDs = []
            } catch {
                errorMessage = error.localizedDescription
            }
            isAnalyzingSessions = false
        }
    }

    func toggleSessionPreview() {
        if sessionPreview == nil {
            createSessionPreview()
        } else {
            isSessionPreviewExpanded.toggle()
        }
    }

    func toggleUnassignedRecord(_ record: UnassignedSessionRecord) {
        if selectedUnassignedRecordIDs.contains(record.id) {
            selectedUnassignedRecordIDs.remove(record.id)
        } else {
            selectedUnassignedRecordIDs.insert(record.id)
        }
    }

    func removeSelectedUnassignedRecords() {
        guard let preview = sessionPreview else { return }
        let records = preview.unassignedRecords.filter { selectedUnassignedRecordIDs.contains($0.id) }
        guard !records.isEmpty else { return }
        isWorking = true
        errorMessage = nil
        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    try BackupEngine().removeUnassignedSessionRecords(records)
                }.value
                selectedUnassignedRecordIDs = []
                sessionPreview = try await Task.detached(priority: .userInitiated) {
                    try BackupEngine().sessionCleanupPreview()
                }.value
                statusMessage = "Selected unassigned local records were removed."
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    func removeSource(_ source: BackupSource) {
        sources.removeAll { $0.id == source.id }
        statusMessage = nil
    }

    func chooseRestorePackage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Open backup"
        panel.message = "Choose a CodexVault backup package to validate."

        guard panel.runModal() == .OK, let url = panel.url else { return }
        isWorking = true
        errorMessage = nil
        restoreStatusMessage = "Validating backup…"

        Task {
            do {
                let manifest = try await Task.detached(priority: .userInitiated) {
                    let engine = BackupEngine()
                    guard try engine.verify(packageURL: url) else { throw BackupError.invalidBackup }
                    return try engine.manifest(in: url)
                }.value
                restorePackageURL = url
                restoreManifest = manifest
                selectedRestoreSourceIDs = Set(manifest.entries.map(\.sourceID))
                restoreStatusMessage = "Backup verified. Choose what to restore."
            } catch {
                restorePackageURL = nil
                restoreManifest = nil
                selectedRestoreSourceIDs = []
                restoreStatusMessage = nil
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    func chooseRestoreDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Use destination"
        panel.message = "Choose where CodexVault should create a new restore folder."

        guard panel.runModal() == .OK, let url = panel.url else { return }
        restoreDestinationURL = url
    }

    func toggleRestoreSource(_ sourceID: String) {
        if selectedRestoreSourceIDs.contains(sourceID) {
            selectedRestoreSourceIDs.remove(sourceID)
        } else {
            selectedRestoreSourceIDs.insert(sourceID)
        }
    }

    func restoreSelected() {
        guard let restorePackageURL, let restoreDestinationURL else {
            errorMessage = "Choose a verified backup and a restore destination."
            return
        }

        let sourceIDs = selectedRestoreSourceIDs
        isWorking = true
        errorMessage = nil
        restoreStatusMessage = "Restoring and verifying files…"

        Task {
            do {
                let summary = try await Task.detached(priority: .userInitiated) {
                    try BackupEngine().restore(
                        packageURL: restorePackageURL,
                        sourceIDs: sourceIDs,
                        destination: restoreDestinationURL
                    )
                }.value
                restoreStatusMessage = "Restored \(summary.restoredFileCount) files into a new verified folder."
            } catch {
                errorMessage = error.localizedDescription
                restoreStatusMessage = nil
            }
            isWorking = false
        }
    }

    func createBackup() {
        guard !sources.isEmpty else {
            errorMessage = "Choose at least one project or folder."
            return
        }
        guard let destinationURL else {
            errorMessage = "Choose where the backup package should be stored."
            return
        }

        let selectedSources = sources
        isWorking = true
        errorMessage = nil
        statusMessage = "Creating and verifying the backup…"

        Task {
            do {
                let summary = try await Task.detached(priority: .userInitiated) {
                    try BackupEngine().createBackup(sources: selectedSources, destination: destinationURL)
                }.value
                archives.insert(summary, at: 0)
                statusMessage = "Backup verified successfully."
            } catch {
                errorMessage = error.localizedDescription
                statusMessage = nil
            }
            isWorking = false
        }
    }

    private func refreshPreviews() {
        let snapshot = sources
        isWorking = true
        statusMessage = "Analyzing selected sources…"

        Task {
            let previews = await Task.detached(priority: .userInitiated) {
                snapshot.map { source in
                    (source.id, try? BackupEngine().preview(source: source))
                }
            }.value
            for (id, preview) in previews {
                guard let index = sources.firstIndex(where: { $0.id == id }) else { continue }
                sources[index].preview = preview
            }
            isWorking = false
            statusMessage = "Selection preview ready."
        }
    }
}
