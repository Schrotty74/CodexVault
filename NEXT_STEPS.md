# Nächste Schritte – CodexVault

Stand: 27. Juli 2026

Dieses Dokument enthält nur Punkte, die aus dem aktuellen Quellcode oder der bereits getroffenen Produktentscheidung ableitbar sind. Bei größeren Änderungen aktualisieren.

## Priorität 1

- Rückmeldungen zur öffentlichen Beta `v1.0.0-beta.1` sammeln und nur bestätigte Fehler oder Verbesserungen aufnehmen.
- Einen separaten, autorisierten Signierungs- und Notarisierungsablauf für spätere Beta- oder Final-Artefakte festlegen. Die erste Beta ist bewusst nur ad-hoc signiert.
- Die Archivansicht persistent machen oder klar als Sitzungsübersicht umbenennen. Derzeit werden frühere Backup-Pakete nach einem Neustart nicht erneut eingelesen.
- Die deutsche und englische Oberfläche mit einem manuellen Durchgang aller Ansichten und Dateiauswahl-Dialoge prüfen. Ein aktuelles Ergebnis ist nicht dokumentiert.
- Den Normal- und Full-Backup-Ablauf mit realistischen, künstlichen Testdaten manuell durchtesten, insbesondere Wiederherstellung und Verwaltung der konfigurierten Projektliste. Ein aktuelles Ergebnis ist nicht dokumentiert.

## Priorität 2

- Die Projekterkennung für vollständige Backups mit transparenten Regeln und einer verständlichen Vorschau erweitern.
- Die Testabdeckung für Wiederherstellung, ältere Manifest-Schemata, Aufbewahrung und die ausgewählte Entfernung nicht zugeordneter lokaler Datensätze ausbauen.
- Die Erststart-Ansicht manuell mit einer leeren lokalen Konfiguration testen, einschließlich fehlender konfigurierter Projektpfade, Logo-Darstellung, Zwischenablage und der sichtbaren Bestätigung vor dem Öffnen eines externen Dienstes. Ein Ergebnis ist nicht dokumentiert.

## Nicht entschieden oder nicht implementiert

- Zeitgesteuerte oder automatische Backups: vorgesehen, aber noch nicht implementiert.
- Passwortschutz oder Verschlüsselung portabler Backup-Pakete: noch nicht entschieden.
- Import eines Chat-Exports: nicht implementiert.
- Signierungs- und Notarisierungsablauf: nicht festgelegt. Bei jeder späteren Beta- oder Final-Veröffentlichung ist jedoch ein Datenschutzbericht als Release-Anhang verpflichtend; Dev wird nie veröffentlicht.
