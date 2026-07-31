# CodexVault – Projektkontext

Stand: 31. Juli 2026
Status: Öffentlicher Quellcode-Upload und erste Beta-Veröffentlichung `v1.0.0-beta.1` erfolgt. Es gibt noch keine Final-Veröffentlichung.

## Zuerst lesen

1. Diese Datei – aktuelle technische und fachliche Grundlage.
2. [NEXT_STEPS.md](NEXT_STEPS.md) – nur die tatsächlich noch offenen Arbeiten.
3. [README.md](README.md) – kurze Startanleitung.
4. [PHASE_0_DISCOVERY.md](PHASE_0_DISCOVERY.md) – historische Bestandsaufnahme; bei Abweichungen hat diese Datei keinen Vorrang.
5. Vor einer Beta- oder Final-Veröffentlichung zusätzlich [docs/RELEASE_PRIVACY_REPORT_TEMPLATE.md](docs/RELEASE_PRIVACY_REPORT_TEMPLATE.md) lesen und einen konkreten Bericht daraus erstellen.

Öffentliche Nutzerdokumentation liegt zweisprachig in `README.md`, `README.de.md`, `docs/CodexVault-Manual-EN.pdf` und `docs/CodexVault-Handbuch-DE.pdf`. Die PDF-Handbücher werden mit `Scripts/generate-manual-pdfs.py` aus den Textquellen unter `Scripts/ManualSources/` erzeugt. Bei jeder sichtbaren Funktions- oder Einstellungsänderung müssen die Feature-Listen, die passenden Handbuchquellen und die daraus erzeugten PDFs im selben Auftrag aktualisiert werden.

Bei einer inhaltlichen Änderung an Funktionen, Datenformaten, Build-Abläufen oder offenen Punkten sind diese Datei und `NEXT_STEPS.md` im selben Arbeitsauftrag zu aktualisieren.

## Zweck

CodexVault ist eine lokale macOS-App zur Sicherung und Wiederherstellung von Arbeitsordnern und Codex-bezogenen Daten. Sie führt keine automatische Netzwerkkommunikation aus. Öffentliche GitHub-, Discord-, Handbuch- und KI-Dienstseiten werden ausschließlich nach einem sichtbaren Klick geöffnet. Nutzende wählen bei normalen Backups Quellen und Ziel selbst; vollständige Backups verwenden einmal pro macOS-Benutzer eingerichtete Projektordner und ein Ziel.

## Architektur und wichtige Ordner

| Bereich | Aufgabe |
| --- | --- |
| `Sources/CodexVaultApp/CodexVaultApp.swift` | SwiftUI-App, Navigation, Ansichten, Sprachwahl, öffentliche Community-Links und die vier Darstellungsvarianten einschließlich Full-Glass-Animation. |
| `Sources/CodexVaultApp/BackupCoordinator.swift` | UI-Zustand, Dateiauswahl, asynchrone Abläufe und lokal gespeicherte Full-Backup-Einstellungen. |
| `Sources/CodexVaultApp/BackupEngine.swift` | Vorschau, Erstellen, Prüfen und Wiederherstellen normaler Backups; ZIP-Backups; Speicheranalyse lokaler Codex-Daten. |
| `Sources/CodexVaultApp/BackupDomain.swift` | Datenmodelle und Fehlerfälle. |
| `Sources/CodexVaultApp/BuildChannel.swift` | Ermittelt den lokalen Build-Kanal aus dem App-Bundle. |
| `Sources/CodexVaultApp/AIHelp.swift` | Sprachwahl mit Englisch als Standard, lokale Erststart-KI-Hilfe, sprachabhängige öffentliche Handbuch-Links, datensparsame Prompts und lokale Logo-Ressourcen. |
| `Sources/CodexVaultApp/Resources/` | Unveränderte, lokal eingebundene offizielle Logos für ChatGPT, Google Gemini, Claude, GitHub und Discord. |
| `Tests/CodexVaultAppTests/` | Automatisierte Tests für Backup-Ausschlüsse, Verifikation und ZIP-Inhalte. |
| `Scripts/` | Lokale Builds für Dev, Beta und Final sowie die lokale Verpackung von Beta-/Final-DMG und -ZIP. Keines der Skripte veröffentlicht etwas. |
| `Packaging/` | Bundle-Vorlage und Signaturkonfiguration für die lokalen App-Bundles. |
| `Assets/AppIcon/` | Quellbilder und die von Icon Composer erzeugte `CodexVault.icon`-Ressource für das macOS-26-App-Icon. Der Build kompiliert sie zu `Assets.car` und `CodexVault.icns`. |
| `docs/CodexVault-Manual-EN.pdf`, `docs/CodexVault-Handbuch-DE.pdf` | Öffentliche englische und deutsche Bedienungsanleitungen für die aktuell umgesetzten Funktionen und Einstellungen. |
| `Scripts/ManualSources/`, `Scripts/generate-manual-pdfs.py` | Textquellen und reproduzierbarer Generator der öffentlichen PDF-Handbücher. |

Die App verwendet Swift Package Manager, SwiftUI, AppKit, Foundation und CryptoKit. Es gibt keine externen Paketabhängigkeiten.

## Datenformate und Abläufe

### Normales Backup

- Erstellt einen Ordner mit der Endung `.codexvault`.
- Enthält `manifest.json` und die ausgewählten Quellordner direkt an der Paketwurzel; es gibt keinen `payload`-Zwischenordner.
- Das Manifest hat aktuell Schema-Version 3, enthält nur relative Pfade sowie SHA-256-Prüfsummen und speichert keine absoluten Quellpfade.
- Die Prüfung akzeptiert aus Kompatibilitätsgründen Schema-Versionen 1 bis 3.
- Wiederherstellungen werden nur aus einem vollständig geprüften Paket erstellt und landen immer in einem neuen Restore-Ordner. Vorhandene Dateien im Ziel werden nicht überschrieben.

### Vollständiges Backup

- Erstellt je eine datierte ZIP-Datei und eine `latest`-Kopie für die Codex-App-Daten sowie jeden konfigurierten Projektordner.
- Die Codex-App-Daten und ein verfügbarer sichtbarer Codex-Arbeitsbereich werden beim vollständigen Backup automatisch für den jeweiligen macOS-Benutzer ermittelt. Nur ausdrücklich hinzugefügte Projektordner und das Ziel werden lokal gespeichert, einzeln sichtbar gelistet und einzeln entfernt. Ein frischer Start zeigt keine automatisch ermittelten Projektpfade als Konfiguration.
- Die ZIP-Dateien werden nach dem Erstellen mit dem Systemwerkzeug geprüft. Ältere datierte Sicherungen werden erst nach einer sichtbaren Bestätigung entfernt; pro Gruppe werden die drei neuesten behalten.
- Laufzeit- und Build-Daten werden gezielt ausgelassen: bei Codex temporäre Daten und IPC-Dateien, bei Projektordnern typische Build- und Abhängigkeitsordner.
- Dieses Backup ist ein vollständiger lokaler Datensicherungsablauf und kann vertrauliche Codex-Inhalte enthalten. Das Ziel muss daher ein vertrauenswürdiger lokaler Speicherort sein.

### Speicherübersicht

- Ermittelt ausschließlich lokal, welche Codex-Daten Speicher belegen.
- Gruppiert lokale Sitzungsdateien nach aktuellem Projekt, soweit eine Zuordnung vorhanden ist.
- Nicht zugeordnete lokale Datensätze können einzeln ausgewählt und erst nach einer Bestätigung dauerhaft entfernt werden. Es gibt keine automatische Löschung.

## Umgesetzte Funktionen

- Auswahl mehrerer Projekt- und Zusatzordner samt lokaler Größen- und Ausschlussvorschau.
- Normales, verifiziertes Backup mit SHA-256-Prüfung und lokal gespeicherter Archivliste: Beim nächsten Start bleiben zuvor von CodexVault erstellte Pakete sichtbar, sofern ihr Paketordner noch vorhanden ist. Unbekannte Pakete werden nicht automatisch gesucht oder importiert.
- Selektive Wiederherstellung geprüfter Quellen ohne Überschreiben vorhandener Dateien.
- Konfigurierbares vollständiges ZIP-Backup mit sichtbarer Mehrfach-Projektliste, Fortschritt und auf Wunsch bestätigter Aufbewahrung.
- Lokale Projektvorschau nach sichtbarer Auswahl eines Suchordners, zeitgesteuerte Full Backups ausschließlich bei geöffneter CodexVault-App sowie ein eindeutiger Hinweis, die separate Codex-Desktop-App vor einem Full Backup zu schließen.
- ChatGPT-Exporte als ausdrücklich ausgewählte normale Backup-Quelle und optionaler Passwortschutz für normale Pakete. Passwörter werden nicht gespeichert; verschlüsselte Pakete werden vor der Wiederherstellung lokal entschlüsselt und geprüft.
- Lokale Codex-Speicherübersicht einschließlich gruppierter Sitzungsdaten und kontrollierter Entfernung nicht zugeordneter Datensätze.
- Freundliche Erststart-Ansicht bei noch fehlenden eigenen Inhalten sowie dauerhaft erreichbare KI-Hilfe auf Overview mit Handbuch-Schaltfläche und bestätigter Kopier-und-Öffnen-Hilfe für ChatGPT, Google Gemini und Claude. Die statischen Prompts enthalten ausschließlich den passenden öffentlichen Handbuch-Link und bestätigte öffentliche App-Fakten; sie verbieten erfundene Funktionen.
- Getrennte lokale Dev-, Beta- und Final-Bundles mit eigenen Bundle-IDs und Datencontainern.
- Vier Designs: Liquid Glass, Full Glass, Graphite & Lime und Midnight. Full Glass nutzt eine einzige milchige Glasoberfläche im gesamten Fenster mit ruhigem, diagonal wanderndem Farbglow und zufällig auftauchenden Lichtpunkten; Liquid Glass beschränkt Glas auf die linke Navigation. Bei „Reduce Motion“ und während Backup-, Wiederherstellungs- oder Speicheranalyse-Abläufen pausiert die Full-Glass-Animation deutlich.
- Zweisprachige sichtbare Oberfläche mit Englisch als Standard und Deutsch als auswählbarer Sprache. Dieselbe Einstellung steuert auch KI-Hilfe und Handbuch-Link.
- App-Icon als Icon-Composer-Ressource mit Liquid-Glass-Effekten und freigestelltem PNG-Quellmotiv; macOS erzeugt fehlende Erscheinungsvarianten aus der gemeinsamen Icon-Struktur.
- GitHub- und Discord-Schaltflächen in der Seitenleiste verwenden lokal eingebundene offizielle Marken und öffnen ausschließlich die öffentlichen CodexVault- bzw. Community-Seiten nach einem Klick.

## Feste Regeln und Entscheidungen

- Mindestplattform ist macOS 26.
- Die sichtbare und interne Produktbezeichnung lautet **CodexVault**.
- Keine automatische Netzwerkkommunikation und keine stillen Backups. Öffentliche Links und KI-Dienste werden ausschließlich nach einer sichtbaren Aktion geöffnet; es werden keine App-Daten mitgegeben.
- Die KI-Hilfe öffnet einen Dienst nur nach sichtbarer Bestätigung. Sie kopiert ausschließlich eine statische allgemeine Frage in die Zwischenablage; Nutzende fügen sie selbst ein. Sie enthält keine App-Inhalte, lokalen Pfade oder Zugangsdaten.
- Normale Backups schließen typische Geheimnisdateien und -namen aus, darunter `.env`-Varianten, Tokens, Secrets, Credentials, Zertifikate und Schlüssel; außerdem werden typische Build- und Cache-Ordner ausgelassen.
- Bei vollständigen Backups gilt die definierte Vollständigkeit vor der Namensfilterung: Sie sind deshalb als vertrauliche lokale Sicherungen zu behandeln.
- Löschvorgänge brauchen eine sichtbare Auswahl und Bestätigung.
- Dev, Beta und Final sind getrennte Build-Kanäle. Ein lokaler Build bedeutet weder Commit noch Release noch Upload.
- Der vollständige Quellcode darf auf GitHub bereitgestellt werden, jedoch erst nach einer Datenschutzprüfung. Private Inhalte, lokale Pfade, Backups, Build-Ausgaben und Zugangsdaten sind ausgeschlossen.
- Dev-Bundles werden nie veröffentlicht. Ausschließlich Beta- oder Final-Bundles dürfen auf ausdrücklichen Auftrag veröffentlicht werden.
- Jede ausdrücklich beauftragte Beta- oder Final-Veröffentlichung enthält immer **beide** Formate: eine DMG und ein ZIP. Die DMG enthält zusätzlich den Finder-Link `Applications` auf `/Applications`, damit die App dorthin gezogen werden kann. Dev wird weder verpackt noch veröffentlicht.
- Zu jeder Beta- oder Final-Veröffentlichung wird ein versionierter Datenschutzbericht aus `docs/RELEASE_PRIVACY_REPORT_TEMPLATE.md` erstellt und als eigenständiger Release-Anhang mit veröffentlicht. Er enthält die SHA-256-Prüfsummen von DMG und ZIP.

## Build-, Test- und Release-Workflow

Im Projektstamm:

```zsh
swift test
Scripts/build-development.sh
```

Weitere lokale, nicht veröffentlichende Builds:

```zsh
Scripts/build-beta.sh
Scripts/build-final.sh
```

Für ein ausdrücklich beauftragtes Beta- oder Final-Release werden die beiden
Artefakte lokal und überprüft erzeugt (dies veröffentlicht nichts):

```zsh
Scripts/package-release-artifacts.sh beta CodexVault-<VERSION>
Scripts/package-release-artifacts.sh final CodexVault-<VERSION>
```

Das Skript lehnt Dev ab, erstellt ausschließlich DMG und ZIP, prüft beide und
stellt sicher, dass die DMG neben der App einen `Applications`-Link enthält.

Die Tests prüfen derzeit zentrale Backup- und ZIP-Verhalten. Jede spätere Beta- oder Final-Veröffentlichung braucht einen separaten Auftrag sowie einen angehängten Datenschutzbericht. Für die Veröffentlichung bleibt die App ad-hoc signiert; die einmalige, app-spezifische Gatekeeper-Freigabe ist vorgesehen. Einen Apple-Developer-Account, Zertifikate oder eine Notarisierung darf die Projektarbeit nicht anlegen oder voraussetzen.

## Quellcode und Veröffentlichungsstand

- Der vollständige, datenschutzgeprüfte Quellcode ist im öffentlichen Repository `Schrotty74/CodexVault` auf dem Branch `main` veröffentlicht.
- Die GPL-3.0-Lizenz liegt als `LICENSE` im Projektstamm. Ihre rechtliche Auswirkung wurde nicht gesondert geprüft.
- Die erste öffentliche Beta ist [CodexVault 1.0 Beta 1](https://github.com/Schrotty74/CodexVault/releases/tag/v1.0.0-beta.1). Sie enthält `CodexVault-1.0-Beta-1.dmg` (mit `Applications`-Link), `CodexVault-1.0-Beta-1.zip` und den separaten Datenschutzbericht. Es gibt keine Final- oder Dev-App-Veröffentlichung; Dev wird nie veröffentlicht.
- Der Beta-Build hat die Bundle-ID `com.codexvault.beta`, Version `1.0.0` und Build `1`. Er ist ad-hoc signiert und nicht notarisiert; Gatekeeper kann deshalb eine ausdrückliche Freigabe verlangen.
- Der Datenschutzbericht dieser Beta liegt unter `docs/releases/CodexVault-1.0-Beta-1-Privacy-Report.md` und ist zusätzlich als Release-Anhang veröffentlicht.
- Der Bericht zur ersten Quellcode-Veröffentlichung liegt unter `docs/PRIVACY_REPORT_SOURCE_PUBLICATION_2026-07-24.md`.
- Die öffentlichen README- und Handbuchdateien sind zweisprachig. Ihre Feature-Listen dürfen nur tatsächlich umgesetzte Funktionen enthalten.

## Bekannte Einschränkungen

- Die Archivansicht ist kein Dateibrowser: Sie zeigt nur die lokal gespeicherten, zuvor von CodexVault erstellten und noch vorhandenen Paketordner. Sie durchsucht keine Zielordner und importiert keine unbekannten Pakete automatisch.
- Weitere Sprachen über Englisch und Deutsch hinaus sind nicht umgesetzt.
- Die Vollständigkeit der automatischen Erkennung von Projektordnern ist bewusst begrenzt und kann eine manuelle Konfiguration erfordern.
- Die Icon-Composer-Ressource verwendet eine gemeinsame Liquid-Glass-Struktur mit freigestelltem Quellmotiv. Spezifische grafische Überarbeitungen für Dark oder Mono sind noch nicht manuell angelegt; macOS erzeugt diese Erscheinungsvarianten aus der gemeinsamen Struktur.
- Die Veröffentlichung verwendet bewusst keine Notarisierung. Die einmalige Gatekeeper-Freigabe ist für Beta- und Final-Artefakte Teil des vorgesehenen Installationsablaufs.

## Datenschutz und Veröffentlichungen

- Niemals private Inhalte, absolute Benutzerpfade, Zugangsdaten, Tokens, Backups oder Testdaten in Git, Dokumentation, Screenshots oder Veröffentlichungen aufnehmen.
- Keine Commits, Pushes, Tags, Versionsänderungen oder Releases ohne ausdrücklichen Auftrag.
- Öffentliche Nennungen verwenden ausschließlich den Namen `Schrotty74`.
- Vor jeder späteren Veröffentlichung müssen Datenschutz, Inhaltsausschlüsse, Verpackung und die sichtbaren Produktnamen erneut geprüft werden.
- Quellcode-Pushes erfolgen nur nach einer Datenschutzprüfung. Dev-Bundles werden nie veröffentlicht. Jeder Beta- und Final-Release enthält DMG, ZIP und einen aktuellen Datenschutzbericht als separaten Anhang.
