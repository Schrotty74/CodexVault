import CryptoKit
import Foundation

struct BackupEngine {
    private let fileManager = FileManager.default

    func preview(source: BackupSource) throws -> SourcePreview {
        let rootValues = try source.url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        if rootValues.isRegularFile == true {
            return SourcePreview(
                fileCount: 1,
                estimatedBytes: UInt64(rootValues.fileSize ?? 0),
                sensitiveExclusionCount: 0,
                standardExclusionCount: 0
            )
        }
        var fileCount = 0
        var byteCount: UInt64 = 0
        var sensitiveExclusionCount = 0
        var standardExclusionCount = 0

        try enumerate(source.url) { url, values, relativePath in
            if exclusionKind(for: url.lastPathComponent) == .sensitive {
                sensitiveExclusionCount += 1
                return
            }
            if exclusionKind(for: url.lastPathComponent) == .standard {
                standardExclusionCount += 1
                return
            }
            guard values.isRegularFile == true else { return }
            fileCount += 1
            byteCount += UInt64(values.fileSize ?? 0)
        }

        return SourcePreview(
            fileCount: fileCount,
            estimatedBytes: byteCount,
            sensitiveExclusionCount: sensitiveExclusionCount,
            standardExclusionCount: standardExclusionCount
        )
    }

    func createBackup(
        sources: [BackupSource],
        destination: URL,
        password: String? = nil,
        archiveBaseName: String? = nil
    ) throws -> ArchiveSummary {
        guard !sources.isEmpty else { throw BackupError.noSources }
        guard destination.hasDirectoryPath else { throw BackupError.destinationUnavailable }

        let createdAt = Date()
        let packageName = "\(normalBackupBaseName(for: sources, customName: archiveBaseName))-\(Self.packageTimestamp.string(from: createdAt)).codexvault"
        let archiveURL = destination.appendingPathComponent("\(packageName).zip", isDirectory: false)
        let stagingRoot = fileManager.temporaryDirectory
            .appendingPathComponent("CodexVault-Backup-\(UUID().uuidString)", isDirectory: true)
        let packageURL = stagingRoot.appendingPathComponent(packageName, isDirectory: true)
        defer { try? fileManager.removeItem(at: stagingRoot) }
        try fileManager.createDirectory(at: packageURL, withIntermediateDirectories: true)

        var entries: [ArchiveEntry] = []
        var directories: [ArchiveDirectory] = []
        var archiveSources: [ArchiveSource] = []
        var exclusionCounts: [String: Int] = [:]
        var errorCount = 0
        var reservedRootNames: Set<String> = []

        for (index, source) in sources.enumerated() {
            let sourceID = String(format: "source-%03d", index + 1)
            let archiveRootName = uniqueArchiveRootName(for: source, reservedNames: &reservedRootNames)
            let targetRoot = packageURL.appendingPathComponent(archiveRootName, isDirectory: true)
            try fileManager.createDirectory(at: targetRoot, withIntermediateDirectories: true)
            directories.append(ArchiveDirectory(sourceID: sourceID, relativePath: ""))
            archiveSources.append(ArchiveSource(sourceID: sourceID, archiveRootName: archiveRootName))

            let sourceValues = try source.url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            if sourceValues.isRegularFile == true {
                let targetURL = targetRoot.appendingPathComponent(source.url.lastPathComponent)
                try fileManager.copyItem(at: source.url, to: targetURL)
                let digest = try sha256(of: targetURL)
                entries.append(ArchiveEntry(
                    sourceID: sourceID,
                    relativePath: source.url.lastPathComponent,
                    archiveRelativePath: "\(archiveRootName)/\(source.url.lastPathComponent)",
                    byteCount: UInt64(sourceValues.fileSize ?? 0),
                    sha256: digest
                ))
                continue
            }

            try enumerate(source.url) { url, values, relativePath in
                let exclusion = exclusionKind(for: url.lastPathComponent)
                if exclusion != .none {
                    exclusionCounts[exclusion.reportKey, default: 0] += 1
                    return
                }
                if values.isSymbolicLink == true {
                    exclusionCounts["symbolic-links", default: 0] += 1
                    return
                }

                let targetURL = targetRoot.appendingPathComponent(relativePath, isDirectory: values.isDirectory == true)
                if values.isDirectory == true {
                    try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true)
                    directories.append(ArchiveDirectory(sourceID: sourceID, relativePath: relativePath))
                    return
                }
                guard values.isRegularFile == true else { return }

                do {
                    try fileManager.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try fileManager.copyItem(at: url, to: targetURL)
                    let digest = try sha256(of: targetURL)
                    let archivePath = "\(archiveRootName)/\(relativePath)"
                    entries.append(
                        ArchiveEntry(
                            sourceID: sourceID,
                            relativePath: relativePath,
                            archiveRelativePath: archivePath,
                            byteCount: UInt64(values.fileSize ?? 0),
                            sha256: digest
                        )
                    )
                } catch {
                    errorCount += 1
                }
            }
        }

        let manifest = ArchiveManifest(
            schemaVersion: 3,
            createdAt: createdAt,
            appName: "CodexVault",
            modules: Array(Set(sources.map(\.kind.rawValue))).sorted(),
            sources: archiveSources,
            entries: entries.sorted { $0.archiveRelativePath < $1.archiveRelativePath },
            directories: directories.sorted { $0.sourceID + $0.relativePath < $1.sourceID + $1.relativePath },
            exclusionCounts: exclusionCounts,
            errorCount: errorCount
        )
        let manifestURL = packageURL.appendingPathComponent("manifest.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(manifest).write(to: manifestURL, options: .atomic)

        let verified = try verify(packageURL: packageURL)
        guard verified else { throw BackupError.verificationFailed }
        if let password, !password.isEmpty {
            try EncryptedArchive.encrypt(packageURL: packageURL, password: password)
        }
        try createPackageZIP(packageURL: packageURL, archiveURL: archiveURL)
        try runTool("/usr/bin/unzip", arguments: ["-tq", archiveURL.path])

        return ArchiveSummary(
            id: UUID(),
            packageURL: archiveURL,
            createdAt: createdAt,
            fileCount: entries.count,
            byteCount: entries.reduce(0) { $0 + $1.byteCount },
            verified: true
        )
    }

    /// The built-in equivalent of the previous complete-backup script. It always
    /// backs up the same two workspace roots and never asks the user to choose a
    /// script or source folder.
    func createStandardCompleteBackup(
        projectRoots: [URL],
        destination: URL,
        progress: @escaping @Sendable (CompleteBackupProgress) -> Void = { _ in }
    ) throws -> CompleteBackupSummary {
        let home = fileManager.homeDirectoryForCurrentUser
        var reservedArchiveBases: Set<String> = ["codex_backup"]
        let projectSources = projectRoots.map { root in
            CompleteBackupSource(
                url: root,
                archiveBase: uniqueCompleteArchiveBase(for: root, reservedBases: &reservedArchiveBases),
                kind: .ordnung
            )
        }
        return try createCompleteBackup(sources: [
            CompleteBackupSource(url: home.appendingPathComponent(".codex", isDirectory: true), archiveBase: "codex_backup", kind: .codex),
        ] + projectSources, destination: destination, progress: progress)
    }

    func createCompleteBackup(
        sources: [CompleteBackupSource],
        destination: URL,
        progress: @escaping @Sendable (CompleteBackupProgress) -> Void = { _ in }
    ) throws -> CompleteBackupSummary {
        guard !sources.isEmpty else { throw BackupError.noSources }
        let createdAt = Date()
        let timestamp = Self.scriptTimestamp.string(from: createdAt)
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)

        var zipURLs: [URL] = []
        var copiedFileCount = 0
        var copiedByteCount: UInt64 = 0
        var skippedSourceNames: [String] = []

        for (index, profile) in sources.enumerated() {
            guard fileManager.fileExists(atPath: profile.url.path) else {
                skippedSourceNames.append(profile.url.lastPathComponent)
                continue
            }
            let start = Double(index) / Double(sources.count)
            let name = profile.url.lastPathComponent == ".codex" ? "Codex" : profile.url.lastPathComponent
            progress(CompleteBackupProgress(fractionCompleted: start + 0.03, message: "\(CodexVaultLocalization.text("Preparing")) \(name)…"))
            let zipURL = destination.appendingPathComponent("\(profile.archiveBase)_\(timestamp).zip")
            let latestURL = destination.appendingPathComponent("\(profile.archiveBase)_latest.zip")
            let fileListURL = try makeCompleteBackupFileList(
                for: profile,
                copiedFileCount: &copiedFileCount,
                copiedByteCount: &copiedByteCount
            )
            defer { try? fileManager.removeItem(at: fileListURL) }
            progress(CompleteBackupProgress(fractionCompleted: start + 0.15, message: "\(CodexVaultLocalization.text("Creating")) \(name) ZIP…"))
            try runZip(zipURL: zipURL, sourceRoot: profile.url, fileListURL: fileListURL)
            progress(CompleteBackupProgress(fractionCompleted: start + 0.35, message: "\(CodexVaultLocalization.text("Verifying")) \(name) ZIP…"))
            try runTool("/usr/bin/unzip", arguments: ["-tq", zipURL.path])
            if fileManager.fileExists(atPath: latestURL.path) {
                try fileManager.removeItem(at: latestURL)
            }
            try fileManager.copyItem(at: zipURL, to: latestURL)
            zipURLs.append(zipURL)
            progress(CompleteBackupProgress(fractionCompleted: Double(index + 1) / Double(sources.count), message: "\(name) \(CodexVaultLocalization.text("backup completed."))"))
        }

        guard !zipURLs.isEmpty else { throw BackupError.noSources }

        progress(CompleteBackupProgress(fractionCompleted: 1, message: CodexVaultLocalization.text("Complete backup verified.")))
        return CompleteBackupSummary(
            zipURLs: zipURLs,
            createdAt: createdAt,
            fileCount: copiedFileCount,
            byteCount: copiedByteCount,
            skippedSourceNames: skippedSourceNames
        )
    }

    func datedCompleteBackups(in destination: URL, keeping keepCount: Int = 3) throws -> [URL] {
        let contents = try fileManager.contentsOfDirectory(
            at: destination,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )
        let dated = contents.filter {
            let name = $0.lastPathComponent
            return name.hasSuffix(".zip") &&
                name.contains("_backup_") &&
                !name.hasSuffix("_latest.zip")
        }
        let grouped = Dictionary(grouping: dated) { url in
            url.lastPathComponent.split(separator: "_").prefix(2).joined(separator: "_")
        }
        return grouped.values.flatMap { backups in
            Array(backups.sorted { $0.lastPathComponent > $1.lastPathComponent }.dropFirst(max(keepCount, 0)))
        }
    }

    func removeCompleteBackups(_ urls: [URL]) throws {
        for url in urls where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    func sessionCleanupPreview(limit: Int = 12) throws -> SessionCleanupPreview {
        let sessionsRoot = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions", isDirectory: true)
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        guard let enumerator = fileManager.enumerator(
            at: sessionsRoot,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            return SessionCleanupPreview(totalFileCount: 0, totalBytes: 0, largestSessions: [], projectGroups: [], unassignedRecords: [], storageCategories: [])
        }

        var items: [(url: URL, date: Date, byteCount: UInt64)] = []
        var totalBytes: UInt64 = 0
        var totalFileCount = 0
        while let url = enumerator.nextObject() as? URL {
            let values = try url.resourceValues(forKeys: keys)
            guard values.isRegularFile == true, url.pathExtension == "jsonl" else { continue }
            let bytes = UInt64(values.fileSize ?? 0)
            totalFileCount += 1
            totalBytes += bytes
            items.append((url: url, date: values.contentModificationDate ?? .distantPast, byteCount: bytes))
        }
        let projectIndex = sessionProjectIndex()
        var projectTotals: [String: (count: Int, bytes: UInt64)] = [:]
        var unassignedRecords: [UnassignedSessionRecord] = []
        for item in items {
            let currentProject = indexedProjectName(for: item.url, in: projectIndex)
                ?? parentThreadID(in: item.url).flatMap { projectIndex[$0] }
            let sourceFolder = sessionWorkingFolder(in: item.url) ?? CodexVaultLocalization.text("Unknown local source")
            let projectName = currentProject ?? "\(CodexVaultLocalization.text("Earlier local work:")) \(sourceFolder)"
            if currentProject == nil {
                let relativePath = item.url.path.replacingOccurrences(of: sessionsRoot.path + "/", with: "")
                unassignedRecords.append(UnassignedSessionRecord(
                    id: relativePath,
                    relativePath: relativePath,
                    sourceFolder: sourceFolder,
                    date: item.date,
                    byteCount: item.byteCount
                ))
            }
            let current = projectTotals[projectName, default: (0, 0)]
            projectTotals[projectName] = (current.count + 1, current.bytes + item.byteCount)
        }
        let projectGroups = projectTotals.map { name, total in
            SessionProjectGroup(id: name, projectName: name, recordCount: total.count, byteCount: total.bytes)
        }.sorted { $0.byteCount > $1.byteCount }
        let largest = items.sorted { $0.byteCount > $1.byteCount }.prefix(limit).map { item in
            let directProject = indexedProjectName(for: item.url, in: projectIndex)
            let parentProject = parentThreadID(in: item.url).flatMap { projectIndex[$0] }
            return SessionPreviewItem(
                id: item.url.lastPathComponent,
                date: item.date,
                byteCount: item.byteCount,
                projectName: directProject ?? parentProject,
                title: sessionTitle(in: item.url)
            )
        }
        return SessionCleanupPreview(
            totalFileCount: totalFileCount,
            totalBytes: totalBytes,
            largestSessions: largest,
            projectGroups: projectGroups,
            unassignedRecords: unassignedRecords.sorted { $0.date > $1.date },
            storageCategories: try codexStorageCategories()
        )
    }

    func removeUnassignedSessionRecords(_ records: [UnassignedSessionRecord]) throws {
        let sessionsRoot = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions", isDirectory: true)
            .standardizedFileURL
        for record in records {
            guard !record.relativePath.contains("..") else { throw BackupError.invalidBackup }
            let target = sessionsRoot.appendingPathComponent(record.relativePath).standardizedFileURL
            guard target.path.hasPrefix(sessionsRoot.path + "/"),
                  target.pathExtension == "jsonl",
                  fileManager.fileExists(atPath: target.path) else { continue }
            try fileManager.removeItem(at: target)
        }
    }

    private func sessionProjectIndex() -> [String: String] {
        let indexURL = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/session_index.jsonl")
        guard let content = try? String(contentsOf: indexURL, encoding: .utf8) else { return [:] }
        let decoder = JSONDecoder()
        var result: [String: String] = [:]
        for line in content.split(separator: "\n") {
            guard let record = try? decoder.decode(SessionIndexRecord.self, from: Data(line.utf8)) else { continue }
            result[record.id] = record.threadName
        }
        return result
    }

    private func indexedProjectName(for url: URL, in index: [String: String]) -> String? {
        let name = url.deletingPathExtension().lastPathComponent
        guard let expression = try? NSRegularExpression(pattern: #"[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}"#) else { return nil }
        let range = NSRange(name.startIndex..., in: name)
        guard let match = expression.matches(in: name, range: range).last,
              let identifierRange = Range(match.range, in: name) else { return nil }
        return index[String(name[identifierRange])]
    }

    private func parentThreadID(in url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 1_000_000),
              let text = String(data: data, encoding: .utf8),
              let expression = try? NSRegularExpression(pattern: #""parent_thread_id"\s*:\s*"([^"]+)""#) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = expression.firstMatch(in: text, range: range),
              let identifierRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[identifierRange])
    }

    private func sessionWorkingFolder(in url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 1_000_000),
              let text = String(data: data, encoding: .utf8),
              let expression = try? NSRegularExpression(pattern: #""cwd"\s*:\s*"([^"]+)""#) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = expression.firstMatch(in: text, range: range),
              let pathRange = Range(match.range(at: 1), in: text) else { return nil }
        return URL(fileURLWithPath: String(text[pathRange])).lastPathComponent
    }

    private func sessionTitle(in url: URL) -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return "Untitled local record" }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 1_000_000),
              let text = String(data: data, encoding: .utf8),
              let expression = try? NSRegularExpression(pattern: #""title"\s*:\s*"((?:\\.|[^"\\])*)""#) else {
            return "Untitled local record"
        }
        let range = NSRange(text.startIndex..., in: text)
        let matches = expression.matches(in: text, range: range)
        guard let match = matches.first, let titleRange = Range(match.range(at: 1), in: text) else {
            return "Untitled local record"
        }
        let title = String(text[titleRange])
            .replacingOccurrences(of: #"\""#, with: "\"")
            .replacingOccurrences(of: #"\\"#, with: "\\")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Untitled local record" : title
    }

    private func codexStorageCategories() throws -> [CodexStorageCategory] {
        let codexRoot = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey]
        guard let enumerator = fileManager.enumerator(
            at: codexRoot,
            includingPropertiesForKeys: Array(keys),
            options: []
        ) else { return [] }

        var totals: [String: UInt64] = [:]
        while let url = enumerator.nextObject() as? URL {
            let values = try url.resourceValues(forKeys: keys)
            guard values.isRegularFile == true else { continue }
            let relativePath = url.path.replacingOccurrences(of: codexRoot.path + "/", with: "")
            let firstComponent = relativePath.split(separator: "/", maxSplits: 1).first.map(String.init) ?? ""
            let category = codexStorageCategory(for: firstComponent, relativePath: relativePath)
            totals[category, default: 0] += UInt64(values.fileSize ?? 0)
        }

        return totals.map { key, bytes in
            CodexStorageCategory(id: key, title: key, byteCount: bytes)
        }.sorted { $0.byteCount > $1.byteCount }
    }

    private func codexStorageCategory(for firstComponent: String, relativePath: String) -> String {
        return switch firstComponent {
        case "sessions": CodexVaultLocalization.text("Active sessions")
        case "archived_sessions": CodexVaultLocalization.text("Archived sessions")
        case "sqlite": CodexVaultLocalization.text("SQLite databases")
        case "plugins": CodexVaultLocalization.text("Plugins")
        case "pet-runs": CodexVaultLocalization.text("Pet runs")
        case "generated_images": CodexVaultLocalization.text("Generated images")
        case "pets": CodexVaultLocalization.text("Pets")
        case ".tmp", "tmp": CodexVaultLocalization.text("Temporary data")
        case "cache", "caches", "models_cache": CodexVaultLocalization.text("Caches")
        default:
            if relativePath.hasSuffix(".sqlite") || relativePath.contains(".sqlite-") {
                CodexVaultLocalization.text("SQLite databases")
            } else {
                CodexVaultLocalization.text("Other Codex data")
            }
        }
    }

    private struct SessionIndexRecord: Decodable {
        let id: String
        let threadName: String

        enum CodingKeys: String, CodingKey {
            case id
            case threadName = "thread_name"
        }
    }

    func verify(packageURL: URL) throws -> Bool {
        try withResolvedPackage(from: packageURL) { package in
            try verifyDirectory(packageURL: package)
        }
    }

    func isEncryptedBackup(at packageURL: URL) throws -> Bool {
        try withUnpackedPackage(from: packageURL) { package in
            EncryptedArchive.isEncrypted(packageURL: package)
        }
    }

    func manifestForRestore(packageURL: URL, password: String? = nil) throws -> ArchiveManifest {
        try withResolvedPackage(from: packageURL, password: password) { package in
            guard try verifyDirectory(packageURL: package) else { throw BackupError.invalidBackup }
            return try manifest(in: package)
        }
    }

    private func verifyDirectory(packageURL: URL) throws -> Bool {
        let manifest = try manifest(in: packageURL)
        guard [1, 2, 3].contains(manifest.schemaVersion) else { return false }

        for entry in manifest.entries {
            let fileURL = packageURL.appendingPathComponent(entry.archiveRelativePath)
            guard fileManager.fileExists(atPath: fileURL.path) else {
                return false
            }
            guard try sha256(of: fileURL) == entry.sha256 else {
                return false
            }
        }
        return true
    }

    func manifest(in packageURL: URL) throws -> ArchiveManifest {
        let manifestURL = packageURL.appendingPathComponent("manifest.json")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ArchiveManifest.self, from: Data(contentsOf: manifestURL))
    }

    func restore(
        packageURL: URL,
        sourceIDs: Set<String>,
        destination: URL,
        password: String? = nil
    ) throws -> RestoreSummary {
        guard !sourceIDs.isEmpty else { throw BackupError.noRestoreSelection }
        return try withResolvedPackage(from: packageURL, password: password) { resolvedPackage in
            try restoreDirectory(
                packageURL: resolvedPackage,
                sourceIDs: sourceIDs,
                destination: destination
            )
        }
    }

    private func restoreDirectory(
        packageURL: URL,
        sourceIDs: Set<String>,
        destination: URL
    ) throws -> RestoreSummary {
        guard try verifyDirectory(packageURL: packageURL) else { throw BackupError.invalidBackup }

        let restoreRoot = destination
            .appendingPathComponent("CodexVault-Restore-\(Self.packageTimestamp.string(from: Date()))", isDirectory: true)
        try fileManager.createDirectory(at: restoreRoot, withIntermediateDirectories: true)
        let manifest = try manifest(in: packageURL)
        var restoredFileCount = 0
        var archiveRootNames: [String: String] = [:]
        for source in manifest.sources ?? [] {
            archiveRootNames[source.sourceID] = source.archiveRootName
        }

        for directory in manifest.directories where sourceIDs.contains(directory.sourceID) {
            let archiveRootName = archiveRootNames[directory.sourceID] ?? directory.sourceID
            let directoryURL = restoreRoot
                .appendingPathComponent(archiveRootName, isDirectory: true)
                .appendingPathComponent(directory.relativePath, isDirectory: true)
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        for entry in manifest.entries where sourceIDs.contains(entry.sourceID) {
            let sourceURL = packageURL.appendingPathComponent(entry.archiveRelativePath)
            let archiveRootName = archiveRootNames[entry.sourceID] ?? entry.sourceID
            let destinationURL = restoreRoot
                .appendingPathComponent(archiveRootName, isDirectory: true)
                .appendingPathComponent(entry.relativePath)
            try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            guard try sha256(of: destinationURL) == entry.sha256 else {
                throw BackupError.verificationFailed
            }
            restoredFileCount += 1
        }

        return RestoreSummary(destinationURL: restoreRoot, restoredFileCount: restoredFileCount, verified: true)
    }

    private func withResolvedPackage<T>(
        from sourceURL: URL,
        password: String? = nil,
        operation: (URL) throws -> T
    ) throws -> T {
        try withUnpackedPackage(from: sourceURL) { unpackedPackage in
            guard EncryptedArchive.isEncrypted(packageURL: unpackedPackage) else {
                return try operation(unpackedPackage)
            }
            guard let password, !password.isEmpty else { throw BackupError.invalidBackup }
            let decryptedPackage = try EncryptedArchive.decryptedPackage(from: unpackedPackage, password: password)
            defer { try? fileManager.removeItem(at: decryptedPackage.deletingLastPathComponent()) }
            return try operation(decryptedPackage)
        }
    }

    private func withUnpackedPackage<T>(
        from sourceURL: URL,
        operation: (URL) throws -> T
    ) throws -> T {
        if sourceURL.pathExtension.lowercased() != "zip" {
            return try operation(sourceURL)
        }

        let root = fileManager.temporaryDirectory
            .appendingPathComponent("CodexVault-Unpack-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try runTool("/usr/bin/ditto", arguments: ["-x", "-k", sourceURL.path, root.path])
        let packages = try fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ).filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        guard packages.count == 1 else { throw BackupError.invalidBackup }
        return try operation(packages[0])
    }

    private func createPackageZIP(packageURL: URL, archiveURL: URL) throws {
        guard !fileManager.fileExists(atPath: archiveURL.path) else {
            throw BackupError.destinationUnavailable
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", packageURL.path, archiveURL.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw BackupError.verificationFailed }
    }

    private func enumerate(
        _ root: URL,
        visitor: (URL, URLResourceValues, String) throws -> Void
    ) throws {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsPackageDescendants]
        ) else { return }
        let resolvedRootPath = root.standardizedFileURL.resolvingSymlinksInPath().path
        let rootPrefix = resolvedRootPath.hasSuffix("/") ? resolvedRootPath : resolvedRootPath + "/"

        while let url = enumerator.nextObject() as? URL {
            let values = try url.resourceValues(forKeys: keys)
            let resolvedPath = url.standardizedFileURL.resolvingSymlinksInPath().path
            guard resolvedPath.hasPrefix(rootPrefix) else { continue }
            let relativePath = String(resolvedPath.dropFirst(rootPrefix.count))
            try visitor(url, values, relativePath)
            if exclusionKind(for: url.lastPathComponent) != .none, values.isDirectory == true {
                enumerator.skipDescendants()
            }
        }
    }

    private func sha256(of url: URL) throws -> String {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Builds the input passed to zip -@. This keeps the source layout intact and
    /// avoids a second, multi-gigabyte copy in a temporary folder.
    private func makeCompleteBackupFileList(
        for profile: CompleteBackupSource,
        copiedFileCount: inout Int,
        copiedByteCount: inout UInt64
    ) throws -> URL {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
        guard let enumerator = fileManager.enumerator(
            at: profile.url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsPackageDescendants]
        ) else { throw BackupError.noSources }

        let parentPath = profile.url.deletingLastPathComponent().standardizedFileURL.path
        let prefix = parentPath.hasSuffix("/") ? parentPath : parentPath + "/"
        var entries = [profile.url.lastPathComponent]
        while let url = enumerator.nextObject() as? URL {
            let values = try url.resourceValues(forKeys: keys)
            if shouldExcludeFromCompleteBackup(url, sourceRoot: profile.url, profile: profile.kind) {
                if values.isDirectory == true { enumerator.skipDescendants() }
                continue
            }
            let sourcePath = url.standardizedFileURL.path
            guard sourcePath.hasPrefix(prefix) else { continue }
            guard values.isDirectory == true || values.isRegularFile == true || values.isSymbolicLink == true else { continue }
            entries.append(String(sourcePath.dropFirst(prefix.count)))
            if values.isRegularFile == true {
                copiedFileCount += 1
                copiedByteCount += UInt64(values.fileSize ?? 0)
            }
        }

        let fileListURL = fileManager.temporaryDirectory
            .appendingPathComponent("CodexVault-ZIP-\(UUID().uuidString).txt")
        try entries.joined(separator: "\n").appending("\n").write(to: fileListURL, atomically: true, encoding: .utf8)
        return fileListURL
    }

    private func runZip(zipURL: URL, sourceRoot: URL, fileListURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-q", "-y", zipURL.path, "-@"]
        process.currentDirectoryURL = sourceRoot.deletingLastPathComponent()
        let input = try FileHandle(forReadingFrom: fileListURL)
        defer { try? input.close() }
        process.standardInput = input
        let errorPipe = Pipe()
        process.standardError = errorPipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw BackupError.completeBackupFailed(error.localizedDescription)
        }
        guard process.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw BackupError.completeBackupFailed(message?.isEmpty == false ? message! : "ZIP creation failed.")
        }
    }

    private func uniqueCompleteArchiveBase(for root: URL, reservedBases: inout Set<String>) -> String {
        let rawName = root.lastPathComponent.lowercased()
        let normalized = rawName.replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
        let folderBase = normalized.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let base = "\(folderBase == "codex" ? "documents-codex" : folderBase)_backup"
        var candidate = base == "_backup" ? "projects_backup" : base
        var suffix = 2
        while reservedBases.contains(candidate) {
            candidate = "\(base)_\(suffix)"
            suffix += 1
        }
        reservedBases.insert(candidate)
        return candidate
    }

    private func copyCompleteSource(
        _ sourceRoot: URL,
        to targetRoot: URL,
        profile: CompleteBackupSource.Kind,
        copiedFileCount: inout Int,
        copiedByteCount: inout UInt64
    ) throws {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
        guard let enumerator = fileManager.enumerator(
            at: sourceRoot,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsPackageDescendants]
        ) else { return }
        // Keep the path as it appears inside the selected source. Resolving a
        // symbolic link here can map two distinct source paths to the same staging
        // path, which caused the duplicate-file error in the Codex Chrome cache.
        let sourceRootPath = sourceRoot.standardizedFileURL.path
        let prefix = sourceRootPath.hasSuffix("/") ? sourceRootPath : sourceRootPath + "/"

        while let url = enumerator.nextObject() as? URL {
            let values = try url.resourceValues(forKeys: keys)
            if shouldExcludeFromCompleteBackup(url, sourceRoot: sourceRoot, profile: profile) {
                if values.isDirectory == true { enumerator.skipDescendants() }
                continue
            }
            let sourcePath = url.standardizedFileURL.path
            guard sourcePath.hasPrefix(prefix) else { continue }
            let relativePath = String(sourcePath.dropFirst(prefix.count))
            let target = targetRoot.appendingPathComponent(relativePath, isDirectory: values.isDirectory == true)
            if values.isDirectory == true {
                try fileManager.createDirectory(at: target, withIntermediateDirectories: true)
            } else if values.isSymbolicLink == true {
                let targetPath = try fileManager.destinationOfSymbolicLink(atPath: url.path)
                try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fileManager.createSymbolicLink(atPath: target.path, withDestinationPath: targetPath)
            } else if values.isRegularFile == true {
                try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fileManager.copyItem(at: url, to: target)
                copiedFileCount += 1
                copiedByteCount += UInt64(values.fileSize ?? 0)
            }
        }
    }

    private func shouldExcludeFromCompleteBackup(_ url: URL, sourceRoot: URL, profile: CompleteBackupSource.Kind) -> Bool {
        let name = url.lastPathComponent.lowercased()
        if profile == .ordnung && [".build", ".build-cache", ".swiftpm", "build", "node_modules"].contains(name) { return true }
        if profile == .codex && ["tmp", ".tmp"].contains(name) { return true }
        let codexIPCPath = sourceRoot.appendingPathComponent("ipc", isDirectory: true).standardizedFileURL.path
        if profile == .codex && (url.standardizedFileURL.path == codexIPCPath || url.standardizedFileURL.path.hasPrefix(codexIPCPath + "/")) { return true }
        if profile == .codex && url.path.hasSuffix("/vendor_imports/skills/.git/fsmonitor--daemon.ipc") { return true }
        return false
    }

    private func runTool(_ executable: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let errorPipe = Pipe()
        process.standardError = errorPipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw BackupError.completeBackupFailed(error.localizedDescription)
        }
        guard process.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw BackupError.completeBackupFailed(message?.isEmpty == false ? message! : "ZIP validation failed.")
        }
    }

    private func exclusionKind(for fileName: String) -> ExclusionKind {
        let lowercased = fileName.lowercased()
        if lowercased == ".env" || lowercased.hasPrefix(".env.") ||
            lowercased.contains("token") || lowercased.contains("secret") ||
            lowercased.contains("credential") || [".pem", ".key", ".p12", ".pfx"].contains(where: { lowercased.hasSuffix($0) }) {
            return .sensitive
        }
        if [".git", ".build", "deriveddata", "node_modules", "cache", "caches"].contains(lowercased) {
            return .standard
        }
        return .none
    }

    private func uniqueArchiveRootName(for source: BackupSource, reservedNames: inout Set<String>) -> String {
        let baseName = source.displayName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let safeBaseName = baseName.isEmpty ? "Selected Folder" : baseName
        var candidate = safeBaseName
        var suffix = 2
        while reservedNames.contains(candidate.localizedLowercase) {
            candidate = "\(safeBaseName) \(suffix)"
            suffix += 1
        }
        reservedNames.insert(candidate.localizedLowercase)
        return candidate
    }

    private func normalBackupBaseName(for sources: [BackupSource], customName: String?) -> String {
        if let customName {
            let sanitized = sanitizedBackupName(customName)
            if !sanitized.isEmpty { return String(sanitized.prefix(96)) }
        }
        var seenNames: Set<String> = []
        let names = sources.compactMap { source -> String? in
            let name = sanitizedBackupName(source.displayName)
            guard !name.isEmpty, seenNames.insert(name.localizedLowercase).inserted else { return nil }
            return name
        }
        return String((names.isEmpty ? "Backup" : names.joined(separator: "-")) .prefix(96))
    }

    private func sanitizedBackupName(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:").union(.controlCharacters)
        let normalized = String(value.unicodeScalars.map { invalid.contains($0) ? Character("-") : Character(String($0)) })
        return normalized
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private enum ExclusionKind {
        case none
        case sensitive
        case standard

        var reportKey: String {
            switch self {
            case .none: "none"
            case .sensitive: "sensitive-files"
            case .standard: "standard-artifacts"
            }
        }
    }

    private static let packageTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter
    }()

    private static let scriptTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()
}
