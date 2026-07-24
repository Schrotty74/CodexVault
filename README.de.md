<p align="center">
  <img src="Assets/AppIcon/CodexVault-Transparent-Large.png" width="180" alt="CodexVault App-Icon">
</p>

# CodexVault

[Deutsch](README.de.md) · [English](README.md)

CodexVault ist eine lokale macOS-App zum Erstellen geprüfter Sicherungen von
ausgewählten Arbeitsordnern und Codex-bezogenen Daten. Die Wiederherstellung
erstellt immer neue Ordner und überschreibt keine vorhandenen Dateien. Es gibt
keinen Upload und keine stillen Backups.

## Funktionen

Diese Liste bei jeder umgesetzten, sichtbaren Funktionsänderung ergänzen oder
anpassen.

- Mehrere Projekt- und Zusatzordner für ein normales Backup auswählen.
- Dateianzahl, Größe und ausgeschlossene sensible Dateien vor dem Backup prüfen.
- Portable `.codexvault`-Pakete mit Manifest und SHA-256-Prüfsummen erstellen.
- Ein Paket vor der Wiederherstellung prüfen und enthaltene Quellen gezielt in
  einen neuen Ordner wiederherstellen.
- Ein vollständiges lokales ZIP-Backup der erkannten Codex-Daten und der
  konfigurierten Projektordner mit Fortschritt, Prüfung, datierter Kopie und
  `latest`-Kopie erstellen.
- Pro Quelle die drei neuesten datierten vollständigen Backups erst nach
  sichtbarer Bestätigung behalten oder ältere löschen; es gibt keine stille
  Bereinigung.
- Den lokalen Codex-Speicher nach Kategorien und Projektzuordnung prüfen sowie
  nur ausgewählte, nicht zugeordnete lokale Einträge nach Bestätigung dauerhaft
  entfernen.
- Vier Darstellungen verwenden: Liquid Glass, Full Glass, Graphite & Lime und
  Midnight.
- Dev-, Beta- und Final-Builds mit getrennten Bundle-IDs und Datencontainern
  verwenden.

## Dokumentation

- [Deutsches Handbuch](docs/MANUAL.de.md)
- [English manual](docs/MANUAL.en.md)
- [Projektkontext für neue Codex-Chats](PROJECT_CONTEXT.md)
- [Aktuelle Entwicklungsaufgaben](NEXT_STEPS.md)

## Voraussetzungen und lokaler Start

CodexVault benötigt macOS 26. Zum lokalen Starten des Swift Packages werden
Xcode 26.6 oder neuer benötigt:

```zsh
swift run
```

Für lokale Bundles stehen die Skripte in `Scripts/` bereit:

```zsh
Scripts/build-development.sh
Scripts/build-beta.sh
Scripts/build-final.sh
```

Die Skripte bauen ausschließlich lokal und veröffentlichen keine App.

## Datenschutz und Veröffentlichungen

CodexVault arbeitet lokal. Normale Backups schließen typische Geheimnisse und
Build-Artefakte aus. Vollständige Backups können sensible lokale Codex-Daten
enthalten und gehören deshalb nur in ein vertrauenswürdiges Ziel.

Dev-App-Bundles werden niemals veröffentlicht. Ausschließlich eine separat
beauftragte Beta- oder Final-Veröffentlichung ist möglich; jede benötigt einen
fertigen Datenschutzbericht als separaten Release-Anhang. Die Vorlage steht in
[docs/RELEASE_PRIVACY_REPORT_TEMPLATE.md](docs/RELEASE_PRIVACY_REPORT_TEMPLATE.md).

## Lizenz

CodexVault steht unter der [GNU GPL v3.0](LICENSE).
