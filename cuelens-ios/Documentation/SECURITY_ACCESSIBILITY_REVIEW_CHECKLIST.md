# CueLens iOS – Security-, Datenschutz- und Accessibility-Review

Stand: 24.08.2026. Keine Prüfung darf echte Teilnehmerkennungen, App-Tokens, Craving-Werte oder Kompensationscodes in Screenshots, Logs oder Testartefakte übernehmen.

## Automatisch nachzuweisen

- Release ohne ATS-Ausnahme, lokales HTTP, lokale IP, Debug-/Staging-Endpunkte oder verbotene Usage-Description;
- keine unerwarteten Entitlements, Swift Packages, Tracking-/Analytics-SDKs, CloudKit-, iCloud- oder App-Group-Speicherung;
- Privacy Manifest syntaktisch und semantisch vollständig; Tracking deaktiviert; Required-Reason-APIs begründet;
- App-Token ausschließlich nicht synchronisierbar und `WhenUnlockedThisDeviceOnly`;
- Studienzustand mit vollständigem Dateischutz und Backup-Ausschluss;
- Logger nur mit Requesttyp, Status und abstrakter Fehlerkategorie;
- keine Force-Unwraps, `try!`, erzwungenen Casts, Compilerwarnungen oder Analyze-Befunde;
- Kontrastgrenzen, Touchziele, Accessibility-Labels und große Dynamic-Type-Szenarien;
- Fehler- und Recovery-Injektion ohne falschen Fortschritt oder Verlust eines sicher gespeicherten Pending-Werts.

## Manuell auf Release beziehungsweise signiertem Archiv

- [ ] Signatur, Team, App-ID und Provisioning gehören zur freigegebenen Distribution.
- [ ] Entitlements enthalten nur die erwartete Application-Identifier-/Keychain-Grundausstattung; keine iCloud-, App-Group-, HealthKit-, Kamera-, Mikrofon- oder Standortfähigkeit.
- [ ] Privacy Report aus Xcode entspricht `APP_PRIVACY_DATA_FLOW_MATRIX.md` und App Store Connect.
- [ ] Keine Debugmenüs, synthetischen UI-Testtexte, Staginghosts oder lokalen Testdaten im Archiv.
- [ ] App-Switcher zeigt bei inaktiver App nur den Privacy Curtain.
- [ ] App-Token und geschützte Zustandsdatei sind bei Gerätesperre nicht lesbar; Wiederaufnahme nach Entsperren bleibt konsistent.
- [ ] Deinstallation/Neuinstallation übernimmt keinen verwaisten Token als gültige Installation.
- [ ] Notification-Berechtigung kann verweigert und später entzogen werden, ohne Kernfunktionen zu blockieren.
- [ ] Sperrbildschirmbenachrichtigungen enthalten keine Studien- oder Gesundheitsdaten.

## Manuell mit VoiceOver und Dynamic Type

- [ ] Deutsch und Englisch auf Home, Feed, Consent, Aktivierung, Demo, Feedback, Studie, Retry und Abschluss.
- [ ] Fokusreihenfolge folgt der visuellen und fachlichen Reihenfolge.
- [ ] Nach Fehlern und Erfolgen gelangt der Fokus zur neuen Meldung.
- [ ] Produktive Reizbilder erhalten keine suggestive Beschreibung; Bildoptionen sind neutral unterscheidbar.
- [ ] Slider werden mit Bezeichnung und ganzzahligem Wert angekündigt und in Einerschritten bedient.
- [ ] Alle allgemeinen Controls besitzen ein ausreichend großes Touchziel.
- [ ] Bei maximaler Accessibility-Schriftgröße bleiben Texte, Formulare und Aktionen erreichbar und scrollbar.
- [ ] Hoch- und Querformat auf iPad; Hochformat auf kleinem iPhone.
- [ ] Kontrast und Statuskommunikation hängen nicht allein von Farbe ab.

## Offene externe Review-Gates

- Vier-Augen-Prüfung dieser Checkliste und der Datenschutzmatrix;
- Staging-E2E mit zurücksetzbarer direkter und Prolific-Registrierung;
- kontrollierte Netzwerkunterbrechung an jedem Auftrag-10-Übergang;
- reale Gerätetests und Prüfung eines signierten Release-Archivs.
