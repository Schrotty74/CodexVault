import Foundation

enum BackupSourceKind: String, Codable, CaseIterable, Sendable {
    case project
    case folder
    case chatGPTExport

    var title: String {
        switch self {
        case .project: CodexVaultLocalization.text("Project")
        case .folder: CodexVaultLocalization.text("Additional folder")
        case .chatGPTExport: "ChatGPT export"
        }
    }
}

struct BackupSource: Identifiable, Sendable {
    let id: UUID
    let kind: BackupSourceKind
    let url: URL
    var preview: SourcePreview?

    init(id: UUID = UUID(), kind: BackupSourceKind, url: URL, preview: SourcePreview? = nil) {
        self.id = id
        self.kind = kind
        self.url = url
        self.preview = preview
    }

    var displayName: String {
        url.lastPathComponent.isEmpty ? kind.title : url.lastPathComponent
    }
}

struct CompleteBackupSource: Sendable {
    enum Kind: Sendable { case codex, ordnung, normal }

    let url: URL
    let archiveBase: String
    let kind: Kind

    init(url: URL, archiveBase: String = "complete_backup", kind: Kind = .normal) {
        self.url = url
        self.archiveBase = archiveBase
        self.kind = kind
    }
}

enum FullBackupScheduleInterval: String, CaseIterable, Codable, Identifiable, Sendable {
    case daily
    case weekly

    var id: Self { self }

    var seconds: TimeInterval {
        switch self {
        case .daily: 86_400
        case .weekly: 604_800
        }
    }

    var title: String {
        switch self {
        case .daily: CodexVaultLocalization.text("Daily")
        case .weekly: CodexVaultLocalization.text("Weekly")
        }
    }
}

struct SourcePreview: Sendable {
    let fileCount: Int
    let estimatedBytes: UInt64
    let sensitiveExclusionCount: Int
    let standardExclusionCount: Int
}

struct ArchiveEntry: Codable, Sendable {
    let sourceID: String
    let relativePath: String
    let archiveRelativePath: String
    let byteCount: UInt64
    let sha256: String
}

struct ArchiveDirectory: Codable, Sendable {
    let sourceID: String
    let relativePath: String
}

struct ArchiveSource: Codable, Sendable {
    let sourceID: String
    let archiveRootName: String
}

struct ArchiveManifest: Codable, Sendable {
    let schemaVersion: Int
    let createdAt: Date
    let appName: String
    let modules: [String]
    let sources: [ArchiveSource]?
    let entries: [ArchiveEntry]
    let directories: [ArchiveDirectory]
    let exclusionCounts: [String: Int]
    let errorCount: Int
}

struct ArchiveSummary: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let packageURL: URL
    let createdAt: Date
    let fileCount: Int
    let byteCount: UInt64
    let verified: Bool

    var displayName: String {
        "CodexVault Backup – " + Self.formatter.string(from: createdAt)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

enum ArchiveHistory {
    static func decode(_ data: Data?) -> [ArchiveSummary] {
        guard let data,
              let summaries = try? JSONDecoder().decode([ArchiveSummary].self, from: data) else {
            return []
        }
        return existingSummaries(from: summaries)
    }

    static func encode(_ summaries: [ArchiveSummary]) -> Data? {
        try? JSONEncoder().encode(summaries)
    }

    static func existingSummaries(from summaries: [ArchiveSummary]) -> [ArchiveSummary] {
        summaries
            .filter { summary in
                var isDirectory: ObjCBool = false
                return FileManager.default.fileExists(
                    atPath: summary.packageURL.path,
                    isDirectory: &isDirectory
                ) && isDirectory.boolValue
            }
            .sorted { $0.createdAt > $1.createdAt }
    }
}

struct CompleteBackupSummary: Sendable {
    let zipURLs: [URL]
    let createdAt: Date
    let fileCount: Int
    let byteCount: UInt64
    let skippedSourceNames: [String]
}

struct CompleteBackupProgress: Sendable {
    let fractionCompleted: Double
    let message: String
}

struct SessionCleanupPreview: Sendable {
    let totalFileCount: Int
    let totalBytes: UInt64
    let largestSessions: [SessionPreviewItem]
    let projectGroups: [SessionProjectGroup]
    let unassignedRecords: [UnassignedSessionRecord]
    let storageCategories: [CodexStorageCategory]
}

struct UnassignedSessionRecord: Identifiable, Sendable {
    let id: String
    let relativePath: String
    let sourceFolder: String
    let date: Date
    let byteCount: UInt64
}

struct SessionProjectGroup: Identifiable, Sendable {
    let id: String
    let projectName: String
    let recordCount: Int
    let byteCount: UInt64
}

struct CodexStorageCategory: Identifiable, Sendable {
    let id: String
    let title: String
    let byteCount: UInt64
}

struct SessionPreviewItem: Identifiable, Sendable {
    let id: String
    let date: Date
    let byteCount: UInt64
    let projectName: String?
    let title: String
}

struct RestoreSummary: Sendable {
    let destinationURL: URL
    let restoredFileCount: Int
    let verified: Bool
}

enum BackupError: LocalizedError {
    case noSources
    case destinationUnavailable
    case verificationFailed
    case invalidBackup
    case noRestoreSelection
    case completeBackupFailed(String)

    var errorDescription: String? {
        switch self {
        case .noSources: CodexVaultLocalization.text("Choose at least one source before creating a backup.")
        case .destinationUnavailable: CodexVaultLocalization.text("Choose a writable backup destination.")
        case .verificationFailed: CodexVaultLocalization.text("The backup was created but did not pass the integrity check.")
        case .invalidBackup: CodexVaultLocalization.text("This CodexVault package could not be verified.")
        case .noRestoreSelection: CodexVaultLocalization.text("Choose at least one source to restore.")
        case let .completeBackupFailed(reason): "\(CodexVaultLocalization.text("The complete backup could not be created:")) \(reason)"
        }
    }
}
