# Nächste Schritte – CodexVault

Stand: 31. Juli 2026

Dieses Dokument enthält nur Punkte, die aus dem aktuellen Quellcode oder der bereits getroffenen Produktentscheidung ableitbar sind. Bei größeren Änderungen aktualisieren.

## Priorität 1

- Rückmeldungen zur öffentlichen Beta `v1.0.0-beta.1` sammeln und nur bestätigte Fehler oder Verbesserungen aufnehmen.

## Priorität 2

- Die Testabdeckung für Wiederherstellung, ältere Manifest-Schemata, Aufbewahrung und die ausgewählte Entfernung nicht zugeordneter lokaler Datensätze weiter ausbauen.
- Die Erststart-Ansicht manuell mit einer leeren lokalen Konfiguration testen, einschließlich fehlender konfigurierter Projektpfade, Logo-Darstellung, Zwischenablage und der sichtbaren Bestätigung vor dem Öffnen eines externen Dienstes. Ein Ergebnis ist nicht dokumentiert.

## Nicht entschieden oder nicht implementiert

- Weitere Chat-Exportformate außer ChatGPT: noch nicht implementiert.
- Veröffentlichungssignatur: Beta- und Final-Artefakte sind bewusst ad-hoc signiert und werden über die einmalige, app-spezifische Gatekeeper-Freigabe geöffnet. Bei jeder späteren Beta- oder Final-Veröffentlichung sind DMG (mit `Applications`-Link), ZIP und ein Datenschutzbericht mit beiden Prüfsummen verpflichtend; Dev wird nie verpackt oder veröffentlicht.
