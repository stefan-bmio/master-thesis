# CueLens iOS – formale Releasefreigabe

Release Candidate: `1.0.0 (1)`

Source Commit: `e66270a93a74fa435af03a8b2054f8f8738756cf`

Aktueller Entscheidungsstatus: **NICHT FREIGEGEBEN**

## Technische Evidenz

- [x] vollständiges automatisiertes Quality-Gate;
- [x] Unit-Tests auf ältester und aktueller Runtime;
- [x] iPhone-/iPad-UI-Suite einschließlich Accessibility;
- [x] Release Analyze und generischer Gerätebuild;
- [x] Content- und Source-Hashes im Release-Manifest;
- [x] keine bekannten kritischen oder hohen automatisierten Produktbefunde;
- [ ] Distribution-signiertes Archiv besteht `verify_release_archive.sh`;
- [ ] Archiv/Upload-Build stimmt exakt mit Release-Manifest überein.

## Studie, Datenschutz und Betrieb

- [ ] unabhängiges Ethikvotum geprüft;
- [ ] Studieninformation und Einwilligungsversion geprüft;
- [ ] Datenschutzmatrix gegen Backend, Hosting und App Store Connect vieräugig geprüft;
- [ ] Supportkontakt Ende-zu-Ende geprüft;
- [ ] synthetische direkte und Prolific-Testregistrierung freigegeben;
- [ ] keine realen Teilnehmerdaten in Test-/Reviewartefakten bestätigt.

## Reale Tests

- [ ] TestFlight-Build auf mindestens zwei realen Geräten installiert;
- [ ] direkter Abschluss vollständig und serverseitig konsistent;
- [ ] Prolific-Abschluss vollständig und serverseitig konsistent;
- [ ] Pending bleibt bei Netzwerkunterbrechung/Neustart erhalten;
- [ ] Notifications, Berechtigungsentzug und Reminder geprüft;
- [ ] Gerätesperre, Data Protection und App-Switcher geprüft;
- [ ] VoiceOver Deutsch/Englisch und maximale Schriftgröße geprüft;
- [ ] 14-Tage-Langzeittest bestanden.

## Entscheidung

- [ ] alle Release-Blocker REL-001 bis REL-007 geschlossen;
- [ ] App-Version, Buildnummer und Source Commit final bestätigt;
- [ ] Freigabe erteilt.

Entscheidungsdatum: `[ausstehend]`

Entscheidung: `NICHT FREIGEGEBEN`

Eine Datumszeile unter „Freigabe erteilt“ genügt als dokumentierte Freigabe; eine Namensangabe ist nicht erforderlich.
