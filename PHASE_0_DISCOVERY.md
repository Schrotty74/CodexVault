# CodexVault – Phase 0: Discovery

> Historische Bestandsaufnahme vom 22. Juli 2026. Der aktuelle Produktname ist CodexVault. Für den heutigen technischen Stand zuerst [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) und [NEXT_STEPS.md](NEXT_STEPS.md) lesen; bei Abweichungen gelten diese aktuellen Dokumente.

Stand: 22. Juli 2026
Status: Bestandsaufnahme abgeschlossen; Phase-1-Backup-Grundlage lokal implementiert

## Grenzen dieser Bestandsaufnahme

Die lokale Codex-Installation wurde ausschließlich lesend und über Struktur- und Metadaten geprüft. Es wurden keine Konfigurationsinhalte, Chat-Inhalte, Zugangsdaten, lokalen Benutzerpfade oder Dateinamen in dieses Dokument übernommen.

Zum Zeitpunkt dieser Bestandsaufnahme war CodexVault ein lokales Git-Repository ohne Commit und ohne Remote. Den aktuellen Quellcode- und Veröffentlichungsstand dokumentiert ausschließlich `PROJECT_CONTEXT.md`.

## Entwicklungsumgebung

| Bereich | Ergebnis |
| --- | --- |
| Plattform | Apple Silicon, macOS 26.5.2 |
| Xcode | 26.6 mit macOS SDK 26.5 |
| Swift | 6.3.3 |
| Versionsverwaltung | Git 2.50.1, lokal initialisiert |
| Zusätzliche Laufzeiten | Python 3.14.6, Node 26.5.0 vorhanden |

Für den MVP sind keine externen Bibliotheken erforderlich oder vorgeschlagen. SwiftUI, Foundation, CryptoKit und Security-Scoped Bookmarks decken die geplante Basis ab. Python und Node sind keine CodexVault-Abhängigkeiten.

## Lesende Codex-Inventarisierung

Die gefundene lokale Codex-Struktur enthält Konfiguration, Skills, Plugins, Erinnerungen, Sitzungen, Cache und eine lokale Datenbank. Eine Zugangsdaten-Datei ist vorhanden. Daraus folgt diese Schutzklassifizierung:

| Kategorie | Einstufung | Behandlung im Produkt |
| --- | --- | --- |
| Konfiguration | geschützt | Nur nach Einzelvorschau; Geheimnisse und lokale Pfade erkennen und ausschließen oder maskieren. |
| Skills und Plugins | prüfpflichtig | Auswahl pro Element; keine Zugangsdaten, Caches oder installierte Laufzeitdateien blind exportieren. |
| Erinnerungen und wiederverwendbare Prompts | privat | Standardmäßig nicht vorgewählt; nur explizit nach Inhaltswarnung sichern. |
| Sitzungen, Chatarchive und lokale Datenbank | hochsensibel | Kein Standardexport. Erst nach Formatvalidierung und expliziter Einzelauswahl als separates, klar gekennzeichnetes Modul zulassen. |
| Cache und temporäre Daten | nicht portabel | Nicht sichern; nur später als Kandidat einer bereinigenden Analyse ausweisen. |
| Zugangsdaten und Schlüssel | ausgeschlossen | Niemals in ein Backup aufnehmen, anzeigen, protokollieren oder in Manifeste schreiben. |

Die Inventarisierung bestätigt damit den Grundsatz aus dem Briefing: Codex benötigt eine regelbasierte, opt-in Moduldefinition. Es dürfen keine festen, nicht dokumentierten Pfade in die App eingebaut werden.

## Technische Machbarkeit pro Modul

| Modul | Machbarkeit | Phase-1/2-Grenze |
| --- | --- | --- |
| Projekte | direkt umsetzbar | Ordnerfreigabe per Security-Scoped Bookmark, deterministische Auswahl, Ausschlussregeln, SHA-256 und relative Pfade. Symlinks, Pakete und Git-Metadaten brauchen explizite Regeln. |
| Zusätzliche Ordner | direkt umsetzbar | Gleiches Sicherheitsmodell wie Projekte; keine dauerhafte Freigabe ohne Bookmark und sichtbare Quellenangabe. |
| Backup-Paket | direkt umsetzbar | Bundle-Verzeichnis mit `manifest.json`, `payload/` und Fehlerbericht; erfolgreicher Abschluss erst nach erneuter Manifest- und Prüfsummenprüfung. |
| Wiederherstellung | direkt umsetzbar | Keine absolute Quellpfadannahme. Zielwahl, Konfliktstrategie und anschließende Prüfung sind eigene Schritte. |
| Codex | nur nach Moduldefinition | Lokale Struktur ist vorhanden, aber teils privat oder installationsgebunden. Eine sichere Positivliste ist vor der Implementierung erforderlich. |
| ChatGPT-Export | machbar nach Musterexport | Erst mit einem künstlichen, nicht personenbezogenen Export die Exportstruktur validieren. Kein Cloud-Chat-Import versprechen. |
| Bereinigung | spätere Phase | In Phase 0 ausschließlich Klassifikation; keine Löschlogik oder Berechtigungen vorsehen. |

## Produktentscheidungen

1. **Mindestversion:** Verbindlich macOS 26. CodexVault wird nicht für ältere macOS-Versionen entwickelt oder getestet.
2. **Passwortschutz für Backups:** Noch offen. Gemeint ist nur: Soll ein portables Backup auf Wunsch mit einem Passwort geschützt werden? Das Passwort würde nie gespeichert und bei einer Wiederherstellung erneut abgefragt.
3. **Git und Quellcode:** Der vollständige CodexVault-Quellcode wird später in Git bereitgestellt. Private Inhalte, Zugangsdaten, lokale Pfade, Build-Ausgaben und Backup-Pakete bleiben ausgeschlossen. Davon getrennt wird die Sicherung eines versteckten Git-Ordners innerhalb eines Benutzerprojekts später als sichtbare Auswahl angeboten.
4. **Automatische Backups:** Geplant. Benutzer wählen selbst, wann gesichert wird, wohin gesichert wird und welche Module oder Ordner dazugehören. Es gibt keine stillen, voreingestellten Sicherungen.
5. **Startdesign:** Noch offen; der Benutzer legt das Standarddesign später fest. Alle vier Designs bleiben ausschließlich Darstellungsschichten.

## Designzerlegung der Master-Mockups

Gemeinsame Komponenten: native Fensterchromierung, linke Navigation (Overview, Backup, Restore, Archive, Settings), Titelbereich, Status-/Datenschutzbadge, Karten, Zeilen mit Auswahlzustand, Größensumme und primäre Abschlussaktion.

| Ansicht | Zustände |
| --- | --- |
| Übersicht | leer, gesund, Warnung, keine Backup-Ziele, Aktion läuft |
| Backup | Quelle nicht freigegeben, Auswahl leer, Auswahl gültig, sensible Funde, Prüfung läuft, Erfolg, Teilerfolg, Fehler |
| Wiederherstellung | Paket ungültig, Paket gültig, keine Auswahl, Zielkonflikt, Prüfung läuft, Erfolg, Teilerfolg, Fehler |
| Archiv | leer, lesbar, beschädigt, kompatibilitätskritisch |
| Einstellungen | vier Themes, Bewegung reduzieren, Transparenz reduzieren, Build-Kanal sichtbar getrennt |

Die Themes ändern nur Farben, Material und Animation. Auswahl, Prüfung, Warnungen und Schutzentscheidungen bleiben identisch.

Für die Glasvarianten gilt verbindlich: **Full Glass** verwendet eine durchgängige native macOS-Glasoberfläche für das gesamte Fenster. **Liquid Glass** beschränkt die Milchglasoptik auf die linke Hauptnavigation; Inhaltsbereich und Karten bleiben deckend. Beide Varianten verwenden echte AppKit-Visual-Effect-Flächen statt nur halbtransparenter SwiftUI-Farben.

## Vorschlag für die spätere kleine Xcode-Projektstruktur

Noch **nicht angelegt**:

```text
CodexVault/
  CodexVaultApp/          App-Shell, Navigation, Designs, Einstellungen
  CodexVaultDomain/       Modelle und Regeln ohne UI oder Dateizugriff
  CodexVaultServices/     Scanner, Backup, Restore, Privacy, Archive Store
  CodexVaultTests/        Synthetische Manifest-, Auswahl- und Konflikttests
  Fixtures/               Ausschließlich künstliche, nicht personenbezogene Daten
```

Eine App-Target plus drei lokale Swift-Package-Targets halten die Dateizugriffe von den Regeln und der UI getrennt. Dev, Beta und Final erhalten später getrennte Bundle-IDs, Container und Namen; bis dahin wird kein Build-Kanal angelegt.

## Nächste sichere Schritte

1. Phase 1 ist lokal vorhanden: Auswahl von Projekten und Zusatzordnern, Manifest, SHA-256-Prüfung und Archivliste. Die Sicherung wird nur nach expliziter Quellen- und Zielwahl erstellt.
2. Bei Bedarf die noch offenen Produktentscheidungen in einfacher Sprache festlegen.
3. Eine Positivliste für portable Codex-Bestandteile ausarbeiten, ohne Zugangsdaten, Sitzungen oder private Inhalte zu übernehmen.
4. Ein künstliches Projekt- und Chat-Export-Fixture definieren, bevor diese Module umgesetzt werden.
