# Sicherheitsrichtlinie

[English](SECURITY.md)

## Unterstützte Versionen

Sicherheitsmeldungen werden für die aktuelle CodexVault-Version entgegengenommen.

## Sicherheitslücke melden

Bitte veröffentliche sensible Details zu Sicherheitslücken nicht in einem öffentlichen GitHub-Issue. Kontaktiere den Repository-Inhaber privat. Nenne die CodexVault- und macOS-Version, Schritte zum Reproduzieren und bereinigte Logs oder Screenshots. Füge niemals echte Codex-Daten, ChatGPT-Exporte, Projektquellcode mit Geheimnissen, Backup-Passwörter oder vollständige Backup-Archive bei.

## Geltungsbereich

Relevante Meldungen umfassen unter anderem Projekt- und Codex-Daten-Backups, ZIP-Erstellung und -Extraktion, SHA-256-Prüfung, passwortgeschützte Backup-Pakete, selektive Wiederherstellung, Ziel- und Pfadverarbeitung, Aufbewahrungs-/Bereinigungsaktionen, geplante Backups während CodexVault geöffnet ist und die Verarbeitung von ChatGPT-Exportdateien.

CodexVault arbeitet lokal und lädt Backup-Inhalte nicht hoch. Vollständige Backups können sensible lokale Codex- und Projektdaten enthalten. Besonders wichtig sind daher unbeabsichtigte Offenlegung oder Überschreibung, Archive-Traversal, unvollständiger Ausschluss von Geheimnissen oder Fehler bei Integritätsprüfungen.

Wiederherstellungen sind dafür ausgelegt, neue Ziele zu verwenden, statt bestehende Dateien unbemerkt zu überschreiben.

Vielen Dank, dass du dabei hilfst, CodexVault und seine Nutzer sicher zu halten.
