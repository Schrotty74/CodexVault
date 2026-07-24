import AppKit
import SwiftUI

@main
struct ArchiveAtlasApp: App {
    var body: some Scene {
        WindowGroup {
            ArchiveAtlasRootView()
                .frame(minWidth: 1_040, minHeight: 700)
        }
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unified(showsTitle: false))
    }
}

private enum AppSection: String, CaseIterable, Identifiable {
    case overview
    case backup
    case restore
    case archive
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .backup: "Backup"
        case .restore: "Restore"
        case .archive: "Archive"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .backup: "externaldrive.badge.plus"
        case .restore: "arrow.counterclockwise"
        case .archive: "archivebox"
        case .settings: "gearshape"
        }
    }
}

private enum DisplayTheme: String, CaseIterable, Identifiable {
    case liquidGlass = "Liquid Glass"
    case fullGlass = "Full Glass"
    case graphiteLime = "Graphite & Lime"
    case midnight = "Midnight"

    var id: Self { self }

    var tint: Color {
        switch self {
        case .liquidGlass: .blue
        case .fullGlass: .cyan
        case .graphiteLime: Color(red: 0.73, green: 0.91, blue: 0.20)
        case .midnight: Color(red: 0.41, green: 0.39, blue: 1.0)
        }
    }

    var background: LinearGradient {
        switch self {
        case .liquidGlass:
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color(nsColor: .controlBackgroundColor)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .fullGlass:
            LinearGradient(colors: [.cyan.opacity(0.24), .blue.opacity(0.12), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .graphiteLime:
            LinearGradient(colors: [.gray.opacity(0.26), .black.opacity(0.28)], startPoint: .top, endPoint: .bottom)
        case .midnight:
            LinearGradient(colors: [.indigo.opacity(0.38), .blue.opacity(0.16), .black.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

private struct ArchiveAtlasFullGlassKey: EnvironmentKey {
    static let defaultValue = false
}

private struct ArchiveAtlasSidebarOnlyGlassKey: EnvironmentKey {
    static let defaultValue = false
}

private extension EnvironmentValues {
    var archiveAtlasFullGlass: Bool {
        get { self[ArchiveAtlasFullGlassKey.self] }
        set { self[ArchiveAtlasFullGlassKey.self] = newValue }
    }

    var archiveAtlasSidebarOnlyGlass: Bool {
        get { self[ArchiveAtlasSidebarOnlyGlassKey.self] }
        set { self[ArchiveAtlasSidebarOnlyGlassKey.self] = newValue }
    }
}

private struct ArchiveAtlasRootView: View {
    @State private var selectedSection: AppSection? = .overview
    @State private var selectedTheme: DisplayTheme = .liquidGlass
    @State private var backupCoordinator = BackupCoordinator()

    var body: some View {
        ZStack {
            if selectedTheme == .fullGlass {
                FullGlassBackdrop()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            } else {
                selectedTheme.background
                    .ignoresSafeArea()
            }

            HStack(spacing: 0) {
                sidebar
                    .frame(width: 260)

                Rectangle()
                    .fill(selectedTheme == .fullGlass ? .white.opacity(0.22) : .primary.opacity(0.10))
                    .frame(width: 1)

                detail
                    .padding(32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .environment(\.archiveAtlasFullGlass, selectedTheme == .fullGlass)
                    .environment(\.archiveAtlasSidebarOnlyGlass, selectedTheme == .liquidGlass)
            }
        }
        .tint(selectedTheme.tint)
    }

    @ViewBuilder
    private var sidebar: some View {
        if selectedTheme == .liquidGlass || selectedTheme == .fullGlass {
            NativeGlassPanel {
                ArchiveAtlasSidebar(selection: $selectedSection, theme: selectedTheme)
            }
        } else {
            ArchiveAtlasSidebar(selection: $selectedSection, theme: selectedTheme)
                .background(.regularMaterial)
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch selectedSection ?? .overview {
        case .overview:
            OverviewView(theme: selectedTheme) {
                selectedSection = .backup
            }
        case .backup:
            BackupView(theme: selectedTheme, coordinator: backupCoordinator)
        case .restore:
            RestoreView(theme: selectedTheme, coordinator: backupCoordinator)
        case .archive:
            ArchiveView(theme: selectedTheme, coordinator: backupCoordinator)
        case .settings:
            SettingsView(selectedTheme: $selectedTheme)
        }
    }
}

private struct ArchiveAtlasSidebar: View {
    @Binding var selection: AppSection?
    let theme: DisplayTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "archivebox.fill")
                    .font(.title3)
                    .foregroundStyle(theme.tint)
                Text("CodexVault")
                    .font(.headline.weight(.semibold))
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 18)

            ForEach(AppSection.allCases) { section in
                Button {
                    selection = section
                } label: {
                    Label(section.title, systemImage: section.icon)
                        .font(.body.weight(selection == section ? .semibold : .regular))
                        .foregroundStyle(selection == section ? .primary : .secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            selection == section ? theme.tint.opacity(0.16) : .clear,
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
            }

            Spacer()

            Label("Local only", systemImage: "lock.shield")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct OverviewView: View {
    let theme: DisplayTheme
    let onStartSetup: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Header(title: "Your workspace, protected.", subtitle: "CodexVault is ready when you are.")

                HStack(spacing: 16) {
                    MetricCard(icon: "clock.arrow.circlepath", title: "Last backup", value: "Not created", tint: theme.tint)
                    MetricCard(icon: "shield", title: "Protected", value: "No sources", tint: theme.tint)
                    MetricCard(icon: "externaldrive", title: "Storage", value: "0 bytes", tint: theme.tint)
                }

                SurfaceCard {
                    HStack(spacing: 24) {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 54))
                            .foregroundStyle(theme.tint)
                            .frame(width: 92, height: 92)
                            .background(theme.tint.opacity(0.12), in: Circle())

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Backup health")
                                .font(.title2.bold())
                            Text("No files have been selected. Your workspace stays private until you explicitly choose a source.")
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Button("Start setup", action: onStartSetup)
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(24)
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 0) {
                        Label("Activity", systemImage: "list.bullet.rectangle")
                            .font(.headline)
                            .padding(.bottom, 12)
                        Divider()
                        ContentUnavailableView("No activity yet", systemImage: "tray", description: Text("A verified backup will appear here after you create one."))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    }
                    .padding(20)
                }

            }
            .frame(maxWidth: 1_120, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

private struct BackupView: View {
    let theme: DisplayTheme
    @Bindable var coordinator: BackupCoordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Header(title: "Create a backup", subtitle: "Choose exactly what you want to protect.")

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Label("Sources", systemImage: "folder.badge.plus")
                                .font(.headline)
                            Spacer()
                            Button("Add project") {
                                coordinator.chooseSource(kind: .project)
                            }
                            Button("Add folder") {
                                coordinator.chooseSource(kind: .folder)
                            }
                        }

                        if coordinator.sources.isEmpty {
                            Text("No folders selected. CodexVault reads only folders you explicitly choose.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(coordinator.sources) { source in
                                HStack(spacing: 12) {
                                    Image(systemName: source.kind == .project ? "folder.fill" : "folder")
                                        .foregroundStyle(theme.tint)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(source.displayName)
                                            .font(.body.weight(.medium))
                                        if let preview = source.preview {
                                            Text("\(preview.fileCount) files · \(ByteCountFormatter.string(fromByteCount: Int64(preview.estimatedBytes), countStyle: .file))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        } else {
                                            Text("Preparing preview…")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Button(role: .destructive) {
                                        coordinator.removeSource(source)
                                    } label: {
                                        Image(systemName: "xmark.circle")
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(.vertical, 5)
                            }
                        }
                    }
                    .padding(20)
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label("Backup destination", systemImage: "externaldrive")
                                .font(.headline)
                            Spacer()
                            Button(coordinator.destinationURL == nil ? "Choose destination" : "Change") {
                                coordinator.chooseDestination()
                            }
                        }
                        Text(coordinator.destinationURL?.lastPathComponent ?? "No destination selected")
                            .foregroundStyle(coordinator.destinationURL == nil ? .secondary : .primary)
                        Text("A new portable CodexVault package is created inside this folder. Existing files are never overwritten.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(20)
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label("CodexVault full backup", systemImage: "archivebox.fill")
                                .font(.headline)
                        }
                        Text("Codex is detected automatically. Project folders and the destination are configured once for each macOS user, then used for every full backup.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("Codex app data", systemImage: "gearshape.2")
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Text("~/.codex · detected automatically")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            HStack {
                                Label("Project folders", systemImage: "folder")
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Text(coordinator.fullBackupProjectRoots.isEmpty ? "None configured" : coordinator.fullBackupProjectRoots.map(\.lastPathComponent).joined(separator: " · "))
                                    .font(.caption)
                                    .foregroundStyle(coordinator.fullBackupProjectRoots.isEmpty ? .secondary : .primary)
                            }
                        }
                        HStack {
                            Button("Configure project folders") {
                                coordinator.chooseFullBackupProjectRoots()
                            }
                            Button("Change destination") {
                                coordinator.chooseFullBackupDestination()
                            }
                        }
                        Divider()
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Full backup destination")
                                    .font(.subheadline.weight(.medium))
                                Text(coordinator.completeBackupDestinationURL.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        HStack {
                            Button(coordinator.isWorking ? "Working…" : "Create complete ZIP backup") {
                                coordinator.createCompleteBackup()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(coordinator.isWorking)
                            Spacer()
                            Text("No script selection required.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if coordinator.isWorking, let progressMessage = coordinator.completeBackupProgressMessage {
                            VStack(alignment: .leading, spacing: 7) {
                                ProgressView(value: coordinator.completeBackupProgress)
                                Text(progressMessage)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(20)
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label("Codex storage overview", systemImage: "externaldrive.badge.magnifyingglass")
                                .font(.headline)
                            Spacer()
                            Button(coordinator.isAnalyzingSessions ? "Analyzing…" : (coordinator.isSessionPreviewExpanded ? "Collapse" : "Check storage")) {
                                coordinator.toggleSessionPreview()
                            }
                            .disabled(coordinator.isAnalyzingSessions)
                        }
                        Text("Shows which local Codex data uses space. This preview does not remove or change anything.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if coordinator.isSessionPreviewExpanded, let preview = coordinator.sessionPreview {
                            Text("\(preview.totalFileCount) local Codex records · \(ByteCountFormatter.string(fromByteCount: Int64(preview.totalBytes), countStyle: .file))")
                                .font(.subheadline.weight(.medium))
                            ForEach(preview.storageCategories) { category in
                                HStack {
                                    Text(category.title)
                                    Spacer()
                                    Text(ByteCountFormatter.string(fromByteCount: Int64(category.byteCount), countStyle: .file))
                                        .foregroundStyle(.secondary)
                                }
                                .font(.caption)
                            }
                            Divider()
                            Text("Local records grouped by project")
                                .font(.subheadline.weight(.medium))
                            ForEach(preview.projectGroups) { group in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(group.projectName)
                                            .lineLimit(1)
                                            .foregroundStyle(group.projectName.hasPrefix("Earlier local work:") || group.projectName == "No current project assignment" ? .orange : .primary)
                                        Text("\(group.recordCount) local record\(group.recordCount == 1 ? "" : "s")")
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(ByteCountFormatter.string(fromByteCount: Int64(group.byteCount), countStyle: .file))
                                        .foregroundStyle(.secondary)
                                }
                                .font(.caption)
                            }
                            if !preview.unassignedRecords.isEmpty {
                                Divider()
                                Text("Unassigned local records")
                                    .font(.subheadline.weight(.medium))
                                Text("These entries are not linked to a current project. Select only records you no longer need.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                ForEach(preview.unassignedRecords) { record in
                                    Button {
                                        coordinator.toggleUnassignedRecord(record)
                                    } label: {
                                        HStack {
                                            Image(systemName: coordinator.selectedUnassignedRecordIDs.contains(record.id) ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(coordinator.selectedUnassignedRecordIDs.contains(record.id) ? theme.tint : .secondary)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(record.sourceFolder)
                                                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Text(ByteCountFormatter.string(fromByteCount: Int64(record.byteCount), countStyle: .file))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                                Button("Remove selected local records", role: .destructive) {
                                    coordinator.isUnassignedDeletionConfirmationPresented = true
                                }
                                .disabled(coordinator.selectedUnassignedRecordIDs.isEmpty || coordinator.isWorking)
                            }
                        }
                    }
                    .padding(20)
                }

                if coordinator.sensitiveExclusionCount > 0 {
                    SurfaceCard {
                        Label("\(coordinator.sensitiveExclusionCount) sensitive files are excluded from this backup preview.", systemImage: "lock.shield")
                            .foregroundStyle(.orange)
                            .padding(20)
                    }
                }

                if let statusMessage = coordinator.statusMessage {
                    Label(statusMessage, systemImage: coordinator.isWorking ? "arrow.triangle.2.circlepath" : "checkmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(coordinator.isWorking ? Color.secondary : Color.green)
                }

                SurfaceCard {
                    HStack {
                        Label(
                            coordinator.sources.isEmpty
                                ? "Nothing selected"
                                : "\(coordinator.totalFileCount) files · \(ByteCountFormatter.string(fromByteCount: Int64(coordinator.totalBytes), countStyle: .file))",
                            systemImage: "externaldrive.badge.checkmark"
                        )
                        .font(.headline)
                        Spacer()
                        Button(coordinator.isWorking ? "Working…" : "Create verified backup") {
                            coordinator.createBackup()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(coordinator.sources.isEmpty || coordinator.destinationURL == nil || coordinator.isWorking)
                    }
                    .padding(20)
                }
            }
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .alert(
            "Backup could not be created",
            isPresented: Binding(
                get: { coordinator.errorMessage != nil },
                set: { if !$0 { coordinator.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { coordinator.errorMessage = nil }
        } message: {
            Text(coordinator.errorMessage ?? "")
        }
        .confirmationDialog(
            "Remove older complete backups?",
            isPresented: Binding(
                get: { !coordinator.pendingCompleteBackupCleanup.isEmpty },
                set: { if !$0 { coordinator.pendingCompleteBackupCleanup = [] } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove \(coordinator.pendingCompleteBackupCleanup.count) older backup(s)", role: .destructive) {
                coordinator.removeOldCompleteBackups()
            }
            Button("Keep all", role: .cancel) {
                coordinator.pendingCompleteBackupCleanup = []
            }
        } message: {
            Text("The new ZIPs and their latest copies are already verified. You decide whether dated backups beyond the newest three are removed.")
        }
        .confirmationDialog(
            "Remove selected local records?",
            isPresented: $coordinator.isUnassignedDeletionConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Remove permanently", role: .destructive) {
                coordinator.removeSelectedUnassignedRecords()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Only the selected local Codex records with no current project assignment are removed. This cannot be undone.")
        }
    }
}

private struct RestoreView: View {
    let theme: DisplayTheme
    @Bindable var coordinator: BackupCoordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Header(title: "Restore with confidence", subtitle: "Validate a backup, choose its contents, then create a new restore folder.")

                SurfaceCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Label("Backup package", systemImage: "archivebox")
                                .font(.headline)
                            Text(coordinator.restorePackageURL?.lastPathComponent ?? "No backup selected")
                                .foregroundStyle(coordinator.restorePackageURL == nil ? .secondary : .primary)
                        }
                        Spacer()
                        Button("Choose Backup") {
                            coordinator.chooseRestorePackage()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(20)
                }

                if let manifest = coordinator.restoreManifest {
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Verified contents", systemImage: "checkmark.shield")
                                .font(.headline)
                                .foregroundStyle(.green)
                            ForEach(restoreSourceIDs(in: manifest), id: \.self) { sourceID in
                                let fileCount = manifest.entries.filter { $0.sourceID == sourceID }.count
                                Button {
                                    coordinator.toggleRestoreSource(sourceID)
                                } label: {
                                    HStack {
                                        Image(systemName: coordinator.selectedRestoreSourceIDs.contains(sourceID) ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(coordinator.selectedRestoreSourceIDs.contains(sourceID) ? theme.tint : .secondary)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(restoreSourceName(sourceID, in: manifest))
                                            Text("\(fileCount) files")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(20)
                    }

                    SurfaceCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Label("Restore destination", systemImage: "folder.badge.arrow.down")
                                    .font(.headline)
                                Text(coordinator.restoreDestinationURL?.lastPathComponent ?? "No destination selected")
                                    .foregroundStyle(coordinator.restoreDestinationURL == nil ? .secondary : .primary)
                            }
                            Spacer()
                            Button(coordinator.restoreDestinationURL == nil ? "Choose destination" : "Change") {
                                coordinator.chooseRestoreDestination()
                            }
                        }
                        .padding(20)
                    }

                    SurfaceCard {
                        HStack {
                            Label("\(coordinator.selectedRestoreSourceIDs.count) sources selected", systemImage: "arrow.counterclockwise")
                                .font(.headline)
                            Spacer()
                            Button(coordinator.isWorking ? "Working…" : "Restore selected") {
                                coordinator.restoreSelected()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(coordinator.selectedRestoreSourceIDs.isEmpty || coordinator.restoreDestinationURL == nil || coordinator.isWorking)
                        }
                        .padding(20)
                    }
                }

                if let message = coordinator.restoreStatusMessage {
                    Label(message, systemImage: coordinator.isWorking ? "arrow.triangle.2.circlepath" : "checkmark.circle")
                        .foregroundStyle(coordinator.isWorking ? Color.secondary : Color.green)
                }

                SurfaceCard {
                    Label("CodexVault always restores into a new folder. Existing destination files are never replaced.", systemImage: "lock.shield")
                        .foregroundStyle(.secondary)
                        .padding(20)
                }
            }
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .alert(
            "Restore could not be completed",
            isPresented: Binding(
                get: { coordinator.errorMessage != nil },
                set: { if !$0 { coordinator.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { coordinator.errorMessage = nil }
        } message: {
            Text(coordinator.errorMessage ?? "")
        }
    }

    private func restoreSourceIDs(in manifest: ArchiveManifest) -> [String] {
        Array(Set(manifest.entries.map(\.sourceID))).sorted()
    }

    private func restoreSourceName(_ sourceID: String, in manifest: ArchiveManifest) -> String {
        manifest.sources?.first(where: { $0.sourceID == sourceID })?.archiveRootName
            ?? sourceID.replacingOccurrences(of: "-", with: " ").capitalized
    }
}

private struct ArchiveView: View {
    let theme: DisplayTheme
    let coordinator: BackupCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Header(title: "Your archive", subtitle: "Only backups you choose will be listed here.")
            SurfaceCard {
                if coordinator.archives.isEmpty {
                    ContentUnavailableView("No archive yet", systemImage: "archivebox", description: Text("Verified backup packages remain under your control and are never uploaded."))
                        .padding(60)
                } else {
                    VStack(spacing: 0) {
                        ForEach(coordinator.archives) { archive in
                            HStack(spacing: 14) {
                                Image(systemName: archive.verified ? "checkmark.shield.fill" : "exclamationmark.shield")
                                    .font(.title2)
                                    .foregroundStyle(archive.verified ? .green : .orange)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(archive.displayName)
                                        .font(.headline)
                                    Text("\(archive.fileCount) files · \(ByteCountFormatter.string(fromByteCount: Int64(archive.byteCount), countStyle: .file))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(archive.verified ? "Verified" : "Needs review")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(archive.verified ? .green : .orange)
                            }
                            .padding(20)
                        }
                    }
                }
            }
            Spacer()
        }
        .frame(maxWidth: 900, maxHeight: .infinity, alignment: .top)
    }
}

private struct SettingsView: View {
    @Binding var selectedTheme: DisplayTheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Settings")
                    .font(.system(size: 40, weight: .bold))

                settingsSection(title: "Appearance") {
                Picker("Preview theme", selection: $selectedTheme) {
                    ForEach(DisplayTheme.allCases) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                Text("This only changes appearance. It never changes selected sources, backup contents, or security decisions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                settingsSection(title: "Privacy") {
                    LabeledContent("Network activity", value: "Disabled")
                    LabeledContent("Stored private content", value: "None")
                    Text("Backup and restore permissions will always be requested explicitly.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                settingsSection(title: "Build channel") {
                    LabeledContent("Current channel", value: BuildChannel.current.displayName)
                    Text("Dev, Beta, and Final use separate bundle identifiers and sandbox containers. No channel migrates data into another.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private func settingsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            SurfaceCard {
                VStack(alignment: .leading, spacing: 12) {
                    content()
                }
                .padding(18)
            }
        }
    }
}

private struct Header: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 40, weight: .bold))
            Text(subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }
}

private struct MetricCard: View {
    let icon: String
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(tint)
                    .frame(width: 42, height: 42)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                Text(title)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title2.bold())
                    .lineLimit(1)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ModuleRow: View {
    @Environment(\.archiveAtlasFullGlass) private var usesFullGlass
    @Environment(\.archiveAtlasSidebarOnlyGlass) private var usesSidebarOnlyGlass
    let title: String
    let icon: String
    let subtitle: String
    let selected: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(selected ? tint : .secondary)
                    .frame(width: 44, height: 44)
                    .background((selected ? tint : .secondary).opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(selected ? tint : .secondary)
            }
            .padding(18)
        }
        .buttonStyle(.plain)
        .background {
            if usesFullGlass {
                RoundedRectangle(cornerRadius: 18).fill(.ultraThinMaterial)
            } else if usesSidebarOnlyGlass {
                RoundedRectangle(cornerRadius: 18).fill(Color(nsColor: .controlBackgroundColor))
            } else {
                RoundedRectangle(cornerRadius: 18).fill(.regularMaterial)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(selected ? tint.opacity(0.8) : .primary.opacity(0.10), lineWidth: selected ? 2 : 1)
        }
    }
}

private struct SurfaceCard<Content: View>: View {
    @Environment(\.archiveAtlasFullGlass) private var usesFullGlass
    @Environment(\.archiveAtlasSidebarOnlyGlass) private var usesSidebarOnlyGlass
    @ViewBuilder let content: Content

    var body: some View {
        content
            .background {
                if usesFullGlass {
                    RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial)
                } else if usesSidebarOnlyGlass {
                    RoundedRectangle(cornerRadius: 20).fill(Color(nsColor: .controlBackgroundColor))
                } else {
                    RoundedRectangle(cornerRadius: 20).fill(.regularMaterial)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(usesFullGlass ? .white.opacity(0.34) : .primary.opacity(0.10), lineWidth: 1)
            }
    }
}

private struct FullGlassBackdrop: NSViewRepresentable {
    func makeNSView(context: Context) -> FullGlassBackdropView {
        FullGlassBackdropView()
    }

    func updateNSView(_ view: FullGlassBackdropView, context: Context) { }
}

private struct NativeGlassPanel<Content: View>: NSViewRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeNSView(context: Context) -> NativeGlassPanelView<Content> {
        let view = NativeGlassPanelView<Content>()
        view.setRootView(content)
        return view
    }

    func updateNSView(_ view: NativeGlassPanelView<Content>, context: Context) {
        view.setRootView(content)
    }
}

private final class NativeGlassPanelView<Content: View>: NSVisualEffectView {
    private var hostingView: NSHostingView<Content>?
    private let tintLayer = CAGradientLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureMaterial()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureMaterial()
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        tintLayer.frame = bounds
        CATransaction.commit()
    }

    func setRootView(_ rootView: Content) {
        if let hostingView {
            hostingView.rootView = rootView
            return
        }

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        self.hostingView = hostingView
    }

    private func configureMaterial() {
        material = .sidebar
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        tintLayer.startPoint = CGPoint(x: 0, y: 0)
        tintLayer.endPoint = CGPoint(x: 1, y: 1)
        tintLayer.colors = [
            NSColor.white.withAlphaComponent(0.22).cgColor,
            NSColor.systemBlue.withAlphaComponent(0.16).cgColor,
            NSColor.white.withAlphaComponent(0.10).cgColor
        ]
        if tintLayer.superlayer == nil {
            layer?.insertSublayer(tintLayer, at: 0)
        }
    }
}

private final class FullGlassBackdropView: NSVisualEffectView {
    private let glowLayer = CAGradientLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        glowLayer.frame = bounds.insetBy(dx: -240, dy: -240)
        CATransaction.commit()
    }

    private func configure() {
        material = .sidebar
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.masksToBounds = true
        glowLayer.startPoint = CGPoint(x: 0, y: 0.15)
        glowLayer.endPoint = CGPoint(x: 1, y: 0.85)
        glowLayer.colors = [
            NSColor.systemTeal.withAlphaComponent(0.24).cgColor,
            NSColor.systemCyan.withAlphaComponent(0.34).cgColor,
            NSColor.systemBlue.withAlphaComponent(0.26).cgColor,
            NSColor.systemIndigo.withAlphaComponent(0.20).cgColor
        ]
        layer?.insertSublayer(glowLayer, at: 0)
    }
}
