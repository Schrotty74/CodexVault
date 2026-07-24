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
    private let hasOwnContentKey = "codexVault.hasOwnContent"

    init() {
        let defaults = UserDefaults.standard
        let home = FileManager.default.homeDirectoryForCurrentUser
        let fallbackDestination = home.appendingPathComponent("Documents/CodexVault Backups", isDirectory: true)
        let savedRoots = defaults.stringArray(forKey: fullBackupProjectRootsKey) ?? []
        let hasSavedFullBackupSetup = defaults.object(forKey: fullBackupDestinationKey) != nil ||
            !savedRoots.isEmpty
        if let savedDestination = defaults.string(forKey: fullBackupDestinationKey) {
            completeBackupDestinationURL = URL(fileURLWithPath: savedDestination, isDirectory: true)
        } else {
            completeBackupDestinationURL = fallbackDestination
        }
        if !savedRoots.isEmpty {
            fullBackupProjectRoots = savedRoots.map { URL(fileURLWithPath: $0, isDirectory: true) }
        } else {
            fullBackupProjectRoots = []
        }
        if hasSavedFullBackupSetup {
            defaults.set(true, forKey: hasOwnContentKey)
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

    var hasOwnContent: Bool {
        UserDefaults.standard.bool(forKey: hasOwnContentKey) || !sources.isEmpty || !archives.isEmpty
    }

    func chooseSource(kind: BackupSourceKind) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = CodexVaultLocalization.text("Add")
        panel.message = kind == .project
            ? CodexVaultLocalization.text("Choose the project folders you want to include.")
            : CodexVaultLocalization.text("Choose the additional folders you want to include.")

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
        panel.prompt = CodexVaultLocalization.text("Use destination")
        panel.message = CodexVaultLocalization.text("Choose the folder where CodexVault should create the backup.")

        guard panel.runModal() == .OK, let url = panel.url else { return }
        destinationURL = url
        statusMessage = CodexVaultLocalization.text("Backup destination selected.")
    }

    func createCompleteBackup() {
        isWorking = true
        errorMessage = nil
        completeBackupProgress = 0
        completeBackupProgressMessage = CodexVaultLocalization.text("Starting complete backup…")
        statusMessage = CodexVaultLocalization.text("Backing up Codex and configured project folders…")
        let projectRoots = fullBackupProjectRoots + automaticFullBackupProjectRoots.filter { automaticRoot in
            !fullBackupProjectRoots.contains { $0.standardizedFileURL == automaticRoot.standardizedFileURL }
        }
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
                let skipped = result.0.skippedSourceNames.isEmpty ? "" : " \(CodexVaultLocalization.text("Missing:")) \(result.0.skippedSourceNames.joined(separator: ", "))."
                statusMessage = "\(result.0.zipURLs.count) ZIP \(CodexVaultLocalization.text("backups verified:")) \(result.0.fileCount) \(CodexVaultLocalization.text("files")) · \(size).\(skipped)"
                pendingCompleteBackupCleanup = result.1
                markOwnContent()
            } catch {
                errorMessage = error.localizedDescription
                statusMessage = nil
            }
            completeBackupProgressMessage = nil
            isWorking = false
        }
    }

    func addFullBackupProjectRoots() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = CodexVaultLocalization.text("Add project folders")
        panel.message = CodexVaultLocalization.text("Choose one or more project folders that CodexVault should include in every full backup. This choice is stored locally for this user.")
        guard panel.runModal() == .OK else { return }
        for url in panel.urls where !fullBackupProjectRoots.contains(where: {
            $0.standardizedFileURL == url.standardizedFileURL
        }) {
            fullBackupProjectRoots.append(url)
        }
        persistFullBackupSetup()
        markOwnContent()
    }

    func removeFullBackupProjectRoot(_ root: URL) {
        fullBackupProjectRoots.removeAll { $0.standardizedFileURL == root.standardizedFileURL }
        persistFullBackupSetup()
    }

    func chooseFullBackupDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = CodexVaultLocalization.text("Use destination")
        panel.message = CodexVaultLocalization.text("Choose where CodexVault should store full backups for this user.")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        completeBackupDestinationURL = url
        persistFullBackupSetup()
        markOwnContent()
    }

    private func persistFullBackupSetup() {
        UserDefaults.standard.set(completeBackupDestinationURL.path, forKey: fullBackupDestinationKey)
        UserDefaults.standard.set(fullBackupProjectRoots.map(\.path), forKey: fullBackupProjectRootsKey)
    }

    private func markOwnContent() {
        UserDefaults.standard.set(true, forKey: hasOwnContentKey)
    }

    private var automaticFullBackupProjectRoots: [URL] {
        let visibleCodexFolder = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/Codex", isDirectory: true)
        return FileManager.default.fileExists(atPath: visibleCodexFolder.path) ? [visibleCodexFolder] : []
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
                statusMessage = CodexVaultLocalization.text("Older complete backups were removed.")
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
                statusMessage = CodexVaultLocalization.text("Selected unassigned local records were removed.")
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
        panel.prompt = CodexVaultLocalization.text("Open backup")
        panel.message = CodexVaultLocalization.text("Choose a CodexVault backup package to validate.")

        guard panel.runModal() == .OK, let url = panel.url else { return }
        isWorking = true
        errorMessage = nil
        restoreStatusMessage = CodexVaultLocalization.text("Validating backup…")

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
                restoreStatusMessage = CodexVaultLocalization.text("Backup verified. Choose what to restore.")
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
        panel.prompt = CodexVaultLocalization.text("Use destination")
        panel.message = CodexVaultLocalization.text("Choose where CodexVault should create a new restore folder.")

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
            errorMessage = CodexVaultLocalization.text("Choose a verified backup and a restore destination.")
            return
        }

        let sourceIDs = selectedRestoreSourceIDs
        isWorking = true
        errorMessage = nil
        restoreStatusMessage = CodexVaultLocalization.text("Restoring and verifying files…")

        Task {
            do {
                let summary = try await Task.detached(priority: .userInitiated) {
                    try BackupEngine().restore(
                        packageURL: restorePackageURL,
                        sourceIDs: sourceIDs,
                        destination: restoreDestinationURL
                    )
                }.value
                restoreStatusMessage = "\(CodexVaultLocalization.text("Restored")) \(summary.restoredFileCount) \(CodexVaultLocalization.text("files into a new verified folder."))"
            } catch {
                errorMessage = error.localizedDescription
                restoreStatusMessage = nil
            }
            isWorking = false
        }
    }

    func createBackup() {
        guard !sources.isEmpty else {
            errorMessage = CodexVaultLocalization.text("Choose at least one project or folder.")
            return
        }
        guard let destinationURL else {
            errorMessage = CodexVaultLocalization.text("Choose where the backup package should be stored.")
            return
        }

        let selectedSources = sources
        isWorking = true
        errorMessage = nil
        statusMessage = CodexVaultLocalization.text("Creating and verifying the backup…")

        Task {
            do {
                let summary = try await Task.detached(priority: .userInitiated) {
                    try BackupEngine().createBackup(sources: selectedSources, destination: destinationURL)
                }.value
                archives.insert(summary, at: 0)
                statusMessage = CodexVaultLocalization.text("Backup verified successfully.")
                markOwnContent()
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
        statusMessage = CodexVaultLocalization.text("Analyzing selected sources…")

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
            statusMessage = CodexVaultLocalization.text("Selection preview ready.")
        }
    }
}
