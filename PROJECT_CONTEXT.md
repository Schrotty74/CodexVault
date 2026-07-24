# CodexVault – Projektkontext

Stand: 24. Juli 2026
Status: Öffentlicher Quellcode-Upload auf GitHub am 24. Juli 2026 erfolgt. Es gibt noch keine Beta- oder Final-Veröffentlichung.

## Zuerst lesen

1. Diese Datei – aktuelle technische und fachliche Grundlage.
2. [NEXT_STEPS.md](NEXT_STEPS.md) – nur die tatsächlich noch offenen Arbeiten.
3. [README.md](README.md) – kurze Startanleitung.
4. [PHASE_0_DISCOVERY.md](PHASE_0_DISCOVERY.md) – historische Bestandsaufnahme; bei Abweichungen hat diese Datei Vorrang.

Bei einer inhaltlichen Änderung an Funktionen, Datenformaten, Build-Abläufen oder offenen Punkten sind diese Datei und `NEXT_STEPS.md` im selben Arbeitsauftrag zu aktualisieren.

## Zweck

CodexVault ist eine lokale macOS-App zur Sicherung und Wiederherstellung von Arbeitsordnern und Codex-bezogenen Daten. Sie arbeitet ohne Netzwerkfunktion. Nutzende wählen bei normalen Backups Quellen und Ziel selbst; vollständige Backups verwenden einmal pro macOS-Benutzer eingerichtete Projektordner und ein Ziel.

## Architektur und wichtige Ordner

| Bereich | Aufgabe |
| --- | --- |
| `Sources/ArchiveAtlasApp/ArchiveAtlasApp.swift` | SwiftUI-App, Navigation, Ansichten und die vier Darstellungsvarianten. Der interne Target-Name ist noch `ArchiveAtlasApp`; sichtbar heißt die App CodexVault. |
| `Sources/ArchiveAtlasApp/BackupCoordinator.swift` | UI-Zustand, Dateiauswahl, asynchrone Abläufe und lokal gespeicherte Full-Backup-Einstellungen. |
| `Sources/ArchiveAtlasApp/BackupEngine.swift` | Vorschau, Erstellen, Prüfen und Wiederherstellen normaler Backups; ZIP-Backups; Speicheranalyse lokaler Codex-Daten. |
| `Sources/ArchiveAtlasApp/BackupDomain.swift` | Datenmodelle und Fehlerfälle. |
| `Sources/ArchiveAtlasApp/BuildChannel.swift` | Ermittelt den lokalen Build-Kanal aus dem App-Bundle. |
| `Tests/ArchiveAtlasAppTests/` | Automatisierte Tests für Backup-Ausschlüsse, Verifikation und ZIP-Inhalte. |
| `Scripts/` | Lokale Builds für Dev, Beta und Final. Diese Skripte veröffentlichen nichts. |
| `Packaging/` | Bundle-Vorlage und Signaturkonfiguration für die lokalen App-Bundles. |
| `Assets/AppIcon/` | Quellbilder und die von Icon Composer erzeugte `CodexVault.icon`-Ressource für das macOS-26-App-Icon. Der Build kompiliert sie zu `Assets.car` und `CodexVault.icns`. |

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
- Die Codex-App-Daten werden automatisch erkannt; Projektordner und Ziel werden lokal für den jeweiligen macOS-Benutzer gespeichert und können in der App geändert werden.
- Die ZIP-Dateien werden nach dem Erstellen mit dem Systemwerkzeug geprüft. Ältere datierte Sicherungen werden erst nach einer sichtbaren Bestätigung entfernt; pro Gruppe werden die drei neuesten behalten.
- Laufzeit- und Build-Daten werden gezielt ausgelassen: bei Codex temporäre Daten und IPC-Dateien, bei Projektordnern typische Build- und Abhängigkeitsordner.
- Dieses Backup ist ein vollständiger lokaler Datensicherungsablauf und kann vertrauliche Codex-Inhalte enthalten. Das Ziel muss daher ein vertrauenswürdiger lokaler Speicherort sein.

### Speicherübersicht

- Ermittelt ausschließlich lokal, welche Codex-Daten Speicher belegen.
- Gruppiert lokale Sitzungsdateien nach aktuellem Projekt, soweit eine Zuordnung vorhanden ist.
- Nicht zugeordnete lokale Datensätze können einzeln ausgewählt und erst nach einer Bestätigung dauerhaft entfernt werden. Es gibt keine automatische Löschung.

## Umgesetzte Funktionen

- Auswahl mehrerer Projekt- und Zusatzordner samt lokaler Größen- und Ausschlussvorschau.
- Normales, verifiziertes Backup mit SHA-256-Prüfung.
- Selektive Wiederherstellung geprüfter Quellen ohne Überschreiben vorhandener Dateien.
- Konfigurierbares vollständiges ZIP-Backup mit sichtbarem Fortschritt und auf Wunsch bestätigter Aufbewahrung.
- Lokale Codex-Speicherübersicht einschließlich gruppierter Sitzungsdaten und kontrollierter Entfernung nicht zugeordneter Datensätze.
- Getrennte lokale Dev-, Beta- und Final-Bundles mit eigenen Bundle-IDs und Datencontainern.
- Vier Designs: Liquid Glass, Full Glass, Graphite & Lime und Midnight. Full Glass nutzt die Glasoberfläche im gesamten Fenster; Liquid Glass nur für die linke Navigation.
- App-Icon als Icon-Composer-Ressource mit Liquid-Glass-Effekten und freigestelltem PNG-Quellmotiv; macOS erzeugt fehlende Erscheinungsvarianten aus der gemeinsamen Icon-Struktur.

## Feste Regeln und Entscheidungen

- Mindestplattform ist macOS 26.
- Die sichtbare Produktbezeichnung lautet immer **CodexVault**. Interne Bezeichner mit `ArchiveAtlas` sind technische Altlasten und werden nicht als öffentliche Produktbezeichnung verwendet.
- Keine Netzwerkfunktion und keine stillen Backups.
- Normale Backups schließen typische Geheimnisdateien und -namen aus, darunter `.env`-Varianten, Tokens, Secrets, Credentials, Zertifikate und Schlüssel; außerdem werden typische Build- und Cache-Ordner ausgelassen.
- Bei vollständigen Backups gilt die definierte Vollständigkeit vor der Namensfilterung: Sie sind deshalb als vertrauliche lokale Sicherungen zu behandeln.
- Löschvorgänge brauchen eine sichtbare Auswahl und Bestätigung.
- Dev, Beta und Final sind getrennte Build-Kanäle. Ein lokaler Build bedeutet weder Commit noch Release noch Upload.
- Der vollständige Quellcode darf auf GitHub bereitgestellt werden, jedoch erst nach einer Datenschutzprüfung. Private Inhalte, lokale Pfade, Backups, Build-Ausgaben und Zugangsdaten sind ausgeschlossen.
- Dev-Bundles werden nie veröffentlicht. Ausschließlich Beta- oder Final-Bundles dürfen auf ausdrücklichen Auftrag veröffentlicht werden.
- Zu jeder Beta- oder Final-Veröffentlichung wird ein versionierter Datenschutzbericht aus `docs/RELEASE_PRIVACY_REPORT_TEMPLATE.md` erstellt und als eigenständiger Release-Anhang mit veröffentlicht.

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

Die Tests prüfen derzeit zentrale Backup- und ZIP-Verhalten. Am 23. Juli 2026 lief `swift test` mit zwei erfolgreichen Tests. Ein vollständiger Signierungs- oder Notarisierungsworkflow ist nicht dokumentiert und darf nicht angenommen werden. Jede spätere Beta- oder Final-Veröffentlichung braucht einen separaten Auftrag sowie einen angehängten Datenschutzbericht.

## Bekannte Einschränkungen

- Der interne Swift-Package- und Quellname lautet noch `ArchiveAtlas`; eine vollständige interne Umbenennung ist nicht umgesetzt.
- Die Archivansicht zeigt nur Backups, die während der aktuellen App-Sitzung erstellt wurden. Sie durchsucht kein Zielverzeichnis nach früheren Paketen.
- UI-Texte sind überwiegend Englisch; eine vollständige Lokalisierung ist nicht umgesetzt.
- Die Vollständigkeit der automatischen Erkennung von Projektordnern ist bewusst begrenzt und kann eine manuelle Konfiguration erfordern.
- Die Icon-Composer-Ressource verwendet eine gemeinsame Liquid-Glass-Struktur mit freigestelltem Quellmotiv. Spezifische grafische Überarbeitungen für Dark oder Mono sind noch nicht manuell angelegt; macOS erzeugt diese Erscheinungsvarianten aus der gemeinsamen Struktur.

## Datenschutz und Veröffentlichungen

- Niemals private Inhalte, absolute Benutzerpfade, Zugangsdaten, Tokens, Backups oder Testdaten in Git, Dokumentation, Screenshots oder Veröffentlichungen aufnehmen.
- Keine Commits, Pushes, Tags, Versionsänderungen oder Releases ohne ausdrücklichen Auftrag.
- Öffentliche Nennungen verwenden ausschließlich den Namen `Schrotty74`.
- Vor jeder späteren Veröffentlichung müssen Datenschutz, Inhaltsausschlüsse, Verpackung und die sichtbaren Produktnamen erneut geprüft werden.
- Quellcode-Pushes erfolgen nur nach einer Datenschutzprüfung. Dev-Bundles werden nie veröffentlicht. Beta- und Final-Releases erhalten jeweils einen aktuellen Datenschutzbericht als separaten Anhang.
