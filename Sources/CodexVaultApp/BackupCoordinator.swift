import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

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
    var restorePassword = ""
    var restoreRequiresPassword = false
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
    var isFullBackupStartConfirmationPresented = false
    var encryptNormalBackup = false
    var normalBackupPassword = ""
    var automaticFullBackupEnabled = false
    var automaticFullBackupInterval: FullBackupScheduleInterval = .weekly
    var lastAutomaticFullBackupDate: Date?

    var completeBackupDestinationURL: URL
    var fullBackupProjectRoots: [URL]
    var discoveredProjectCandidates: [ProjectCandidate] = []
    var selectedDiscoveredProjectURLs: Set<URL> = []
    var isDiscoveringProjects = false

    private let fullBackupDestinationKey = "codexVault.fullBackup.destination"
    private let fullBackupProjectRootsKey = "codexVault.fullBackup.projectRoots"
    private let hasOwnContentKey = "codexVault.hasOwnContent"
    private let archivesKey = "codexVault.archiveHistory"
    private let automaticFullBackupEnabledKey = "codexVault.fullBackup.automatic.enabled"
    private let automaticFullBackupIntervalKey = "codexVault.fullBackup.automatic.interval"
    private let automaticFullBackupDateKey = "codexVault.fullBackup.automatic.lastRun"
    private let defaults: UserDefaults
    @ObservationIgnored private var automaticBackupTimer: Timer?

    init() {
        let defaults = UserDefaults.standard
        self.defaults = defaults
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
        let savedArchives = ArchiveHistory.decode(defaults.data(forKey: archivesKey))
        archives = savedArchives
        if let encodedArchives = ArchiveHistory.encode(savedArchives) {
            defaults.set(encodedArchives, forKey: archivesKey)
        }
        if hasSavedFullBackupSetup {
            defaults.set(true, forKey: hasOwnContentKey)
        }
        automaticFullBackupEnabled = defaults.bool(forKey: automaticFullBackupEnabledKey)
        automaticFullBackupInterval = FullBackupScheduleInterval(rawValue: defaults.string(forKey: automaticFullBackupIntervalKey) ?? "") ?? .weekly
        lastAutomaticFullBackupDate = defaults.object(forKey: automaticFullBackupDateKey) as? Date
        scheduleAutomaticBackupCheck()
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

    func chooseChatGPTExport() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json, .zip]
        panel.prompt = CodexVaultLocalization.text("Import ChatGPT export")
        panel.message = CodexVaultLocalization.text("Choose the conversations.json file or ZIP from a ChatGPT data export. It stays local and is included only in a backup you create.")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if EncryptedArchive.isEncrypted(packageURL: url) {
            restorePackageURL = url
            restoreManifest = nil
            restoreRequiresPassword = true
            restoreStatusMessage = CodexVaultLocalization.text("Enter the backup password to validate encrypted contents.")
            return
        }
        guard !sources.contains(where: { $0.url.standardizedFileURL == url.standardizedFileURL }) else { return }
        sources.append(BackupSource(kind: .chatGPTExport, url: url))
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

    func requestCompleteBackup() {
        guard !isWorking else { return }
        isFullBackupStartConfirmationPresented = true
    }

    func saveAutomaticBackupSettings() {
        defaults.set(automaticFullBackupEnabled, forKey: automaticFullBackupEnabledKey)
        defaults.set(automaticFullBackupInterval.rawValue, forKey: automaticFullBackupIntervalKey)
        scheduleAutomaticBackupCheck()
    }

    func createCompleteBackup(isAutomatic: Bool = false) {
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
                if isAutomatic {
                    lastAutomaticFullBackupDate = Date()
                    defaults.set(lastAutomaticFullBackupDate, forKey: automaticFullBackupDateKey)
                }
            } catch {
                errorMessage = error.localizedDescription
                statusMessage = nil
            }
            completeBackupProgressMessage = nil
            isWorking = false
        }
    }

    private func scheduleAutomaticBackupCheck() {
        automaticBackupTimer?.invalidate()
        automaticBackupTimer = nil
        guard automaticFullBackupEnabled else { return }
        automaticBackupTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.runAutomaticBackupIfDue() }
        }
        runAutomaticBackupIfDue()
    }

    private func runAutomaticBackupIfDue() {
        guard automaticFullBackupEnabled, !isWorking else { return }
        if let lastAutomaticFullBackupDate,
           Date().timeIntervalSince(lastAutomaticFullBackupDate) < automaticFullBackupInterval.seconds {
            return
        }
        guard !codexDesktopAppIsRunning else {
            statusMessage = CodexVaultLocalization.text("Automatic full backup is waiting for Codex to close.")
            return
        }
        createCompleteBackup(isAutomatic: true)
    }

    private var codexDesktopAppIsRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { application in
            application.bundleIdentifier?.localizedCaseInsensitiveContains("codex") == true ||
                application.localizedName?.localizedCaseInsensitiveCompare("Codex") == .orderedSame
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

    func chooseProjectDiscoveryScope() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = CodexVaultLocalization.text("Search projects")
        panel.message = CodexVaultLocalization.text("Choose a folder to search locally for project markers. Nothing is added until you select candidates and confirm.")
        guard panel.runModal() == .OK, let scope = panel.url else { return }
        isDiscoveringProjects = true
        discoveredProjectCandidates = []
        selectedDiscoveredProjectURLs = []
        Task {
            defer { isDiscoveringProjects = false }
            do {
                let candidates = try await Task.detached(priority: .userInitiated) {
                    try ProjectDiscovery.candidates(in: scope)
                }.value
                discoveredProjectCandidates = candidates.filter { candidate in
                    !fullBackupProjectRoots.contains { $0.standardizedFileURL == candidate.url.standardizedFileURL }
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func addSelectedDiscoveredProjects() {
        for candidate in discoveredProjectCandidates where selectedDiscoveredProjectURLs.contains(candidate.url) {
            guard !fullBackupProjectRoots.contains(where: { $0.standardizedFileURL == candidate.url.standardizedFileURL }) else { continue }
            fullBackupProjectRoots.append(candidate.url)
        }
        discoveredProjectCandidates = []
        selectedDiscoveredProjectURLs = []
        persistFullBackupSetup()
        markOwnContent()
    }

    func toggleDiscoveredProject(_ candidate: ProjectCandidate) {
        if selectedDiscoveredProjectURLs.contains(candidate.url) {
            selectedDiscoveredProjectURLs.remove(candidate.url)
        } else {
            selectedDiscoveredProjectURLs.insert(candidate.url)
        }
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

    private func persistArchives() {
        guard let data = ArchiveHistory.encode(archives) else { return }
        defaults.set(data, forKey: archivesKey)
    }

    private func addArchiveToHistory(_ summary: ArchiveSummary) {
        archives.removeAll { $0.packageURL.standardizedFileURL == summary.packageURL.standardizedFileURL }
        archives.insert(summary, at: 0)
        persistArchives()
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
                restoreRequiresPassword = false
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

    func validateEncryptedRestore() {
        guard let restorePackageURL, !restorePassword.isEmpty else { return }
        isWorking = true
        let password = restorePassword
        Task {
            do {
                let manifest = try await Task.detached(priority: .userInitiated) {
                    let unpacked = try EncryptedArchive.decryptedPackage(from: restorePackageURL, password: password)
                    let engine = BackupEngine()
                    guard try engine.verify(packageURL: unpacked) else { throw BackupError.invalidBackup }
                    return try engine.manifest(in: unpacked)
                }.value
                restoreManifest = manifest
                selectedRestoreSourceIDs = Set(manifest.entries.map(\.sourceID))
                restoreStatusMessage = CodexVaultLocalization.text("Encrypted backup verified. Choose what to restore.")
            } catch {
                errorMessage = CodexVaultLocalization.text("The password is incorrect or this encrypted package is invalid.")
            }
            isWorking = false
        }
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
        let password = restorePassword
        isWorking = true
        errorMessage = nil
        restoreStatusMessage = CodexVaultLocalization.text("Restoring and verifying files…")

        Task {
            do {
                let summary = try await Task.detached(priority: .userInitiated) {
                    let sourcePackage: URL
                    if EncryptedArchive.isEncrypted(packageURL: restorePackageURL) {
                        sourcePackage = try EncryptedArchive.decryptedPackage(from: restorePackageURL, password: password)
                    } else {
                        sourcePackage = restorePackageURL
                    }
                    return try BackupEngine().restore(
                        packageURL: sourcePackage,
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
        let password = encryptNormalBackup ? normalBackupPassword : nil
        isWorking = true
        errorMessage = nil
        statusMessage = CodexVaultLocalization.text("Creating and verifying the backup…")

        Task {
            do {
                let summary = try await Task.detached(priority: .userInitiated) {
                    try BackupEngine().createBackup(
                        sources: selectedSources,
                        destination: destinationURL,
                        password: password
                    )
                }.value
                addArchiveToHistory(summary)
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
