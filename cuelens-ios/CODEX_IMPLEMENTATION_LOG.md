# CueLens iOS – Implementierungslog

Dieses Protokoll wird ausschließlich ergänzt. Planung und tatsächlich nachgewiesener Implementierungsstand sind getrennt zu dokumentieren.

## 15.08.2026 – Auftrag 0

**Datum und Commit**  
15.08.2026; Branch `codex/ios-auftrag-0`; uncommitteter Arbeitsstand auf Basis des Android-Referenz-Commits `9ef5f38ee341a0f59a1b2844773c8cadc8a807c2`.

**Auftragsnummer**  
Auftrag 0 – Repository-Grundlagen und kanonische Studienressourcen.

**Ziel**  
Eigenständige, prüfbare Ressourcenbasis für die native iOS-Portierung im Geschwisterverzeichnis `cuelens-ios/`, ohne Änderungen an Android-App oder Backend.

**Geänderte Dateien**

- Spezifikationen nach `cuelens-ios/` verschoben und ausschließlich hinsichtlich Repositorypfaden, Struktur und Dokumentversion 1.0.1 angepasst.
- Projektregeln, README, Schemata, leere Fixture-Verzeichnisse und gepinnte Entwicklungsabhängigkeiten ergänzt.
- Deterministischen Ressourcen-Generator und semantischen Prüfer ergänzt.
- 150 PNG-Dateien bytegleich aus der produktiven Android-Referenz kopiert.
- Content- und Assetmanifest Version 1 erzeugt.

**Ausgeführte Tests**

- `python3 -m py_compile Tools/generate_study_resources.py Tools/verify_study_resources.py`
- `python3 Tools/generate_study_resources.py`
- `.venv/bin/python Tools/generate_study_resources.py --check`
- `.venv/bin/python Tools/verify_study_resources.py`
- zusätzliche `jq`-Prüfung der Arraylängen 50/50/150
- Git-Pfadprüfung auf Änderungen außerhalb von `cuelens-ios/`
- visuelle Stichprobe der Indizes `010`, `026`, `036`, `044` und `049`

**Testergebnis**

- 50 Cue-, 50 Match-A- und 50 Match-B-Dateien vorhanden; alle 512 × 512 Pixel.
- Sämtliche iOS-Kopien sind SHA-256-byteidentisch zur Android-Referenz.
- 50 Matching- und 50 Labeling-Zuordnungen mit lückenlosen Indizes `0...49`.
- Anhang A und die Android-`CueLabelMapping`-Einträge stimmen exakt überein.
- Beide JSON-Dateien entsprechen den versionierten Draft-2020-12-Schemata.
- Erneute Generierung ist reproduzierbar und erzeugt keinen abweichenden Sollzustand.
- Stichprobe: alle 15 PNGs ließen sich visuell fehlerfrei darstellen; die jeweiligen deutschen und englischen Labels waren:
  - `010`: Packungsrascheln/Rauchschleier; pack rustling/smoke haze
  - `026`: gemeinsam draußen/Papiergeschmack; outside together/taste of paper
  - `036`: Halskratzen/Balkonmoment; scratchy throat/balcony moment
  - `044`: ziehen/Dazugehören; taking a drag/belonging
  - `049`: Rauchkringel/Aufglimmen; smoke ring/lighting up

**Sicherheits-/Datenschutzprüfung**

- Keine Teilnehmendenkennungen, App-Tokens oder Gesundheitsdaten ergänzt.
- Keine KI-, Modell-, Kamera-, Tracking- oder Cloud-Ressourcen übernommen.
- `cuelens/grouped/` und `AI_PoC/` sind von Generierung und Verifikation ausgeschlossen.
- Android-App und Backend wurden nicht geändert.

**Abweichungen von der Planung**  
Wegen des auf dem Entwicklungs-Mac vorhandenen Python 3.9 wurde `check-jsonschema` auf die letzte kompatible Version 0.36.2 statt 0.37.4 festgelegt. Sämtliche transitiven Entwicklungsabhängigkeiten wurden ebenfalls exakt gepinnt. Die Draft-2020-12-Validierung bleibt vollständig erhalten.

**Offene Punkte**

- Die separat identifizierte Anpassung der iPad-Vollbildvorgabe an iPadOS 26 ist vor Auftrag 1 zu entscheiden und umzusetzen.

**Menschliche Freigabe**  
Am 16.08.2026 ohne Namensnennung erteilt; die Fortsetzung mit Auftrag 1 wurde ausdrücklich beauftragt.

## 16.08.2026 – Auftrag 1

**Datum und Branch**
16.08.2026; Branch `codex/ios-auftrag-1`; Umsetzung auf Basis des freigegebenen Auftrags 0.

**Auftragsnummer**
Auftrag 1 – Xcode-Projekt, Build-Konfiguration und lokales CI-/Quality-Gate-Grundgerüst.

**Ziel**
Ein reproduzierbar baubares natives iOS-/iPadOS-Projekt ab Version 17.0 mit getrennten Umgebungen, strengen Compilerprüfungen, minimaler datenschutzkonformer App-Hülle und automatisierter lokaler Abnahme auf iPhone und iPad.

**Geänderte Dateien**

- Xcode-Projekt mit den Targets `CueLens`, `CueLensTests` und `CueLensUITests` sowie den geteilten Schemes `CueLens` und `CueLens Staging` ergänzt.
- Build-Konfigurationen `Debug`, `Staging` und `Release` in `.xcconfig`-Dateien getrennt; Debug/Staging verwenden nicht routbare `.invalid`-Endpunkte, produktive Werte liegen ausschließlich in Release.
- Deployment Target 17.0, Swift-6-Sprachmodus, vollständige Strict-Concurrency-Prüfung und Warnungen-als-Fehler festgelegt.
- Minimale lokalisierte SwiftUI-App, gültiges Privacy Manifest und testbare Fail-closed-Geometrieentscheidung ergänzt.
- Lokales Quality-Gate, Simulatorauswahl und Release-Artefaktprüfung ergänzt.
- Spezifikationen auf Version 1.1 präzisiert: adaptive iPad-Fenster und Systemrotation, produktive Reizdarstellung nur bei geeigneter hochformatiger Geometrie.

**Ausgeführte Tests**

- `xcodebuild -project CueLens.xcodeproj -list`
- Debug- und Staging-Build für den generischen iOS-Simulator
- drei Unit-Tests auf iPhone Air mit iOS 26.5 sowie auf iPhone 15 Pro mit iOS 17.5
- je ein UI-Smoke-Test auf iPhone Air und iPad mini (A17 Pro) mit iOS 26.5
- je ein UI-Smoke-Test auf iPhone 15 Pro und iPad (10. Generation) mit iOS 17.5
- `xcodebuild analyze` für Release
- unsigniertes Release-Archiv für ein generisches iOS-Gerät
- `Scripts/verify_release_configuration.sh`
- vollständiges `Scripts/quality_gate.sh`

**Testergebnis**

- iOS-17.5- (Build 21F79) und iOS-26.5-Simulator-Runtime (Build 23F77) installiert und auf iPhone sowie iPad betriebsbereit.
- Debug, Staging, Release, Analyze und unsigniertes Archiv erfolgreich und ohne Projektwarnungen.
- Unit-Tests: auf iOS 17.5 und iOS 26.5 jeweils 3 von 3 bestanden; UI-Smoke-Tests auf beiden Versionen und Geräteklassen jeweils 1 von 1 bestanden.
- Release-Prüfung bestätigt Bundle ID `de.eachandevery.cuelens`, Mindestversion 17.0, Privacy Manifest ohne Tracking, keine verbotenen Berechtigungsschlüssel oder ATS-Ausnahmen und keine Drittanbieterabhängigkeiten.
- iPhone ist auf Hochformat begrenzt; iPad unterstützt die erforderliche adaptive Systemrotation, während die produktive Studiengeometrie Querformat und zu kleine Szenen fail-closed ablehnt.

**Sicherheits-/Datenschutzprüfung**

- Keine Berechtigungen, Entitlements, Analyse-, Werbe-, Tracking- oder Crash-Reporting-SDKs ergänzt.
- Keine Geheimnisse, Zertifikate, Profile, Teilnehmendenkennungen oder Gesundheitsdaten eingecheckt.
- Lokale Signierparameter sind über eine ignorierte Datei vorgesehen.
- Android-App und Backend wurden nicht geändert.

**Abweichungen und Annahmen**
Wegen der adaptiven iPad-Fensterverwaltung werden auf iPadOS alle Systemausrichtungen deklariert. Die spätere produktive Studienansicht darf dennoch ausschließlich bei mindestens 375 × 667 Punkten und `Höhe >= Breite` laufen. Serverbasierte CI wurde entsprechend der Planung nicht eingerichtet; das reproduzierbare Shell-Gate bildet das CI-Grundgerüst lokal ab. Die erstmalige Datenmigration frisch installierter Simulatoren meldete teilweise einen nicht fatalen Abschlussfehler; der erste UI-Test traf dadurch auf einen noch nicht geladenen Accessibility-Dienst. Nach abgeschlossener Initialisierung bestanden die Wiederholungsläufe. Das Quality-Gate erlaubt deshalb genau einen UI-Retry, während Unit- und Buildfehler weiterhin unmittelbar fehlschlagen.

**Offene Punkte**

- Auf dem Entwicklungs-Mac ist keine gültige Apple-Codesigning-Identität vorhanden. Ein signiertes Geräte-/Distributionsarchiv erfordert außerhalb des Repositorys eine Apple-Team-ID, ein Zertifikat und das passende Provisioning.

**Menschliche Freigabe**
Am 16.08.2026 ohne Namensnennung erteilt; die Fortsetzung mit Auftrag 2 wurde ausdrücklich beauftragt.

## 16.08.2026 – Auftrag 2

**Datum und Branch**
16.08.2026; Branch `codex/ios-auftrag-2`; Umsetzung auf Basis des freigegebenen Auftrags 1.

**Auftragsnummer**
Auftrag 2 – Reines Domain-Modul.

**Ziel**
Fachliche Zustände, Wertgrenzen, Parser und Entscheidungsregeln der CueLens-Studie als UI- und infrastrukturunabhängige Swift-6-Schicht mit fail-closed Invarianten und reproduzierbaren Tests bereitstellen.

**Geänderte Dateien**

- Logisch abgegrenztes Domain-Modul unter `CueLens/Domain/` mit Bereichen für Aktivierung, gemeinsame Werttypen, Informationsfeed, Feedback, Studie und Abschluss ergänzt.
- `AppLanguage`, `ParticipantIdentifier`, `InfoMessage`, `FeedbackDraft`, `StudyState`, `CompletionState`, `SelfReportResponse`, UUID-v4-, Craving- und Situationswerttypen implementiert.
- Vollständige Permutation der 50 Cue-Matching-Items, fünf Trials je Situation und feste Fünferblöcke der zehn Cue-Labeling-Situationen abgebildet.
- Start-Gate mit expliziten Sperrgründen für ungültigen/abgeschlossenen Zustand, ausstehende Übertragung beziehungsweise Abschlussbestätigung, Token, Feature, Ressourcen, Geometrie und Cooldown implementiert.
- Strikte JSON-Parser mit exakten Schlüsselmengen, ganzzahligen Typprüfungen, kalendarisch gültigen UTC-Zeitpunkten, erwarteten Situationen/Bedingungen und getrennten Direct-/Prolific-Abschlüssen ergänzt.
- Stabil getaggte `Codable`-Repräsentation für Studien- und Abschlusszustand mit Millisekunden-Zeitpunkten und Invariantenprüfung bei Initialisierung sowie Decodierung ergänzt.
- 16 synthetische Message- und Submission-Fixtures sowie 27 Domain-Unit-Tests ergänzt; vorhandene drei Geometrie-Unit-Tests bleiben bestehen.
- `Scripts/verify_domain_boundaries.sh` ergänzt und in das Quality-Gate aufgenommen; es prüft erlaubte Imports, verbotene Infrastruktursymbole und die eigenständige Swift-6-Typprüfung.
- README und Architekturplanung auf Dokumentversion 1.2 um den tatsächlich gewählten Modulzuschnitt und die festgelegten Repräsentationen ergänzt.

**Ausgeführte Tests**

- `Scripts/verify_domain_boundaries.sh`
- `plutil -lint CueLens.xcodeproj/project.pbxproj`
- `xcodebuild -project CueLens.xcodeproj -list`
- Debug-Build für den generischen iOS-Simulator
- vollständiges `Scripts/quality_gate.sh` mit Debug-/Staging-Build, Unit-Tests, iPhone-/iPad-UI-Smoke-Tests und Release-Verifikation auf iOS 26.5
- alle Unit-Tests zusätzlich auf iPhone 15 Pro mit iOS 17.5 (Build 21F79)
- `git diff --check` und statische Prüfung der Domain-Imports

**Testergebnis**

- Domain-Grenzprüfung und eigenständige Swift-6-Typprüfung mit Strict Concurrency und Warnungen als Fehler erfolgreich.
- Xcode-Projekt syntaktisch gültig; Debug und Staging bauen ohne Signing.
- iOS 26.5: 30 von 30 Unit-Tests sowie je ein UI-Smoke-Test auf iPhone und iPad bestanden; Release-Konfiguration erfolgreich verifiziert.
- iOS 17.5: 30 von 30 Unit-Tests bestanden, keine Fehler und keine übersprungenen Tests.
- Alle 20 Situationen liefern die festgelegte Bedingungsreihenfolge und genau fünf Trials; Matching verwendet jeden Index `0...49` genau einmal.
- Ungültige Zustands-, Abschluss-, Message- und Submission-Kombinationen werden vollständig abgelehnt.

**Sicherheits-/Datenschutzprüfung**

- Domain enthält keine UI-, Netzwerk-, Keychain-, Notification-, Datei- oder Logging-Zugriffe und keine Drittanbieterabhängigkeiten.
- Keine Force-Unwraps, `try!` oder erzwungenen Casts im Produktionscode ergänzt.
- Fixtures enthalten ausschließlich synthetische Protokolldaten und keine realen Teilnehmendenkennungen, App-Tokens oder Gesundheitsdaten.
- Keine Plattform-, OS-, Geräte- oder Trackingfelder ergänzt.
- Android-App, KI-PoC und Backend wurden nicht geändert.

**Abweichungen und Annahmen**
Zur Wahrung der Einfachheit ist `CueLens/Domain/` ein logisch abgegrenzter Quellbereich im bestehenden App-Target und kein zusätzliches Framework oder Swift Package. Die Grenze wird durch eine separate Compiler- und Importprüfung technisch abgesichert. Unbekannte Felder in Serverantworten werden fail-closed abgelehnt. Feedbacklängen werden als Unicode-Skalare gezählt, entsprechend der serverseitigen Unicode-Zeichenzählung. Lokale Zeitpunkte werden stabil als Millisekunden seit Unix-Epoche codiert. Der erste vollständige Quality-Gate-Versuch traf beim Start des zuvor erfolgreichen Unit-Test-Runners auf einen transienten CoreSimulator-Mach-Fehler; der unveränderte vollständige Wiederholungslauf war erfolgreich. Das Quality-Gate selbst erhielt keinen Unit-Test-Retry.

**Offene Punkte**

- Die Infrastruktur aus den Folgeaufträgen muss die Domain-Parser und Zustandsinvarianten verwenden; Auftrag 2 führt bewusst noch keine Netzwerk- oder Persistenzzugriffe aus.
- Vor Auftrag 3 ist das Review-Gate mit fachlicher Gegenprüfung der 20 Situationen, fünf Trials, Bedingungsreihenfolge, Wartezeit und beiden Abschlussmodi durchzuführen.

**Menschliche Freigabe**
Ausstehend; erforderlich ist die fachliche Gegenprüfung gemäß Review-Gate von Auftrag 2.
