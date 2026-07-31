import AppKit
import SwiftUI

@main
struct CodexVaultApp: App {
    var body: some Scene {
        WindowGroup {
            CodexVaultRootView()
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
        case .overview: CodexVaultLocalization.text("Overview")
        case .backup: CodexVaultLocalization.text("Backup")
        case .restore: CodexVaultLocalization.text("Restore")
        case .archive: CodexVaultLocalization.text("Archive")
        case .settings: CodexVaultLocalization.text("Settings")
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

private struct CodexVaultFullGlassKey: EnvironmentKey {
    static let defaultValue = false
}

private struct CodexVaultSidebarOnlyGlassKey: EnvironmentKey {
    static let defaultValue = false
}

private extension EnvironmentValues {
    var codexVaultFullGlass: Bool {
        get { self[CodexVaultFullGlassKey.self] }
        set { self[CodexVaultFullGlassKey.self] = newValue }
    }

    var codexVaultSidebarOnlyGlass: Bool {
        get { self[CodexVaultSidebarOnlyGlassKey.self] }
        set { self[CodexVaultSidebarOnlyGlassKey.self] = newValue }
    }
}

private struct CodexVaultRootView: View {
    @State private var selectedSection: AppSection? = .overview
    @State private var selectedTheme: DisplayTheme = .liquidGlass
    @State private var backupCoordinator = BackupCoordinator()
    @AppStorage(CodexVaultLanguage.storageKey) private var selectedLanguageRaw = CodexVaultLanguage.english.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var selectedLanguage: CodexVaultLanguage {
        CodexVaultLanguage(rawValue: selectedLanguageRaw) ?? .english
    }

    var body: some View {
        ZStack {
            if selectedTheme == .fullGlass {
                FullGlassBackdrop(isAnimated: fullGlassAnimationEnabled)
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
                    .environment(\.codexVaultFullGlass, selectedTheme == .fullGlass)
                    .environment(\.codexVaultSidebarOnlyGlass, selectedTheme == .liquidGlass)
            }
        }
        .tint(selectedTheme.tint)
        .environment(\.locale, selectedLanguage.locale)
    }

    @ViewBuilder
    private var sidebar: some View {
        if selectedTheme == .liquidGlass {
            NativeGlassPanel {
                CodexVaultSidebar(selection: $selectedSection, theme: selectedTheme)
            }
        } else if selectedTheme == .fullGlass {
            CodexVaultSidebar(selection: $selectedSection, theme: selectedTheme)
        } else {
            CodexVaultSidebar(selection: $selectedSection, theme: selectedTheme)
                .background(.regularMaterial)
        }
    }

    private var fullGlassAnimationEnabled: Bool {
        !reduceMotion && !backupCoordinator.isWorking && !backupCoordinator.isAnalyzingSessions
    }

    @ViewBuilder
    private var detail: some View {
        switch selectedSection ?? .overview {
        case .overview:
            if backupCoordinator.hasOwnContent {
                OverviewView(theme: selectedTheme, archives: backupCoordinator.archives) {
                    selectedSection = .backup
                }
            } else {
                CodexVaultFirstStartView(theme: selectedTheme) {
                    selectedSection = .backup
                }
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

private struct CodexVaultFirstStartView: View {
    let theme: DisplayTheme
    let onStartSetup: () -> Void

    @State private var pendingAIService: CodexVaultAIHelpService?

    private var language: CodexVaultLanguage {
        CodexVaultLanguage.current
    }

    private var title: String {
        language == .german ? "Willkommen bei CodexVault" : "Welcome to CodexVault"
    }

    private var introduction: String {
        language == .german
            ? "CodexVault sichert ausgewählte Ordner lokal und stellt sie geprüft wieder her. Beginne mit einer eigenen Auswahl - nichts wird automatisch hochgeladen oder gesichert."
            : "CodexVault backs up selected folders locally and restores them after verification. Start with your own selection - nothing is uploaded or backed up automatically."
    }

    private var startTitle: String {
        language == .german ? "Backup einrichten" : "Set up backup"
    }

    private var manualTitle: String {
        language == .german ? "Handbuch öffnen" : "Open manual"
    }

    private var privacyText: String {
        language == .german
            ? "Es wird nur eine allgemeine Frage in die Zwischenablage kopiert. CodexVault sendet keine persönlichen Daten automatisch an einen KI-Dienst."
            : "Only a general question is copied to the clipboard. CodexVault never sends personal data to an AI service automatically."
    }

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "archivebox.fill")
                .font(.system(size: 60))
                .foregroundStyle(theme.tint)
                .frame(width: 100, height: 100)
                .background(theme.tint.opacity(0.14), in: Circle())

            Text(title)
                .font(.largeTitle.bold())

            Text(introduction)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 620)

            Button(action: onStartSetup) {
                Label(startTitle, systemImage: "folder.badge.plus")
            }
            .buttonStyle(.borderedProminent)

            Divider()
                .frame(maxWidth: 620)
                .padding(.vertical, 4)

            Text(language == .german ? "KI-Hilfe zum Einstieg" : "AI help for getting started")
                .font(.headline)
            Text(language == .german
                 ? "Wähle einen Dienst. Die vorbereitete Frage wird kopiert; füge sie dort selbst mit ⌘V ein."
                 : "Choose a service. The prepared question is copied; paste it there yourself with ⌘V.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button {
                    NSWorkspace.shared.open(CodexVaultHelpLinks.manualURL(for: language))
                } label: {
                    Label(manualTitle, systemImage: "book")
                }
                .buttonStyle(.bordered)

                ForEach(CodexVaultAIHelpService.allCases) { service in
                    Button {
                        pendingAIService = service
                    } label: {
                        HStack(spacing: 7) {
                            Image(nsImage: codexVaultAIHelpLogo(for: service))
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                                .accessibilityHidden(true)
                            Text(service.title)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }

            Label(privacyText, systemImage: "hand.raised.fill")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 620, alignment: .leading)
                .padding(.top, 6)
        }
        .padding(34)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert(item: $pendingAIService) { service in
            Alert(
                title: Text(language == .german ? "\(service.title) öffnen" : "Open \(service.title)"),
                message: Text(
                    language == .german
                        ? "CodexVault kopiert eine vorbereitete allgemeine Frage und öffnet \(service.title). Füge die Frage dort selbst mit ⌘V ein."
                        : "CodexVault copies a prepared general question and opens \(service.title). Paste the question there yourself with ⌘V."
                ),
                primaryButton: .default(Text(language == .german ? "Kopieren und öffnen" : "Copy and open")) {
                    copyPromptAndOpen(service)
                },
                secondaryButton: .cancel(Text(language == .german ? "Abbrechen" : "Cancel"))
            )
        }
    }

    private func copyPromptAndOpen(_ service: CodexVaultAIHelpService) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(
            CodexVaultHelpLinks.aiPrompt(for: language),
            forType: .string
        )
        NSWorkspace.shared.open(service.url)
    }
}

private struct CodexVaultSidebar: View {
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
                Spacer(minLength: 4)
                CommunityLinkButton(
                    title: "Discord",
                    assetName: "discord-mark-white",
                    url: CodexVaultCommunityLinks.discord
                )
                CommunityLinkButton(
                    title: "GitHub",
                    assetName: "github-invertocat",
                    url: CodexVaultCommunityLinks.github
                )
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

private enum CodexVaultCommunityLinks {
    static let github = URL(string: "https://github.com/Schrotty74/CodexVault")!
    static let discord = URL(string: "https://discord.gg/RbsvqRCPQ")!
}

private struct CommunityLinkButton: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let assetName: String
    let url: URL

    private var isDiscord: Bool { assetName == "discord-mark-white" }

    private var imageName: String {
        isDiscord ? assetName : "\(assetName)-\(colorScheme == .dark ? "black" : "white")"
    }

    var body: some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isDiscord
                          ? Color(red: 0.35, green: 0.40, blue: 0.95)
                          : (colorScheme == .dark ? Color.white.opacity(0.96) : Color.black.opacity(0.88)))
                Image(nsImage: codexVaultCommunityLogo(named: imageName))
                    .resizable()
                    .scaledToFit()
                    .padding(isDiscord ? 5 : 5.5)
                    .accessibilityHidden(true)
            }
            .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
    }
}

private func codexVaultCommunityLogo(named name: String) -> NSImage {
    guard let url = CodexVaultResources.bundle.url(forResource: name, withExtension: "svg"),
          let image = NSImage(contentsOf: url) else {
        return NSImage()
    }
    return image
}

private struct OverviewView: View {
    let theme: DisplayTheme
    let archives: [ArchiveSummary]
    let onStartSetup: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Header(title: CodexVaultLocalization.text("Your workspace, protected."), subtitle: CodexVaultLocalization.text("CodexVault is ready when you are."))

                HStack(spacing: 16) {
                    MetricCard(icon: "clock.arrow.circlepath", title: CodexVaultLocalization.text("Last backup"), value: CodexVaultLocalization.text("Not created"), tint: theme.tint)
                    MetricCard(icon: "shield", title: CodexVaultLocalization.text("Protected"), value: CodexVaultLocalization.text("No sources"), tint: theme.tint)
                    MetricCard(icon: "externaldrive", title: CodexVaultLocalization.text("Storage"), value: "0 bytes", tint: theme.tint)
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

                CodexVaultAIHelpCard()

                if !archives.isEmpty {
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Activity", systemImage: "list.bullet.rectangle")
                                .font(.headline)
                            Divider()
                            ForEach(archives.prefix(3)) { archive in
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(archive.displayName)
                                            .font(.subheadline.weight(.medium))
                                        Text(archive.verified ? "Verified backup" : "Backup needs verification")
                                            .font(.caption)
                                            .foregroundStyle(archive.verified ? .green : .secondary)
                                    }
                                    Spacer()
                                    Text(ByteCountFormatter.string(fromByteCount: Int64(archive.byteCount), countStyle: .file))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(20)
                    }
                }

            }
            .frame(maxWidth: 1_120, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

private struct CodexVaultAIHelpCard: View {
    @State private var pendingAIService: CodexVaultAIHelpService?

    private var language: CodexVaultLanguage { CodexVaultLanguage.current }

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Label(language == .german ? "KI-Hilfe" : "AI help", systemImage: "sparkles")
                    .font(.headline)
                Text(language == .german
                     ? "Allgemeine Einstiegsfrage kopieren und bei Bedarf selbst in einen KI-Dienst einfügen."
                     : "Copy a general getting-started question and paste it into an AI service yourself when needed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button {
                        NSWorkspace.shared.open(CodexVaultHelpLinks.manualURL(for: language))
                    } label: {
                        Label(language == .german ? "Handbuch öffnen" : "Open manual", systemImage: "book")
                    }
                    .buttonStyle(.bordered)

                    ForEach(CodexVaultAIHelpService.allCases) { service in
                        Button {
                            pendingAIService = service
                        } label: {
                            HStack(spacing: 7) {
                                Image(nsImage: codexVaultAIHelpLogo(for: service))
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 18, height: 18)
                                    .accessibilityHidden(true)
                                Text(service.title)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(20)
        }
        .alert(item: $pendingAIService) { service in
            Alert(
                title: Text(language == .german ? "\(service.title) öffnen" : "Open \(service.title)"),
                message: Text(language == .german
                              ? "CodexVault kopiert eine vorbereitete allgemeine Frage und öffnet \(service.title). Füge die Frage dort selbst mit ⌘V ein."
                              : "CodexVault copies a prepared general question and opens \(service.title). Paste the question there yourself with ⌘V."),
                primaryButton: .default(Text(language == .german ? "Kopieren und öffnen" : "Copy and open")) {
                    copyPromptAndOpen(service)
                },
                secondaryButton: .cancel(Text(language == .german ? "Abbrechen" : "Cancel"))
            )
        }
    }

    private func copyPromptAndOpen(_ service: CodexVaultAIHelpService) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(CodexVaultHelpLinks.aiPrompt(for: language), forType: .string)
        NSWorkspace.shared.open(service.url)
    }
}

private struct BackupView: View {
    let theme: DisplayTheme
    @Bindable var coordinator: BackupCoordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Header(title: CodexVaultLocalization.text("Create a backup"), subtitle: CodexVaultLocalization.text("Choose exactly what you want to protect."))

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
                            Button("Import ChatGPT export") {
                                coordinator.chooseChatGPTExport()
                            }
                        }

                        if coordinator.sources.isEmpty {
                            Text("No folders selected. CodexVault reads only folders you explicitly choose.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(coordinator.sources) { source in
                                HStack(spacing: 12) {
                                    Image(systemName: source.kind == .project ? "folder.fill" : (source.kind == .chatGPTExport ? "bubble.left.and.bubble.right" : "folder"))
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
                        Toggle("Encrypt this backup with a password", isOn: $coordinator.encryptNormalBackup)
                        if coordinator.encryptNormalBackup {
                            SecureField("Backup password", text: $coordinator.normalBackupPassword)
                            Text("The password is not stored. Keep it safe: encrypted packages cannot be opened without it.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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
                                Label("Visible Codex workspace", systemImage: "folder.badge.gearshape")
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Text("Detected during backup if available")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Project folders (\(coordinator.fullBackupProjectRoots.count))", systemImage: "folder")
                                    .font(.subheadline.weight(.medium))
                                if coordinator.fullBackupProjectRoots.isEmpty {
                                    Text("None configured. Add one or more project folders.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    ForEach(coordinator.fullBackupProjectRoots, id: \.self) { root in
                                        HStack(spacing: 8) {
                                            Image(systemName: "folder.fill")
                                                .foregroundStyle(.blue)
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(root.lastPathComponent)
                                                    .font(.caption.weight(.medium))
                                                Text(root.path)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                                    .truncationMode(.middle)
                                            }
                                            Spacer(minLength: 8)
                                            Button("Remove", role: .destructive) {
                                                coordinator.removeFullBackupProjectRoot(root)
                                            }
                                            .controlSize(.small)
                                        }
                                    }
                                }
                            }
                            if coordinator.isDiscoveringProjects {
                                HStack(spacing: 8) {
                                    ProgressView()
                                    Text("Searching selected folder locally…")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } else if !coordinator.discoveredProjectCandidates.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Suggested projects")
                                        .font(.subheadline.weight(.medium))
                                    Text("These are local suggestions based on project files. Select only folders you want in every full backup.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    ForEach(coordinator.discoveredProjectCandidates) { candidate in
                                        Button {
                                            coordinator.toggleDiscoveredProject(candidate)
                                        } label: {
                                            HStack(spacing: 8) {
                                                Image(systemName: coordinator.selectedDiscoveredProjectURLs.contains(candidate.url) ? "checkmark.square.fill" : "square")
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(candidate.displayName)
                                                        .font(.caption.weight(.medium))
                                                    Text(candidate.signals.joined(separator: " · "))
                                                        .font(.caption2)
                                                        .foregroundStyle(.secondary)
                                                }
                                                Spacer()
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    Button("Add selected projects") {
                                        coordinator.addSelectedDiscoveredProjects()
                                    }
                                    .disabled(coordinator.selectedDiscoveredProjectURLs.isEmpty)
                                }
                            }
                        }
                        HStack {
                            Button("Add project folders") {
                                coordinator.addFullBackupProjectRoots()
                            }
                            Button("Search projects") {
                                coordinator.chooseProjectDiscoveryScope()
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
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Automatic full backups while CodexVault is open", isOn: Binding(
                                get: { coordinator.automaticFullBackupEnabled },
                                set: {
                                    coordinator.automaticFullBackupEnabled = $0
                                    coordinator.saveAutomaticBackupSettings()
                                }
                            ))
                            if coordinator.automaticFullBackupEnabled {
                                Picker("Frequency", selection: Binding(
                                    get: { coordinator.automaticFullBackupInterval },
                                    set: {
                                        coordinator.automaticFullBackupInterval = $0
                                        coordinator.saveAutomaticBackupSettings()
                                    }
                                )) {
                                    ForEach(FullBackupScheduleInterval.allCases) { interval in
                                        Text(interval.title).tag(interval)
                                    }
                                }
                                .pickerStyle(.segmented)
                                Text("CodexVault checks once per minute while it is open. It waits until the Codex desktop app is closed; it never launches in the background.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        HStack {
                            Button(coordinator.isWorking ? "Working…" : "Create complete ZIP backup") {
                                coordinator.requestCompleteBackup()
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
        .confirmationDialog(
            "Close the Codex desktop app before the full backup",
            isPresented: $coordinator.isFullBackupStartConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Codex is closed - start backup") {
                coordinator.createCompleteBackup()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Keep CodexVault open. Close only the separate Codex desktop app first so its local data is not being written during the backup. Then return here and start the backup.")
        }
    }
}

private struct RestoreView: View {
    let theme: DisplayTheme
    @Bindable var coordinator: BackupCoordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Header(title: CodexVaultLocalization.text("Restore with confidence"), subtitle: CodexVaultLocalization.text("Validate a backup, choose its contents, then create a new restore folder."))

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

                if coordinator.restoreRequiresPassword, coordinator.restoreManifest == nil {
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Encrypted backup", systemImage: "lock.fill")
                                .font(.headline)
                            SecureField("Backup password", text: $coordinator.restorePassword)
                            Button("Unlock and validate") {
                                coordinator.validateEncryptedRestore()
                            }
                            .disabled(coordinator.restorePassword.isEmpty || coordinator.isWorking)
                        }
                        .padding(20)
                    }
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
            Header(title: CodexVaultLocalization.text("Your archive"), subtitle: CodexVaultLocalization.text("Only backups you choose will be listed here."))
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
    @AppStorage(CodexVaultLanguage.storageKey) private var selectedLanguageRaw = CodexVaultLanguage.english.rawValue

    private var isGerman: Bool {
        CodexVaultLanguage.current == .german
    }

    private var selectedLanguage: Binding<CodexVaultLanguage> {
        Binding(
            get: { CodexVaultLanguage(rawValue: selectedLanguageRaw) ?? .english },
            set: { selectedLanguageRaw = $0.rawValue }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Settings")
                    .font(.system(size: 40, weight: .bold))

                settingsSection(title: "Language") {
                    Picker("App language", selection: selectedLanguage) {
                        ForEach(CodexVaultLanguage.allCases) { language in
                            Text(language.title).tag(language)
                        }
                    }
                    Text("English is the default. The selected language also controls the AI-help prompt and manual link.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

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
                    LabeledContent(isGerman ? "Automatische Netzwerkaktivität" : "Automatic network activity", value: isGerman ? "Deaktiviert" : "Disabled")
                    LabeledContent(isGerman ? "Externe Links" : "External links", value: isGerman ? "Nur nach Klick" : "Only after click")
                    LabeledContent(isGerman ? "Gespeicherte private Inhalte" : "Stored private content", value: isGerman ? "Keine" : "None")
                    Text(isGerman
                         ? "Backup- und Wiederherstellungsberechtigungen werden immer ausdrücklich angefordert."
                         : "Backup and restore permissions will always be requested explicitly.")
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
    @Environment(\.codexVaultFullGlass) private var usesFullGlass
    @Environment(\.codexVaultSidebarOnlyGlass) private var usesSidebarOnlyGlass
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
    @Environment(\.codexVaultFullGlass) private var usesFullGlass
    @Environment(\.codexVaultSidebarOnlyGlass) private var usesSidebarOnlyGlass
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
    let isAnimated: Bool

    func makeNSView(context: Context) -> FullGlassBackdropView {
        let view = FullGlassBackdropView()
        view.setAnimated(isAnimated)
        return view
    }

    func updateNSView(_ view: FullGlassBackdropView, context: Context) {
        view.setAnimated(isAnimated)
    }
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
    private let sparkLayer = CALayer()
    private var sparkTimer: Timer?
    private var isAnimated = false

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
        let horizontalInset = max(bounds.width * 0.9, 420)
        let verticalInset = max(bounds.height * 0.9, 420)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        glowLayer.frame = bounds.insetBy(dx: -horizontalInset, dy: -verticalInset)
        sparkLayer.frame = bounds
        CATransaction.commit()
        updateGlowAnimation()
        if isAnimated, sparkTimer == nil, sparkLayer.sublayers?.isEmpty != false {
            updateSparks()
        }
    }

    func setAnimated(_ animated: Bool) {
        guard isAnimated != animated else { return }
        isAnimated = animated
        updateGlowAnimation()
        updateSparks()
    }

    private func configure() {
        material = .sidebar
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.masksToBounds = true
        glowLayer.startPoint = CGPoint(x: 0, y: 0.08)
        glowLayer.endPoint = CGPoint(x: 1, y: 0.92)
        glowLayer.locations = [0, 0.16, 0.36, 0.58, 0.80, 1]
        glowLayer.colors = [
            NSColor.clear.cgColor,
            NSColor.systemCyan.withAlphaComponent(0.24).cgColor,
            NSColor.systemBlue.withAlphaComponent(0.27).cgColor,
            NSColor.systemPurple.withAlphaComponent(0.21).cgColor,
            NSColor.systemPink.withAlphaComponent(0.13).cgColor,
            NSColor.clear.cgColor
        ]
        layer?.insertSublayer(glowLayer, at: 0)
        layer?.insertSublayer(sparkLayer, above: glowLayer)
    }

    private func updateGlowAnimation() {
        glowLayer.removeAnimation(forKey: "fullGlassDiagonalGlow")
        glowLayer.opacity = isAnimated ? 0.72 : 0.33

        guard isAnimated, bounds.width > 0, bounds.height > 0 else { return }

        let travel = CABasicAnimation(keyPath: "transform.translation")
        travel.fromValue = NSValue(size: CGSize(width: -bounds.width * 0.18, height: -bounds.height * 0.16))
        travel.toValue = NSValue(size: CGSize(width: bounds.width * 0.18, height: bounds.height * 0.16))
        travel.duration = 38
        travel.repeatCount = .infinity
        travel.timingFunction = CAMediaTimingFunction(name: .linear)
        glowLayer.add(travel, forKey: "fullGlassDiagonalGlow")
    }

    private func updateSparks() {
        sparkTimer?.invalidate()
        sparkTimer = nil
        sparkLayer.sublayers?.forEach { $0.removeFromSuperlayer() }

        guard isAnimated, bounds.width > 0, bounds.height > 0 else { return }

        scheduleNextSpark(after: Double.random(in: 0.08...0.30))
    }

    private func scheduleNextSpark(after delay: TimeInterval) {
        guard isAnimated else { return }
        sparkTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isAnimated else { return }
                self.addSpark()
                self.scheduleNextSpark(after: Double.random(in: 0.12...0.48))
            }
        }
    }

    private func addSpark() {
        guard bounds.width > 0, bounds.height > 0 else { return }

        let colors: [NSColor] = [
            .systemCyan,
            .systemTeal,
            .systemBlue,
            .systemPurple,
            .systemPink,
            .systemYellow
        ]
        let spark = CAShapeLayer()
        let size = CGFloat.random(in: 4.0...9.0)
        let color = colors.randomElement()!.withAlphaComponent(CGFloat.random(in: 0.60...0.92))
        let start = CGPoint(
            x: CGFloat.random(in: bounds.width * 0.025...bounds.width * 0.975),
            y: CGFloat.random(in: bounds.height * 0.035...bounds.height * 0.965)
        )
        let drift = CGPoint(x: CGFloat.random(in: -16...16), y: CGFloat.random(in: -12...12))
        let duration = Double.random(in: 1.6...3.8)

        spark.path = CGPath(ellipseIn: CGRect(x: -size / 2, y: -size / 2, width: size, height: size), transform: nil)
        spark.fillColor = color.cgColor
        spark.shadowColor = color.cgColor
        spark.shadowRadius = CGFloat.random(in: 9...18)
        spark.shadowOpacity = 0.9
        spark.opacity = 0
        spark.position = start
        sparkLayer.addSublayer(spark)

        let movement = CABasicAnimation(keyPath: "position")
        movement.fromValue = NSValue(point: start)
        movement.toValue = NSValue(point: CGPoint(x: start.x + drift.x, y: start.y + drift.y))
        movement.duration = duration
        movement.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [0, 0.9, 0.32, 0]
        fade.keyTimes = [0, 0.22, 0.58, 1]
        fade.duration = duration
        fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [0.35, 1.15, 0.72, 0.25]
        scale.keyTimes = [0, 0.22, 0.62, 1]
        scale.duration = duration

        let group = CAAnimationGroup()
        group.animations = [movement, fade, scale]
        group.duration = duration
        group.isRemovedOnCompletion = true
        spark.add(group, forKey: "fullGlassSpark")
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak spark] in
            spark?.removeFromSuperlayer()
        }
    }
}
