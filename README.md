# CodexVault

Die aktuelle Wissensquelle für neue Chats ist [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md); offene Arbeiten stehen in [NEXT_STEPS.md](NEXT_STEPS.md). [PHASE_0_DISCOVERY.md](PHASE_0_DISCOVERY.md) ist eine historische Bestandsaufnahme.

CodexVault ist eine lokale macOS-App für die selektive Sicherung und Wiederherstellung von Codex- und Arbeitsdaten.

## Erster App-Stand

Die erste SwiftUI-App enthält die Navigation, vier umschaltbare Darstellungsvarianten und sichere Leer-/Vorschaustände für Übersicht, Backup, Wiederherstellung, Archiv und Einstellungen.

Normale Backups sichern nur ausdrücklich ausgewählte Ordner in ein ebenfalls ausdrücklich gewähltes lokales Ziel. Das Full Backup verwendet einmal konfigurierte Quellen und ein Ziel. Die App speichert keinen privaten Inhaltskatalog, hat keine Netzwerkfunktion und entfernt Daten nur nach sichtbarer Auswahl und Bestätigung.

## Lokale Sicherung – Phase 1

Die Backup-Ansicht kann Projekte und zusätzliche Ordner über den macOS-Dateidialog auswählen. Sie zeigt eine lokale Vorschau von Dateianzahl und Größe, bevor der Benutzer ein Zielverzeichnis auswählt.

Beim Start der Sicherung erstellt CodexVault dort ein neues Paket mit Manifest und SHA-256-Prüfsummen. Die gewählten Projekt- und Ordnernamen liegen direkt im Paket; es gibt keinen technischen Zwischenordner. Das Paket wird direkt danach erneut geöffnet und verifiziert. Dateien mit typischen Geheimnisnamen, `.env`-Dateien, Zertifikate, Schlüssel sowie Standard-Build- und Cache-Ordner werden standardmäßig ausgeschlossen. Weder die App noch das Manifest speichert absolute Quellpfade.

Die Wiederherstellung öffnet ein CodexVault-Paket, prüft es vollständig, lässt die enthaltenen logischen Quellen einzeln auswählen und erstellt am gewählten Ziel immer einen neuen Restore-Ordner. Vorhandene Dateien werden nie überschrieben.

Zusätzlich sichert „Komplett-Backup“ die automatisch erkannte Codex-App-Datenbasis und die einmal pro macOS-Benutzer konfigurierten Projektordner. Pro Quelle entstehen eine datierte ZIP-Datei und eine `latest`-Kopie. Kein externes Skript wird ausgewählt. CodexVault prüft jedes ZIP und schlägt die Bereinigung älterer Sicherungen erst nach einer sichtbaren Bestätigung vor.

Chat-Import und zeitgesteuerte Sicherungen sind nicht implementiert. CodexVault erstellt Backups nur nach einer aktiven Aktion der nutzenden Person; es gibt keine stillen oder zeitgesteuerten Sicherungen.

## Lokal starten

Voraussetzung: macOS 26 und Xcode 26.6 oder neuer.

```zsh
swift run
```

Das Projekt kann auch als Swift Package in Xcode geöffnet werden. Es verwendet ausschließlich Apple-Frameworks und keine externen Abhängigkeiten.

Für ein lokal startbares Dev-Bundle verwende Scripts/build-development.sh. Das Bundle liegt danach unter Build/dev/CodexVault Dev.app.

## Getrennte Build-Kanäle

Scripts/build-development.sh, Scripts/build-beta.sh und Scripts/build-final.sh erzeugen getrennte lokale Bundles. Jeder Kanal hat einen eigenen Namen, eine eigene Bundle-ID, einen eigenen Swift-Build-Ordner und damit einen eigenen Sandbox-Datencontainer:

- Dev: CodexVault Dev / com.codexvault.dev
- Beta: CodexVault Beta / com.codexvault.beta
- Final: CodexVault / com.codexvault

Die Scripts bauen ausschließlich lokal. Sie veröffentlichen nichts, löschen keine Container und übernehmen keine Daten zwischen den Kanälen.

## App-Icon

`Assets/AppIcon/CodexVault.icon` ist die Icon-Composer-Ressource für macOS 26. Der lokale Bundle-Build kompiliert sie mit Apples Asset-Compiler zu `Assets.car` und `CodexVault.icns`; erst diese Bundle-Ressourcen erkennt der Finder als App-Icon. Das freigestellte Liquid-Glass-Quellmotiv erlaubt macOS die passende Erscheinungsvariante.

## Datenschutz

Lokale Inhalte, Zugangsdaten, Tokens, Backups und absolute Benutzerpfade gehören nicht in Git. Die Datei `.gitignore` schließt Build-Ausgaben und künftige Backup-Pakete aus.

Dev-Bundles werden niemals veröffentlicht. Eine spätere Veröffentlichung ist nur für Beta oder Final möglich und benötigt jeweils einen aktuellen Datenschutzbericht als separaten Release-Anhang. Die Vorlage steht in [docs/RELEASE_PRIVACY_REPORT_TEMPLATE.md](docs/RELEASE_PRIVACY_REPORT_TEMPLATE.md).
