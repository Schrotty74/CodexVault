import Foundation

struct ProjectCandidate: Identifiable, Hashable, Sendable {
    let url: URL
    let signals: [String]

    var id: URL { url }
    var displayName: String { url.lastPathComponent }
}

enum ProjectDiscovery {
    private static let markerNames: [String: String] = [
        "Package.swift": "Swift package",
        "package.json": "Node project",
        "pyproject.toml": "Python project",
        "requirements.txt": "Python project",
        "Cargo.toml": "Rust project",
        "go.mod": "Go module",
        "pom.xml": "Java project",
        "build.gradle": "Gradle project"
    ]

    private static let skippedDirectoryNames: Set<String> = [
        ".git", ".build", "node_modules", "DerivedData", "Pods", "build", "dist", ".swiftpm"
    ]

    static func candidates(in scope: URL, maximumDepth: Int = 4) throws -> [ProjectCandidate] {
        let manager = FileManager.default
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey]
        guard let enumerator = manager.enumerator(
            at: scope,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var signalsByDirectory: [URL: Set<String>] = [:]
        while let url = enumerator.nextObject() as? URL {
            let relativeComponents = url.pathComponents.dropFirst(scope.pathComponents.count)
            if relativeComponents.count > maximumDepth + 1 {
                if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                    enumerator.skipDescendants()
                }
                continue
            }
            let values = try url.resourceValues(forKeys: keys)
            if values.isDirectory == true {
                if skippedDirectoryNames.contains(url.lastPathComponent) {
                    enumerator.skipDescendants()
                    continue
                }
                if url.pathExtension == "xcodeproj" {
                    signalsByDirectory[url.deletingLastPathComponent().standardizedFileURL, default: []].insert("Xcode project")
                    enumerator.skipDescendants()
                }
                continue
            }
            guard values.isRegularFile == true else { continue }
            let directory = url.deletingLastPathComponent().standardizedFileURL
            if let signal = markerNames[url.lastPathComponent] {
                signalsByDirectory[directory, default: []].insert(signal)
            }
            if url.lastPathComponent == "config.json", directory.lastPathComponent == ".git" {
                signalsByDirectory[directory.deletingLastPathComponent().standardizedFileURL, default: []].insert("Git repository")
            }
        }

        return signalsByDirectory.map { url, signals in
            ProjectCandidate(url: url, signals: signals.sorted())
        }.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
}
