import AppKit
import Foundation

enum CodexVaultLanguage: String, CaseIterable, Identifiable, Sendable {
    case english
    case german

    static let storageKey = "codexVault.appLanguage"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .english: "English"
        case .german: "Deutsch"
        }
    }

    var locale: Locale {
        Locale(identifier: self == .german ? "de" : "en")
    }

    static var current: Self {
        Self(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .english
    }
}

enum CodexVaultAIHelpService: String, CaseIterable, Identifiable, Sendable {
    case chatGPT
    case gemini
    case claude

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chatGPT: "ChatGPT"
        case .gemini: "Google Gemini"
        case .claude: "Claude"
        }
    }

    var logoResource: (name: String, fileExtension: String) {
        switch self {
        case .chatGPT: ("ai-chatgpt-logo", "jpg")
        case .gemini: ("ai-gemini-logo", "svg")
        case .claude: ("ai-claude-logo", "png")
        }
    }

    var url: URL {
        switch self {
        case .chatGPT: URL(string: "https://chatgpt.com/")!
        case .gemini: URL(string: "https://gemini.google.com/app")!
        case .claude: URL(string: "https://claude.ai/new")!
        }
    }
}

enum CodexVaultHelpLinks {
    static func manualURL(for language: CodexVaultLanguage) -> URL {
        let filename = switch language {
        case .german: "CodexVault-Handbuch-DE.pdf"
        case .english: "CodexVault-Manual-EN.pdf"
        }
        return URL(string: "https://github.com/Schrotty74/CodexVault/blob/main/docs/\(filename)")!
    }

    static func aiPrompt(for language: CodexVaultLanguage) -> String {
        let manualURL = manualURL(for: language).absoluteString
        return switch language {
        case .german:
            """
            Ich habe CodexVault gerade zum ersten Mal geöffnet. Erkläre mir die App freundlich und in einfacher Sprache. Führe mich Schritt für Schritt durch den ersten sinnvollen Start. Erkläre die wichtigsten Funktionen, wo ich sie in der App finde und wann sie sinnvoll sind. Frage mich am Ende, wobei ich Hilfe benötige. Verwende dieses offizielle Handbuch:
            \(manualURL)

            Wichtige, verbindliche Tatsachen zu CodexVault: Es ist eine lokale macOS-App für geprüfte Backups und Wiederherstellungen von ausgewählten Ordnern und Codex-bezogenen Daten. Die Bereiche heißen Overview, Backup, Restore, Archive und Settings. Normale Backups sichern ausdrücklich ausgewählte Ordner in ein geprüftes `.codexvault`-Paket. Full Backups erstellen lokale ZIP-Dateien der Codex-Daten und konfigurierter Projektordner. Die App lädt keine Daten hoch und startet keine Backups automatisch.

            Erfinde keine Funktionen oder Bedienelemente. Insbesondere gibt es keine Vaults oder Tresore, keine Snippets, Tags, Code-Editoren, Syntax-Highlighting oder globale Snippet-Suche. Wenn das Handbuch nicht erreichbar ist, halte dich nur an die genannten Tatsachen.
            """
        case .english:
            """
            I have just opened CodexVault for the first time. Explain the app to me in a friendly, simple way. Guide me step by step through the first useful start. Explain the most important features, where to find them in the app, and when they are useful. At the end, ask what I need help with. Use this official manual:
            \(manualURL)

            Important, confirmed facts about CodexVault: it is a local macOS app for verified backups and restores of selected folders and Codex-related data. Its sections are Overview, Backup, Restore, Archive, and Settings. Normal backups package explicitly selected folders in a verified `.codexvault` package. Full backups create local ZIP files for Codex data and configured project folders. The app does not upload data or start backups automatically.

            Do not invent features or controls. In particular, CodexVault has no vaults, snippets, tags, code editor, syntax highlighting, or global snippet search. If the manual is unavailable, use only the confirmed facts above.
            """
        }
    }
}

enum CodexVaultResources {
    static var bundle: Bundle {
        if let resourceURL = Bundle.main.resourceURL,
           let bundle = Bundle(url: resourceURL.appendingPathComponent("CodexVault_CodexVaultApp.bundle", isDirectory: true)) {
            return bundle
        }
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        return Bundle.main
        #endif
    }
}

enum CodexVaultLocalization {
    static func text(_ key: String) -> String {
        let language = CodexVaultLanguage.current == .german ? "de" : "en"
        guard let path = CodexVaultResources.bundle.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return key
        }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
}

func codexVaultAIHelpLogo(for service: CodexVaultAIHelpService) -> NSImage {
    let resource = service.logoResource
    guard let url = CodexVaultResources.bundle.url(
        forResource: resource.name,
        withExtension: resource.fileExtension
    ), let image = NSImage(contentsOf: url) else {
        return NSImage()
    }
    return image
}
