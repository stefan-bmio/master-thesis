# CueLens iOS – bekannte Befunde und Restrisiken

Stand: 24.08.2026. Es sind in den automatisierten Prüfungen keine offenen kritischen oder hohen Produktbefunde bekannt. Der Release-Status bleibt dennoch blockiert, solange die externen Nachweise nicht abgeschlossen sind.

## Release-blockierende Nachweise

| ID | Status | Erforderlicher Abschluss |
|---|---|---|
| REL-001 | blockiert | Unabhängiges Ethikvotum und freigegebene Einwilligungsunterlagen nachweisen; keine Aufnahme realer Teilnehmender vorher. |
| REL-002 | blockiert | Mit Distribution-Signatur archivieren, `verify_release_archive.sh` bestehen und Build nach App Store Connect hochladen. |
| REL-003 | blockiert | TestFlight-Build auf mindestens zwei realen Geräten prüfen. |
| REL-004 | blockiert | 14-Tage-Langzeittest mit 20 Durchgängen, Neustarts, Netzwerkfehler und Retry abschließen. |
| REL-005 | blockiert | Je eine zurücksetzbare direkte und Prolific-Staging-Registrierung vollständig abschließen. |
| REL-006 | blockiert | Datenschutzmatrix mit Serverkonfiguration und App-Store-Connect-Angaben im Vier-Augen-Prinzip abgleichen. |
| REL-007 | blockiert | Formale Releaseentscheidung nach der DoD-Checkliste datieren. |

Das lokal erzeugte Archiv ist nur mit einer Apple-Development-Identität signiert und enthält deshalb `get-task-allow=true`. Es dient ausschließlich dem technischen Archivierungsnachweis und ist weder als Distribution geprüft noch für TestFlight freigegeben.

## Akzeptierte technische Restrisiken

- Das bestehende Submission-Protokoll besitzt keine Request-ID. Nach unklarer Serverantwort kann ein Retry serverseitig nicht allein durch die App dedupliziert werden; Pending bleibt deshalb fail-closed erhalten und ein kontrollierter Supportprozess ist erforderlich.
- Die Gerätesystemzeit beeinflusst den lokalen Cooldown. Rückwärtsbewegungen verlängern faktisch die Sperre; eine manipulationssichere Serverzeit ist ohne Vertragsänderung nicht verfügbar.
- `BGAppRefreshTask` und lokale Benachrichtigungszustellung sind durch iOS best effort. Der Vordergrundabruf und das Start Gate bleiben autoritativ.
- Ein nicht bestätigter In-Memory-Trial wird nach Prozessbeendigung wiederholt. Auswahlen und Reaktionszeiten werden absichtlich nicht persistiert.
- Eine Deinstallation entfernt den geschützten Studienzustand, während ein Keychain-Token verbleiben kann. Der Installationsmarker verhindert eine unkontrollierte Fortsetzung und verweist fail-closed an den Support.
- Freitextfeedback kann trotz Nutzerhinweis selbst eingegebene Identifikatoren enthalten. Es bleibt deshalb getrennt und wird ohne App-Token gesendet.

## Kein Befund

Die wiederkehrende Xcode-26.6-Meldung `DebuggerVersionStore.StoreError` trat beim Start isolierter Simulator-UI-Prozesse auf, ohne Tests oder Appausführung zu beeinflussen. Sie ist kein CueLens-Produktfehler. Die Simulatorauswahl bevorzugt inzwischen stabile Standardmodelle.
