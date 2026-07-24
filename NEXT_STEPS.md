# Nächste Schritte – CodexVault

Stand: 24. Juli 2026

Dieses Dokument enthält nur Punkte, die aus dem aktuellen Quellcode oder der bereits getroffenen Produktentscheidung ableitbar sind. Bei größeren Änderungen aktualisieren.

## Priorität 1

- Die Archivansicht persistent machen oder klar als Sitzungsübersicht umbenennen. Derzeit werden frühere Backup-Pakete nach einem Neustart nicht erneut eingelesen.
- Die sichtbaren UI-Texte konsistent lokalisieren; die Oberfläche ist aktuell überwiegend Englisch.
- Den Normal- und Full-Backup-Ablauf mit realistischen, künstlichen Testdaten manuell durchtesten, insbesondere Wiederherstellung und die Auswahl mehrerer Projektordner. Ein aktuelles Ergebnis ist nicht dokumentiert.

## Priorität 2

- Die Projekterkennung für vollständige Backups mit transparenten Regeln und einer verständlichen Vorschau erweitern.
- Die Testabdeckung für Wiederherstellung, ältere Manifest-Schemata, Aufbewahrung und die ausgewählte Entfernung nicht zugeordneter lokaler Datensätze ausbauen.

## Nicht entschieden oder nicht implementiert

- Zeitgesteuerte oder automatische Backups: vorgesehen, aber noch nicht implementiert.
- Passwortschutz oder Verschlüsselung portabler Backup-Pakete: noch nicht entschieden.
- Import eines Chat-Exports: nicht implementiert.
- Signierungs- und Notarisierungsablauf: nicht festgelegt. Bei jeder späteren Beta- oder Final-Veröffentlichung ist jedoch ein Datenschutzbericht als Release-Anhang verpflichtend; Dev wird nie veröffentlicht.
