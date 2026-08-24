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
Am 16.08.2026 ohne Namensnennung erteilt; die Umsetzung von Auftrag 3 wurde ausdrücklich beauftragt.
Freigegeben 16.8.2026

## 16.08.2026 – Auftrag 3

**Datum und Branch**
16.08.2026; Branch `codex/ios-auftrag-3`; Umsetzung auf Basis des freigegebenen Auftrags 2.

**Auftragsnummer**
Auftrag 3 – Sicherer Tokenstore und geschützter Studienzustand.

**Ziel**
Installationsgebundene, atomare und fail-closed arbeitende lokale Persistenz für App-Token und kritischen Studienzustand ohne Cloud-Synchronisierung oder Speicherung zusätzlicher Forschungsdaten.

**Geänderte Dateien**

- Domain-Schnittstellen für Token- und Zustandsstore ergänzt; konkrete Betriebssystemzugriffe bleiben vollständig in `CueLens/Infrastructure/` gekapselt.
- Actor-basierten Keychain-Store mit festem Service und Account, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, ausgeschalteter Synchronisierung, UUID-v4-Prüfung, idempotentem Speichern und vollständiger OSStatus-Abbildung implementiert.
- 32-Byte-Installationsmarker aus `SecRandomCopyBytes` sowie fail-closed Abgleich von Marker, Zustandsdatei und Keychain-Token ergänzt.
- Deterministischen, größenbegrenzten und atomaren JSON-Zustandsstore mit Schema-Router, strikter Strukturprüfung, Domain-Invarianten, vollständigem Dateischutz und Backup-Ausschluss implementiert.
- Sicheren App-Bootstrap und neutralen lokalisierten Fehlerzustand ergänzt; ein ungültiger Persistenzzustand wird nicht als verwendbarer UI-Zustand veröffentlicht.
- 28 Infrastrukturtests mit In-Memory-Doubles sowie realen, synthetisch isolierten Simulator-Roundtrips für Keychain und Application Support ergänzt.
- Persistenz-Sicherheitsprüfung in das Quality-Gate aufgenommen und das Privacy Manifest wegen der Metadatenprüfung im eigenen Container um `NSPrivacyAccessedAPICategoryFileTimestamp` mit Grund `C617.1` ergänzt.

**Ausgeführte Tests**

- `Scripts/verify_domain_boundaries.sh`
- `Scripts/verify_persistence_security.sh`
- `plutil -lint` für Xcode-Projekt und Privacy Manifest sowie `jq empty` für den String Catalog
- vollständiges `Scripts/quality_gate.sh` mit Debug-/Staging-Build, Unit-Tests, iPhone-/iPad-UI-Smoke-Tests und Release-Verifikation auf iOS 26.5
- alle Unit-Tests zusätzlich auf iPhone 15 Pro mit iOS 17.5 (Build 21F79)
- `xcodebuild analyze` in Release für den generischen iOS-Simulator
- unsignierter Release-Build für `generic/platform=iOS`
- `git diff --check` und statische Prüfung auf verbotene Persistenz-, Logging- und Force-Unwrap-Nutzung

**Testergebnis**

- iOS 26.5: 58 von 58 Unit-Tests sowie je ein UI-Smoke-Test auf iPhone und iPad bestanden; Debug, Staging und Release-Verifikation erfolgreich.
- iOS 17.5: 58 von 58 Unit-Tests bestanden; keine Fehler, erwarteten Fehler oder übersprungenen Tests.
- Release-Analyse und unsignierter Geräte-Build erfolgreich und ohne Projektwarnungen.
- Keychain-Fehler, Tokenkonflikt, verwaister Token, beschädigter beziehungsweise fehlender Marker, beschädigter oder unbekannter Zustandsstand, Datei- und Zufallsfehler sowie konkurrierende Zugriffe werden getestet fail-closed behandelt.
- Reale Simulator-Roundtrips bestätigen synthetisch isolierte Keychain-Nutzung, atomare Zustandswiederherstellung und Backup-Ausschluss.

**Sicherheits-/Datenschutzprüfung**

- App-Token wird weder in Datei noch `UserDefaults` gespeichert und nicht synchronisiert; ein vorhandener abweichender oder formal ungültiger Wert wird nie still überschrieben oder gelöscht.
- Studienzustand und Installationsmarker liegen ausschließlich unter Application Support, erhalten vollständigen Dateischutz und werden aus Backups ausgeschlossen.
- Beschädigte Zustände werden weder zurückgesetzt noch überschrieben; die App zeigt ausschließlich eine neutrale Supportmeldung.
- Keine echten Teilnehmendenkennungen, Tokens oder Gesundheitsdaten, keine Cloud-, Analyse-, Tracking- oder Drittanbieterkomponenten ergänzt.
- Die Required-Reason-Deklaration `C617.1` entspricht der ausschließlichen Metadatennutzung im eigenen App-Container und wird automatisiert im Release-Artefakt geprüft.

**Abweichungen und Annahmen**
Der Token wird als bereits vorhandener Domain-Typ `UUIDv4` repräsentiert. Ein identischer erneuter Speichervorgang ist idempotent; ein anderer vorhandener Token erzeugt einen Konflikt. Fehlen Marker und Zustand, wird ein möglicher Keychain-Rest vor Anlage eines neuen Markers gelöscht. Fehlt nur der Marker bei vorhandener Zustandsdatei, wird nichts gelöscht. Da Schema 1 das erste reale Format ist, lehnt der explizite Router alle anderen Versionen ab, statt eine nicht belegte Migration zu erfinden. CoreSimulator meldet die effektive Data-Protection-Klasse trotz erfolgreicher Schutz-APIs nicht zuverlässig; Backup-Ausschluss und alle Schutzaufrufe sind automatisiert geprüft, die effektive Klasse wird auf echten Geräten zusätzlich strikt verifiziert.

**Offene Punkte**

- Das Review-Gate auf einem echten Gerät ist noch auszuführen: synthetischen Testtoken aktivieren, bei Gerätesperre Zugriffsschutz prüfen sowie Update- und Neuinstallationssimulation durchführen. Am Entwicklungs-Mac ist derzeit kein iOS-Gerät verbunden.
Ausgeführt am 16.8.2026

**Menschliche Freigabe**
16.8.2026

## 16.08.2026 – Korrektur zu Auftrag 3

**Anlass**
Beim ersten App-Start erschien auf Simulator und Gerät fälschlich der sichere Fehlerzustand „Lokale Daten konnten nicht sicher geladen werden.“

**Ursache und Korrektur**
`FileManager.attributesOfItem(atPath:)` meldet eine fehlende Datei als `NSFileReadNoSuchFileError` mit Code 260. Der Existenzcheck behandelte zuvor nur `NSFileNoSuchFileError` mit Code 4 als regulär nicht vorhanden. Dadurch wurde der bei einer frischen Installation erwartungsgemäß fehlende Marker als Dateisystemfehler bewertet. Der System-Dateiclient erkennt nun beide Foundation-Varianten als „nicht vorhanden“; andere Fehler bleiben fail-closed.

Der UI-Smoke-Test hatte den Fehler nicht erkannt, weil Lade-, Bereitschafts- und Fehlerzustand denselben Accessibility-Identifier verwendeten. Die Zustände besitzen nun getrennte Identifier, und der Smoke-Test wartet explizit auf `app.foundationStatus.ready` und lehnt `app.foundationStatus.failure` ab.

**Ergänzte Regressionstests**

- tatsächlicher System-Dateizugriff auf einen nicht vorhandenen Pfad liefert `false` statt eines Fehlers;
- vollständiger Bootstrap mit echten Application-Support-Dateien erzeugt bei einer frischen Installation einen geschützten Marker und lädt den initialen Studienzustand;
- verschärfter UI-Smoke-Test bestätigt den erfolgreichen Bereitschaftszustand.

**Testergebnis**

- gezielte Persistenz-, Bootstrap- und UI-Regressionstests auf iOS 26.5 bestanden;
- vollständiges Quality-Gate auf iOS 26.5 einschließlich iPhone- und iPad-Smoke-Test bestanden;
- iOS 17.5: 60 von 60 Unit-Tests bestanden, keine Fehler oder übersprungenen Tests;
- die Korrektur erzeugt oder löscht beim zuvor fehlgeschlagenen Start keine Studiendaten; eine Neuinstallation ist nicht erforderlich.

## 16.08.2026 – Auftrag 4

**Datum und Branch**
16.08.2026; Branch `codex/ios-auftrag-4`; Umsetzung auf Basis des ausdrücklich und per Gerätetest freigegebenen Auftrags 3.

**Auftragsnummer**
Auftrag 4 – Netzwerkbasis und API-Vertragstests.

**Ziel**
Eine zentrale datensparsame und fail-closed arbeitende HTTPS-Infrastruktur sowie typisierte Clientservices für die unveränderten CueLens-Backendverträge bereitstellen, ohne bereits Netzwerkabläufe aus der App-Oberfläche zu starten.

**Geänderte Dateien**

- Domain-Schnittstellen für Aktivierung, Informationsfeed, Feature-Konfiguration, Feedback und Studiensubmission ergänzt; der Submission-Vertrag erhält die lokal erwartete Situation für die strikte Antwortvalidierung.
- Zentralen Actor-basierten `URLSession`-Client mit ephemerer Konfiguration, ausgeschalteten Cookies/Credentials/Caches, 15-/30-Sekunden-Timeouts, vollständiger Redirect-Ablehnung und während des Empfangs greifenden Antwortlimits implementiert.
- Buildabhängige Endpunkte über eine eingecheckte minimale `Info.plist` und einen strikt validierenden Konfigurationsloader angebunden; nur absolute HTTPS-URLs ohne Credentials, Query oder Fragment werden akzeptiert.
- Typisierte Services für den zweistufigen Aktivierungsvertrag, Messages, Features, Feedback, Selbstbericht und Kompensationsbestätigung implementiert und mit den vorhandenen strikten Domain-Decodern verbunden.
- Fehlerklassen einschließlich nicht näher klassifizierbarem `transportFailure` sowie einen Logger ergänzt, dessen Schnittstelle ausschließlich Requesttyp, Status und technische Fehlerkategorie akzeptiert.
- 24 Contract-, Konfigurations-, Transport- und Servicetests mit isoliertem `URLProtocol`-Stub sowie acht neue synthetische Fixtures für Aktivierung, Features und Feedback ergänzt.
- Netzwerk-Sicherheitsprüfung in das Quality-Gate und die produktiven Endpunkte in die Release-Artefaktprüfung aufgenommen.
- Architekturplanung auf Version 1.4 und README um die tatsächlich festgelegten Netzwerkregeln ergänzt.

**Ausgeführte Tests**

- `Scripts/verify_domain_boundaries.sh`
- `Scripts/verify_persistence_security.sh`
- `Scripts/verify_network_security.sh`
- `plutil -lint` für Xcode-Projekt, App- und Privacy-Property-List sowie `jq empty` für den String Catalog
- gezielte neue `AppConfigurationTests`, `HTTPClientTests` und `NetworkServiceContractTests`
- vollständiges `Scripts/quality_gate.sh` mit Debug-/Staging-Build, Unit-Tests, iPhone-/iPad-UI-Smoke-Tests und Release-Artefaktprüfung auf iOS 26.5
- alle Unit-Tests zusätzlich auf iPhone 15 Pro mit iOS 17.5 (Build 21F79)
- `xcodebuild analyze` in Release für den generischen Simulator
- unsignierter Release-Build für `generic/platform=iOS`
- statischer Vergleich mit den Android-Clients/-Vertragstests und den fünf PHP-Endpunkten
- `git diff --check` sowie statische Prüfung auf verbotene Persistenz-, Cloud-, Plattform-, Logging- und Force-Unwrap-Nutzung

**Testergebnis**

- iOS 26.5: 84 von 84 Unit-Tests sowie je ein UI-Smoke-Test auf iPhone und iPad bestanden; vollständiges Quality-Gate erfolgreich.
- iOS 17.5: 84 von 84 Unit-Tests bestanden; keine Fehler, erwarteten Fehler oder übersprungenen Tests.
- Release-Analyse, Release-Artefaktprüfung und unsignierter Geräte-Build erfolgreich und ohne Projektwarnungen.
- Contract-Tests bestätigen Methoden, Pfade, Header, User-Agent, Unicode und exakt erlaubte Payloadfelder sowie 200/204, 400/401/404/405/429/500, Timeout, Offline, Abbruch, TLS-, sonstige Transport-, Content-Type-, Größen-, Empty-Body-, Malformed-JSON-, Protokoll- und Redirectfehler.
- Das Feature-Gate liefert ausschließlich bei explizitem Boolean `true` einen positiven Wert; sämtliche Fehler und Schemaabweichungen ergeben `false`.
- Die fünf produktiven HTTPS-Endpunkte sind im Release-Artefakt vorhanden; Debug und Staging bleiben bei nicht routbaren `.invalid`-Endpunkten.

**Sicherheits-/Datenschutzprüfung**

- Keine Cookies, Credentials, Responses oder Caches werden durch die Netzwerkkonfiguration persistent gespeichert.
- Sämtliche Redirects und Cleartext-URLs werden abgelehnt; System-Trust bleibt unverändert aktiv und es gibt weder Trust-Override noch Certificate Pinning.
- Requests enthalten keine Plattform-, Geräte-, OS-, Sprach-, Zeitzonen-, Installations- oder Zeitstempelfelder; der User-Agent lautet ausschließlich `CueLens/<Bundle-Version>`.
- Logger-API und statische Prüfung verhindern die Übergabe von Identifier, Token, Craving, Kompensationscode, Feedback-, Nachrichten-, Body- oder Payloaddaten.
- Tests und Fixtures enthalten ausschließlich synthetische Werte; es wurden keine produktiven schreibenden Endpunkte aufgerufen.
- Privacy Manifest benötigt durch die verwendeten Foundation-Netzwerk-APIs keine zusätzliche Required-Reason-Kategorie.

**Abweichungen und Annahmen**
Alle Redirects werden zur Vereinfachung strenger als die Mindestvorgabe abgelehnt. `application/json` wird als Medientyp mit optionalen Parametern akzeptiert; erwartete leere 204-Antworten benötigen keinen Content-Type und dürfen keinen Body enthalten. Nicht belegte optionale Feedbackfelder werden ausgelassen. Als `app_version` und User-Agent-Version wird die tatsächliche iOS-Bundle-Version `1.0.0` verwendet. Antwortlimits werden per `URLSession.AsyncBytes` während des Empfangs durchgesetzt. Der Submission-Service verlangt die erwartete Situation, weil eine strikte Antwortprüfung ohne lokalen Sollindex nicht möglich wäre. Auftrag 4 stellt nur Infrastruktur bereit; Aktivierungs-, Feed- und Studien-UI folgen in späteren Aufträgen.

Die vorhandenen PHP- und Android-Verträge wurden statisch verglichen. Ihre zusätzlichen Referenztests konnten auf dem Entwicklungs-Mac nicht ausgeführt werden, weil weder PHP-CLI noch eine Java-Laufzeit installiert ist; dies beeinträchtigt die isolierten iOS-Contract-Tests nicht.

**Offene Punkte**

- Vor Auftrag 5 ist das Review-Gate durch Gegenprüfung der aufgezeichneten iOS-Requests mit den Android-Vertragstests und PHP-Endpunkten menschlich freizugeben.
Requests werden durch Akzeptanztest zu einem späteren Zeitpunkt getestet
- Produktive Live-Schreibrequests bleiben bewusst ungetestet; eine spätere Ende-zu-Ende-Prüfung benötigt synthetische serverseitige Testregistrierungen beziehungsweise ein freigegebenes Staging-System.
freigegebenes Staging-System: http://192.168.1.243/cuelens

**Menschliche Freigabe**
16.8.2026

## 16.08.2026 – Auftrag 5

**Datum und Branch**
16.08.2026; Branch `codex/ios-auftrag-5`; Umsetzung auf Basis der durch den datierten Freigabevermerk ausdrücklich erteilten Freigabe von Auftrag 4. Der produktive Live-Schreibtest bleibt wie freigegeben einem späteren Akzeptanztest vorbehalten.

**Auftragsnummer**
Auftrag 5 – App-Shell, Sprache, Lifecycle und Informationsfeed.

**Ziel**
Vollständiger datensparsamer App-Start bis zur vorläufigen Startseite mit persistentem Sprachwechsel, fehlertolerantem Informationsfeed und blickdichtem Lifecycle-Sichtschutz.

**Geänderte Dateien**

- `AppEnvironment` und das `@MainActor`-isolierte App-Modell zur geordneten Komposition von Einstellungen, sicherer Persistenz und Feed ergänzt.
- Actor-gekapselten `UserDefaults`-Store für Sprache sowie positive ausgeblendete und bekannte Nachrichten-IDs implementiert; Nachrichtentexte werden nicht gespeichert.
- Feed-Repository, vollständige Seitenfolge, Sortierung, sitzungsweises Schließen, dauerhaftes Ausblenden, spezifikationsgemäße Zurücknavigation und neutrale Fehlerhinweise ergänzt.
- Sofortigen Deutsch-/Englisch-Wechsel mit persistenter Auswahl und Systemsprachregel für den Erststart implementiert.
- Vollständig undurchsichtigen Privacy Curtain für inaktive beziehungsweise im Hintergrund befindliche Scenes ergänzt; neue Feedrequests beginnen nur im aktiven Vordergrund.
- Lokales Staging-System unter `192.168.1.243` ausschließlich für Staging konfiguriert; HTTP wird vom Loader nur bei explizitem Flag und für Loopback-, `.local`- oder private IPv4-Ziele akzeptiert. Release bleibt HTTPS-only und ohne ATS-Ausnahme.
- Synthetische, ausschließlich in Debug kompilierte UI-Testfeeds sowie neue Unit- und UI-Tests ergänzt.
- Privacy Manifest um `NSPrivacyAccessedAPICategoryUserDefaults` mit Grund `CA92.1` für ausschließlich app-eigene Einstellungen ergänzt.
- Architekturplanung auf Version 1.5 und README auf den umgesetzten Stand aktualisiert.

**Ausgeführte Tests**

- `Scripts/verify_domain_boundaries.sh`
- `Scripts/verify_persistence_security.sh`
- `Scripts/verify_network_security.sh`
- `Scripts/verify_staging_configuration.sh`
- vollständiges `Scripts/quality_gate.sh` mit Debug-/Staging-Build, Unit-Tests, vier UI-Szenarien auf iPhone und iPad sowie Release-Artefaktprüfung auf iOS 26.5
- sämtliche Unit-Tests zusätzlich auf iOS 17.5
- `xcodebuild analyze` in Release und unsignierter Release-Gerätebuild
- read-only HTTP-Abruf des lokalen Staging-Nachrichtenendpunkts
- `plutil -lint`, `jq empty`, `git diff --check` und statische Prüfung auf direkte Infrastrukturzugriffe aus Views, Force-Unwraps und sensible Persistenz

**Testergebnis**

- iOS 26.5: 96 von 96 Unit-Tests bestanden; alle vier UI-Szenarien auf iPhone und iPad bestanden.
- iOS 17.5: 96 von 96 Unit-Tests bestanden.
- Debug, Staging, Release, Analyze und unsignierter Gerätebuild erfolgreich und ohne Projektwarnungen.
- Systemsprachregel, sofortiger und persistenter Sprachwechsel, Feed mit null/einer/mehreren Nachrichten, Sortierung, Zurücknavigation, Ausblendung, bekannte IDs, Speicher- und Feedfehler sowie Lifecycle-Sichtschutz sind automatisiert geprüft.
- Das Release-Artefakt enthält weder die lokale IP-Adresse noch lokales HTTP oder eine ATS-Ausnahme. Staging enthält ausschließlich `NSAllowsLocalNetworking`, keine globale ATS-Freigabe.
- Der lokale Staging-Endpunkt antwortete auf `messages.php` mit HTTP 200, jedoch ohne JSON-Content-Type und mit ausgeliefertem PHP-Quelltext. Der iOS-Client lehnt diese Antwort korrekt als Protokollfehler ab; ein Live-Feed-Akzeptanztest ist serverseitig noch nicht möglich.

**Sicherheits-/Datenschutzprüfung**

- In `UserDefaults` liegen ausschließlich Sprache und positive Nachrichten-IDs; keine Nachrichtentexte, Tokens, Kennungen, Craving-Werte oder Studienfortschritte.
- Der Privacy Curtain verdeckt die gesamte Oberfläche vor App-Switcher-Snapshots; Hinweise bleiben neutral und enthalten keine Backenddetails.
- Synthetische UI-Testfeeds enthalten keine realen Teilnehmenden- oder Gesundheitsdaten und führen keine Netzwerkrequests aus.
- Release erzwingt weiterhin HTTPS, System-Trust und die vorhandenen Netzwerkgrenzen; die lokale HTTP-Ausnahme ist build- und zielgebunden.
- Android-App, Backend und KI-PoC wurden nicht verändert.

**Abweichungen und Annahmen**
Fehler unkritischer Einstellungen blockieren die App nicht: ungültige Werte werden verworfen, die Sprache wird erneut aus der primären Systemsprache abgeleitet und Schreibfehler erzeugen einen neutralen Hinweis. Bekannte IDs werden erst beim Feedende geschrieben und umfassen alle erfolgreich abgerufenen IDs einschließlich bereits ausgeblendeter Nachrichten. Benachrichtigungseinwilligung und Hintergrundprüfung bleiben Auftrag 6 vorbehalten. Wegen der fehlerhaften PHP-Auslieferung wird der freigegebene Staging-Host bis zur Serverkorrektur nur als konfiguriertes Ziel und nicht als bestandener Ende-zu-Ende-Nachweis bewertet.

**Offene Punkte**

- Review-Gate: manuelle Prüfung auf kleinem iPhone und iPad mit Deutsch, Englisch, Feedfehler und App-Switcher-Sichtschutz.
- Das lokale Staging-System muss PHP serverseitig ausführen, `application/json` liefern und sollte vor weitergehenden Akzeptanztests auf HTTPS umgestellt werden. Bis dahin dürfen keine schreibenden Staging-Akzeptanztests erfolgen.

**Menschliche Freigabe**
16.8.2026

## 16.08.2026 – Korrektur zu Auftrag 5: lokale Staging-Transportpolicy

**Anlass**
Der Staging-Feed meldete `invalidConfiguration`, obwohl der Konfigurationsloader den explizit freigegebenen privaten HTTP-Endpunkt akzeptiert hatte.

**Ursache und Korrektur**
Der zentrale HTTP-Client validierte jeden Request unabhängig vom Build weiterhin pauschal als HTTPS-only. Eine gemeinsame `NetworkTransportPolicy` wird nun sowohl vom Konfigurationsloader als auch vom HTTP-Client verwendet und durch `NetworkServices` weitergereicht. HTTPS-only bleibt Standard und Release-Regel. Die lokale Policy akzeptiert HTTP ausschließlich für Loopback-, `.local`- und private IPv4-Ziele; öffentliche HTTP-Ziele bleiben gesperrt.

**Ergänzte Regressionstests**

- Standardclient lehnt HTTP weiterhin vor dem Transport ab;
- explizite lokale Policy übermittelt einen aufgezeichneten HTTP-Request an `192.168.1.243`;
- öffentliche HTTP-Ziele bleiben auch mit lokaler Policy abgelehnt;
- geparste Staging-Konfiguration liefert die lokale Policy, normale HTTPS-Konfiguration die sichere Standardpolicy;
- statisches Netzwerk-Gate prüft die Weitergabe der Policy vom Build bis zum Client.

**Testergebnis**

- gezielte Konfigurations- und HTTP-Clienttests bestanden;
- vollständiges Quality-Gate mit 98 Unit-Tests und je vier UI-Szenarien auf iPhone und iPad unter iOS 26.5 bestanden;
- 98 Unit-Tests unter iOS 17.5 bestanden;
- Release-Analyse und unsignierter Gerätebuild erfolgreich; Release bleibt ohne HTTP-Endpunkt und ATS-Ausnahme.

Der davon unabhängige Staging-Serverfehler bleibt bestehen: `messages.php` lieferte beim dokumentierten Prüfaufruf PHP-Quelltext ohne JSON-Content-Type. Sobald der Client den Server erreicht, lehnt er eine solche Antwort erwartungsgemäß als ungültigen Content-Type ab.

## 16.08.2026 – Korrektur zu Auftrag 5: Local-Network-Privacy auf Geräten

**Anlass und Diagnose**
Der Staging-Feed funktionierte im Simulator, meldete auf einem iPhone mit iOS 26.6 jedoch zunächst `URLError.notConnectedToInternet`, obwohl Safari den lokalen Server erreichte. Das gebaute Staging-Artefakt enthielt die ATS-Deklaration `NSAllowsLocalNetworking`, aber keine Nutzungserklärung für die davon unabhängige Local-Network-Privacy-Freigabe. Nach aktiviertem lokalen Netzwerkzugriff und einem Neustart des App-Prozesses war der Feed auf dem Gerät erreichbar.

**Korrektur**
Nur die Staging-Property-List enthält nun `NSLocalNetworkUsageDescription` mit einer sachlichen Erklärung des Zugriffs auf den lokalen Testserver. Das Staging-Gate verlangt die Erklärung im gebauten Artefakt. Das Release-Gate verbietet sowohl diese Erklärung als auch weiterhin jede ATS-Ausnahme, sodass der produktive HTTPS-Build unverändert keinen lokalen Netzwerkzugriff deklariert.

**Prüfung**
Die Property Lists werden syntaktisch validiert; anschließend werden Staging- und Release-Artefakt sowie das vollständige Quality-Gate geprüft. Der abschließende Gerätetest muss bei einer frischen Installation die systemseitige Freigabe anzeigen und nach Zustimmung den Feed laden.

Staging- und Release-Artefaktprüfung sowie das vollständige Quality-Gate mit 98 Unit-Tests und je vier UI-Szenarien auf iPhone und iPad unter iOS 26.5 bestanden. Ein signierter Staging-Gerätebuild enthielt die erwartete Nutzungserklärung, wurde als datenbewahrendes Update auf dem verbundenen iPhone installiert und erfolgreich gestartet. Der erneute Dialogtest bleibt bewusst einer späteren frischen Installation vorbehalten, da eine Deinstallation den lokalen Staging-App-Container löschen würde.

## 17.08.2026 – Auftrag 6

**Freigabe und Umfang**

Die unter Auftrag 5 nachgetragene Datumszeile und die ausdrückliche Nutzerbestätigung geben das Review-Gate frei. Umgesetzt wurden der App-interne Benachrichtigungsdialog, die optionale Systemberechtigung, lokale Studienerinnerungen, Notification-Routing, die best-effort Hintergrundprüfung des Informationsfeeds sowie eine modusunabhängige CueLens-Farbpalette.

**Implementierung**

- Der eigene Dialog erscheint nur nach einem erfolgreichen Feedabschluss und vor einer möglichen Systemanfrage. Auswahl, abgeschlossene Entscheidung und effektive Aktivierung werden ohne Gesundheitsdaten in `UserDefaults` gespeichert; Ablehnung und Fehler bleiben fail-safe deaktiviert.
- `NotificationCoordinator` plant ausschließlich Alert-Benachrichtigungen ohne Ton, Badge, Nutzdaten oder sensible Texte. Deterministische Reminder-IDs, Berechtigungsprüfung, Zustandsregeln, Entfernen obsoleter Requests, Sprachwechsel und neutrale Vorschautexte sind zentral gekapselt.
- Ein Hinweis auf neue Informationen öffnet den Informationsfeed erneut; eine Studienerinnerung führt nur zur Startseite und löst keine Studienaktion aus.
- `BGAppRefreshTask` ist unter `de.eachandevery.cuelens.infofeed.refresh` registriert, wird nur bei wirksamer Einwilligung ungefähr täglich erneut geplant und verwendet den bestehenden lesenden Feedservice. Alle abgerufenen IDs werden bekannt gesetzt; pro Lauf entsteht höchstens ein generischer Hinweis.
- Es gibt keine APNs-Registrierung, kein Push-Entitlement und keinen neuen Backend- oder Android-Eingriff.
- Die gesamte App erzwingt die festgelegte helle CueLens-Palette auch bei dunkler Systemdarstellung. Nachrichtentexte behalten dadurch auf dem hellen Hintergrund den vorgesehenen dunklen Kontrast.

**Tests und technische Prüfung**

- 116 Unit-Tests prüfen zusätzlich Consent-Reihenfolge und alle Entscheidungen, Preference-Normalisierung, Permission-Entzug, Reminder-Policy und Kennungen, Cancel-/Reconcile-Logik, Sprachwechsel, Routing sowie erfolgreiche, bekannte, ausgeblendete, deaktivierte und fehlschlagende Hintergrundabrufe.
- Sechs UI-Szenarien liefen auf iPhone und iPad unter iOS 26.5; dazu gehört die Lesbarkeit des Informationsfeeds bei erzwungener dunkler Systemdarstellung.
- Alle 116 Unit-Tests bestanden zusätzlich unter iOS 17.5.
- Das vollständige lokale Quality-Gate einschließlich Debug, Staging und Release, die Notification-, Persistenz-, Netzwerk- und Domain-Gates, Release-Analyze sowie ein unsignierter Release-Gerätebuild bestanden.
- Statische Prüfungen bestätigen ausschließlich `.alert`, das Fehlen von Push, Sound, Badge und sensitiven Payload-Feldern, die Hintergrunddeklaration `fetch`, syntaktisch gültige Property Lists und Lokalisierung sowie das Fehlen erzwungener Casts und Force-Unwraps im Produktionscode.
- Ein signierter Staging-Build wurde als datenbewahrendes Update auf dem verbundenen iPhone installiert. Der anschließende automatisierte Start wurde ausschließlich durch den gesperrten Gerätezustand abgewiesen; Installation und Signatur waren erfolgreich.

**Abgrenzung und Review-Gate**

Aktivierung und Studienablauf werden erst in den Folgeaufträgen umgesetzt. Die produktive Reminder-Schnittstelle und ihre vollständige Policy sind vorhanden, erhalten bis dahin aber noch keinen aktivierten Fortschrittszustand und planen folgerichtig keine Studienerinnerung. Die Hintergrundausführung bleibt systemseitig best effort; der Vordergrundabruf ist weiterhin maßgeblich.

Ausstehend ist das menschliche Review auf einem echten Gerät: erstmaliges Erlauben und Ablehnen, nachträglicher Berechtigungsentzug, Öffnen beider Notification-Typen und Sprachwechsel. Ein bestehender App-Container wird für diesen Test nicht ohne ausdrückliche Freigabe gelöscht.

Freigabe erfolgte am 17.8.26

## 17.08.2026 – Auftrag 7

**Freigabe und Umfang**

Auftrag 6 wurde durch den datierten Vermerk ausdrücklich freigegeben. Auftrag 7 wurde auf Branch `codex/ios-auftrag-7` umgesetzt und umfasst die E-Mail-/Prolific-Aktivierungsseite, lokale Validierung, den zweistufigen Aktivierungshandshake, Keychainpersistenz nach Bestätigung, Timeout- und Recovery-Behandlung sowie die vorläufige Startseitenintegration.

**Implementierung**

- `ActivationCoordinator` serialisiert Anforderung und Bestätigung und akzeptiert während eines laufenden oder ausstehenden Handshakes keinen zweiten Versuch. Der UUID-v4-Token bleibt innerhalb des Actors und wird erst nach der erwarteten leeren 204-Antwort gespeichert.
- Die Aktivierungsseite akzeptiert dieselben E-Mail- und Prolific-Regeln wie Domain und Android-Referenz. Sie deaktiviert Eingabe, Zurücknavigation und Submit während des Handshakes, unterstützt sofortigen Sprachwechsel und entfernt die Teilnehmerkennung nach Erfolg oder Fehler aus dem AppModel.
- Der Bestätigungstimeout zeigt den vorgeschriebenen Supporttext. Andere Request-, HTTP- und Protokollfehler bleiben neutral und wiederholbar. Ein Keychain- oder sicherheitskritischer Dateifehler wechselt fail-closed in den sicheren Supportzustand.
- Vor dem Bestätigungsrequest wird ohne Kennung oder Token der Marker `activation-confirmation-uncertain-v1` atomar, vollständig dateigeschützt und vom Backup ausgeschlossen gespeichert. Nach eindeutigem Fehler oder sicherer Tokenspeicherung wird er entfernt. Bei Timeout, Prozessabbruch oder Keychainfehler bleibt eine unkontrollierte erneute Aktivierung im laufenden Prozess und nach einem Neustart gesperrt; ein bereits vorhandener gültiger Token bereinigt einen verbliebenen Marker.
- Nicht aktivierte Apps bieten die Aktivierung an; aktivierte Apps zeigen nur den abgeschlossenen Zustand und können die Seite nicht erneut öffnen. Nach Erfolg wird unmittelbar die bestehende Notification-Reconcile-Schnittstelle aktualisiert.
- Alle sichtbaren Texte entsprechen der deutschen und englischen Android-Referenz. Es wurde kein iOS-interner Datenschutz-Zustimmungsdialog ergänzt.

**Tests und technische Prüfung**

- 133 Unit-Tests bestanden unter iOS 26.5 und zusätzlich unter iOS 17.5. Neue Tests prüfen beide Kennungstypen, Trimmen und Case-Erhalt, Doppelaufrufe, beide Handshakephasen, Fehler- und Timeoutklassifikation, Speichern erst nach Bestätigung, Marker-Lebenszyklus, Keychain- und Dateifehler, Neustart-Recovery sowie den realen geschützten Dateizugriff im Simulatorcontainer.
- Zwölf synthetische UI-Szenarien bestanden jeweils auf iPhone und iPad unter iOS 26.5. Sie prüfen zusätzlich ungültige Eingabe, E-Mail, Prolific-ID, Sprachwechsel, laufenden Zustand, allgemeinen Fehler, Bestätigungstimeout, sicheren Speicherfehler, Recovery und eine bereits aktivierte App.
- Das vollständige Quality-Gate mit Debug-, Staging- und Release-Prüfung, sämtliche Domain-, Persistenz-, Netzwerk-, Notification- und Aktivierungsgates, Release-Analyze sowie der unsignierte Release-Gerätebuild bestanden.
- Ein signierter Staging-Build wurde als datenbewahrendes Update auf dem verbundenen iPhone installiert und erfolgreich gestartet.
- Automatisierte Aktivierungstests verwenden ausschließlich synthetische Kennungen und Test-Doubles. Es wurden keine produktiven oder Staging-Aktivierungsrequests ausgelöst und keine Teilnehmerkennungen, Tokens oder Serverdetails geloggt.

**Abweichungen, Annahmen und Review-Gate**

Die Datenflussmatrix begrenzt die Teilnehmerkennung strenger als der Android-Retry-Komfort; deshalb wird sie bei einem Fehler geleert und muss für einen Retry erneut eingegeben werden. Die geschützte Unklarheitsmarkierung konkretisiert den nicht vollständig spezifizierten Prozessabbruch beziehungsweise Keychainfehler nach möglicherweise erfolgreicher Serverbestätigung konservativ fail-closed.

Das menschliche Review-Gate bleibt ausstehend. Erforderlich sind je eine freigegebene, zurücksetzbare Staging-Testregistrierung für E-Mail und Prolific sowie eine kontrollierbare Simulation eines Timeouts beim zweiten Request. Ohne diese externen Voraussetzungen darf kein schreibender Aktivierungs-E2E-Test durchgeführt werden.
Freigabe erfolgt am 24.8.26

## 24.08.2026 – Auftrag 8

**Freigabe und Umfang**

Auftrag 7 wurde durch den datierten Vermerk ausdrücklich freigegeben. Auftrag 8 wurde auf Branch `codex/ios-auftrag-8` umgesetzt und umfasst die zustandsabhängige nichtproduktive Startseite, informative Datenschutz- und Rechtekontakte, die vollständig lokale Beispieldemo, das Feedbackformular sowie einen neutralen Abschlussplatzhalter.

**Implementierung**

- Die Startseite zeigt Aktivierung, Demo, Feedback und Informationslinks abhängig von Aktivierungs-, Abschluss- und Sicherheitszustand. Produktive Studienaktionen werden vor Auftrag 9 und 10 nicht als wirkungslose Platzhalter angeboten.
- Isolierte Tokenlese-, Aktivierungs-Recovery- oder Tokenspeicherfehler veröffentlichen einen eingeschränkten Home-Zustand: Aktivierung und produktive Nutzung bleiben fail-closed, während die nicht persistierende Demo und das getrennte Feedback erreichbar bleiben. Beschädigte Installation oder Studienpersistenz bleiben fatal.
- Die Demo führt über Cue-Matching, Cue-Labeling, Rauchverlangensslider und Abschluss. Sie nutzt ausschließlich die bytegleichen kanonischen Dateien `cue_000.png`, `cue_001.png`, `match_a_000.png` und `match_b_000.png`. Reihenfolgen werden injizierbar randomisiert und bleiben beim Sprachwechsel stabil.
- Der Matching-Countdown zählt fünf vollständig sichtbare Vordergrundsekunden. `.inactive` und `.background` brechen die aktuelle Warteoperation ab; bei Rückkehr wird mit dem unveränderten Restwert fortgesetzt.
- Demoauswahlen und der Wert des ganzzahligen Sliders `0...100` bleiben ausschließlich im flüchtigen AppModel und werden beim Verlassen verworfen. Es gibt keinen Token-, Netzwerk-, Datei-, Einstellungs- oder Notificationzugriff aus dem Demoablauf.
- `FeedbackCoordinator` serialisiert Übertragungen. Vor dem Request validiert `FeedbackDraft` mindestens ein belegtes Feld sowie 500 beziehungsweise 5.000 Unicode-Skalare. Das Payload besteht weiterhin ausschließlich aus `source`, `comment` und der tatsächlichen App-Version; Token, Teilnehmerkennung, Plattform, Gerät und Studienwert fehlen.
- Feedbackfehler erhalten das Formular innerhalb der Seite; Erfolg verwirft die Eingaben und zeigt die Dankesmeldung. Es wurde keine persistente Warteschlange ergänzt.
- Datenschutz-URLs werden als vollständige, buildkonfigurierte HTTPS-Allowlist ohne Credentials, Port, Query oder Fragment validiert. Der sprachabhängige Link wird über das Betriebssystem geöffnet. Der Rechtekontakt ist ausschließlich `mailto:cuelens@each-and-every.de` ohne vorbefüllten Betreff oder Body.
- Staging verwendet für diese beiden rein lesenden Informationslinks die produktiven HTTPS-Seiten. Alle schreibenden Staging-Endpunkte bleiben unverändert auf den freigegebenen lokalen Server begrenzt.

**Tests und technische Prüfung**

- 152 Unit-Tests bestanden unter iOS 26.5 und zusätzlich unter iOS 17.5. Neu geprüft werden Demo-Invarianten und Zustandsübergänge, genau fünf sichtbare Countdownsekunden, Hintergrundpause, stabiler Sprachwechsel, Feedbackgrenzen, Doppelaufrufschutz, Retry, Payload-Snapshot, Link-Allowlist, reiner `mailto:`-Kontakt und eingeschränkter Home-Zustand bei Tokenfehlern.
- 17 synthetische UI-Szenarien bestanden jeweils auf iPhone und iPad unter iOS 26.5. Sie decken Startseitenaktionen, den vollständigen deutschen und englischen Demoablauf, reale Fünf-Sekunden-Sperre, Demo-Neustart, Feedback-Erfolg und -Fehler, Abschlusszustand sowie Demo und Feedback bei Aktivierungsspeicherfehlern ab.
- Das vollständige Quality-Gate mit Debug-, Staging- und Release-Prüfung, sämtlichen Sicherheitsgates, Release-Analyze und generischem Release-Gerätebuild bestand. Die vier App-Bundle-Assets werden zusätzlich bytegleich gegen die Android-Referenz geprüft.
- Der zusätzliche signierte Installationsversuch auf dem verbundenen iPhone konnte nicht abgeschlossen werden, weil das gesperrte Gerät das Einhängen des Developer Disk Image abwies. Ein generischer signierter Build bleibt ohne die bewusst nicht eingecheckte lokale Development-Team-Zuordnung erwartungsgemäß ausgeschlossen; dies betrifft weder Simulator-, Analyze- noch unsignierte Gerätebuilds.
- Automatisierte Feedbacktests verwenden ausschließlich synthetische Test-Doubles. Es wurden keine Feedbacktexte an Produktion oder Staging gesendet und keine Teilnehmer-, Token- oder Gesundheitsdaten protokolliert.

**Abweichungen, Annahmen und Review-Gate**

Die vollständige globale Home-Matrix umfasst produktive Zustände, deren Abläufe erst Auftrag 9 und 10 implementieren. Auftrag 8 stellt dafür die erweiterbare Zustandsdarstellung bereit, zeigt jedoch keine Aktion ohne funktionsfähiges Ziel. Der Abschlussplatzhalter nennt nur den Abschlussstatus; Codeanzeige, Kopieraktion und Abschluss-Recovery bleiben Auftrag 10 vorbehalten.

Das menschliche Review-Gate bleibt ausstehend: fachliche Sichtprüfung aller deutschen und englischen Texte sowie der vier Demo-Reize auf iPhone und iPad. Ein echter Feedbackrequest ist für dieses Review nicht erforderlich.

## 24.08.2026 – Korrektur der Demo-Bilddarstellung

Die vier Demo-PNGs waren bytegleich im App-Bundle vorhanden, wurden durch SwiftUIs namensbasierten `Image`-Initialisierer in dieser Form der Ressourcenintegration jedoch nicht decodiert. Dadurch existierten die Bildelemente und ihre Layoutflächen, während Simulator und physisches Gerät nur leere Flächen darstellten.

Die Demo lädt die erlaubten PNG-Ressourcen nun explizit per Bundle-URL und übergibt das decodierte `UIImage` an SwiftUI. Ein Unit-Test prüft Dateiauflösung, Decodierung und die erwarteten Abmessungen aller vier kanonischen Demo-Bilder. Der bestehende vollständige UI-Ablauf prüft zusätzlich Mindestbreite und Mindesthöhe der gerenderten Cue- und Auswahlflächen. Ein diagnostischer iOS-17.5-Screenshot bestätigte nach der Korrektur die sichtbare Darstellung von Cue und beiden Matching-Bildern.

Freigabe erfolgt am 24.8.26

## 24.08.2026 – Auftrag 9

**Freigabe und Umfang**

Auftrag 8 wurde durch den datierten Vermerk und die erfolgreiche Sichtprüfung nach der Bildkorrektur freigegeben. Auftrag 9 wurde auf Branch `codex/ios-auftrag-9` als vollständig lokaler produktiver Durchgang umgesetzt. Entsprechend der vorab geklärten Testannahme bestätigen Debug und Staging die Situationen 1 bis 19 lokal mit drei Sekunden Cooldown; Situation 20 bleibt pending. Release bindet den Ablauf bis zur echten Übertragung aus Auftrag 10 fail-closed nicht ein.

**Implementierung**

- Das actor-gekapselte `BundleStudyContentRepository` lädt den kanonischen Content und das Assetmanifest höchstens einmal. Es validiert unbekannte Felder, Version und Hashalgorithmus, 50 Matching- und 50 Labeling-Items, 150 eindeutige Dateiverweise, Hashsyntax, Abmessungen sowie die tatsächliche Dekodierbarkeit aller Bilder. Ein fehlerhafter Inhalt sperrt den produktiven Start neutral.
- Alle 150 bytegleichen PNGs und beide JSON-Manifeste sind als App-Ressourcen eingebunden. Bilder werden per expliziter Bundle-URL geladen; der aktuelle Trial hält nur die aktuell verwendeten `UIImage`-Instanzen und keinen unbeschränkten eigenen Cache.
- Beim ersten produktiven Start wird eine vollständige Permutation `0...49` erzeugt, vor Nutzung als geschützter Studienzustand atomar persistiert und für die zehn Matching-Situationen in disjunkte Fünferblöcke geschnitten. Die zehn Labeling-Situationen verwenden die festgelegten Fünferblöcke in aufsteigender Reihenfolge.
- Jede der beiden Optionspositionen wird pro Trial durch ein neues Zufallsbit festgelegt. Sprachwechsel verändert die festgelegte Position nicht. Die konkrete Auswahl, Trialposition und Reaktionszeit werden weder persistiert noch an einen Service übergeben.
- Matching sperrt jede Auswahl für vier gezählte sichtbare Vordergrundsekunden. Inaktivität, Hintergrund und ungeeignete iPad-Geometrie pausieren den Countdown ohne Zeitnachholung. Nach genau fünf Trials folgt ein ganzzahliger Slider `0...100` mit Standardwert 50 und expliziter Sendeaktion.
- Vor jedem Fake-Serviceaufruf wird der Craving-Wert atomar als Pending gespeichert. Erst danach bestätigt der lokale Service Situationen 1 bis 19, entfernt Pending, erhöht den Zähler und setzt den buildkonfigurierten Cooldown in einem weiteren atomaren Zustandswechsel. Situation 20 verbleibt absichtlich pending; echter Retry, Serverantwort und Abschluss folgen in Auftrag 10.
- Die Vollbildoberfläche stellt den Cue zentriert mit `scaledToFill` dar, hält Cue und Optionen gleichzeitig sichtbar, zeigt Matching-Optionen vollständig mit `scaledToFit`, enthält keine suggestiven Bildbeschreibungen und hält den Sprachumschalter oben rechts erreichbar.

**Tests und technische Prüfung**

- 158 Unit-Tests bestanden unter iOS 26.5 und zusätzlich unter der Kompatibilitätsuntergrenze iOS 17.5. Neu geprüft werden vier sichtbare Sekunden pro Matching-Trial, exakt fünf Trials, disjunkte Matching-Slices, feste Labeling-Blöcke, Craving-Grenzen, persistierte Permutation, Pending vor Serviceaufruf, lokaler Fortschritt, Situation 20 pending, Cooldownkonfiguration und das Laden aller kanonischen Bundle-Ressourcen.
- 19 synthetische UI-Szenarien bestanden jeweils auf iPhone und iPad unter iOS 26.5. Die neuen Abläufe prüfen einen vollständigen Fünf-Trial-Matching-Durchgang mit Sperrzeit und Cooldown sowie einen vollständigen Fünf-Trial-Labeling-Durchgang mit Sprachwechsel.
- Das vollständige lokale Quality-Gate bestand einschließlich Debug- und Staging-Build, Release-Artefakt, sämtlicher Sicherheitsgates und erneuter kanonischer Prüfung von Byteidentität, SHA-256, 512-x-512-Abmessungen, JSON-Schemata und Querverweisen. Release-Analyze und ein unsignierter generischer Release-Gerätebuild waren ebenfalls erfolgreich.
- Die Runtime-Integration deckte zwei zunächst nicht zugelassene, aber kanonische Manifestfelder auf (`demo` und `hash_algorithm`). Die strikte Laufzeitvalidierung wurde daraufhin an das kanonische Schema angepasst und durch Bundle- und UI-Regressionstests abgesichert.
- Automatisierte Studienabläufe verwenden ausschließlich den lokalen Fake-Service. Es wurden keine Craving-Werte, Trialauswahlen, Teilnehmerkennungen oder Tokens an ein Backend übertragen oder protokolliert. Android, Backend und KI-PoC blieben unverändert.

**Abgrenzung und Review-Gate**

Der lokale Fake bildet bewusst keine echte Serversemantik nach. Pending-Retry beim App-Start, Submission-Payload, Responseparser, direkter beziehungsweise Prolific-Abschluss und der produktive dreistündige Fortschritt werden erst in Auftrag 10 aktiviert. Das Review-Gate bleibt daher die manuelle fachliche Sichtprüfung mehrerer vollständiger 20-Durchgang-Debugläufe auf iPhone und iPad; am Ende jedes Testlaufs ist der Pending-Zustand der 20. Situation erwartet.

Freigabe erfolgt am 24.8.26

## 24.08.2026 – Auftrag 10

**Freigabe und Umfang**

Auftrag 9 wurde durch den datierten Vermerk und die erfolgreiche Funktionsprüfung ausdrücklich freigegeben. Auftrag 10 wurde auf Branch `codex/ios-auftrag-10` umgesetzt und ersetzt den lokalen Fake-Service durch die reale, buildkonfigurierte Studienübertragung. Der Umfang umfasst den sicheren Pending-Retry, die serverbestätigte Fortschreibung, den direkten beziehungsweise Prolific-Abschluss und die zugehörige Abschlussdarstellung.

**Implementierung**

- `ProductiveStudyCoordinator` überträgt ausschließlich App-Token, ganzzahligen Craving-Wert und tatsächliche App-Version über den bestehenden `StudySubmissionService`. Vor dem ersten Request wird der Pending-Zustand atomar und dateigeschützt gespeichert; nach Fehler oder Prozessneustart wird exakt dieser Wert erneut übertragen.
- Nur eine strikt geparste Antwort für den erwarteten Situationsindex und die erwartete Bedingung darf den Fortschritt erhöhen. Unpassende, unvollständige oder unerwartete Antworten bleiben fail-closed im Pending-Zustand. Ein Actor verhindert parallele Doppelübertragungen.
- Situationen 1 bis 19 werden erst nach gültiger Serverantwort atomar bestätigt. Release setzt danach einen Cooldown von 10.800 Sekunden; Debug und Staging verwenden weiterhin drei Sekunden für kontrollierbare Tests. Reminder werden nach jedem bestätigten Zustandswechsel über die bestehende Reconcile-Schnittstelle aktualisiert.
- Bei direkter Teilnahme wird der Kompensationscode vor dem Bestätigungsrequest geschützt als ausstehende Bestätigung persistiert. Erst die erwartete leere 204-Antwort schaltet den Abschluss und die Codeanzeige frei. Ein Abbruch oder Neustart wiederholt ausschließlich die Bestätigung und niemals den Self-Report.
- Bei Prolific-Teilnahme wird ohne Code abgeschlossen und der spezifizierte Hinweis auf die Gutschrift innerhalb von zwei Tagen angezeigt. Beide Abschlussarten sperren weitere Studiensituationen dauerhaft.
- Der direkte Code kann nur über eine ausdrückliche Schaltfläche kopiert werden. Die lokale Zwischenablage ist auf das Gerät begrenzt und läuft nach zehn Minuten ab; automatische oder implizite Kopiervorgänge finden nicht statt.
- Netzwerk- und Protokollfehler zeigen einen neutralen Retry-Zustand. Ein fehlender App-Token oder nicht sicher lesbarer Studienzustand sperrt die produktive Nutzung fail-closed, ohne sensible Details anzuzeigen oder zu protokollieren.

**Tests und technische Prüfung**

- 166 Unit-Tests bestanden unter iOS 26.5 und zusätzlich unter der Kompatibilitätsuntergrenze iOS 17.5. Neu geprüft werden Pending-vor-Request, unveränderte Retry-Payloads, Fehlerpersistenz, falsche Serversemantik, dreistündiger Release-Cooldown, direkter Zweiphasenabschluss, Neustart zwischen Code und Bestätigung, Prolific-Abschluss, fehlender Token, Persistenzfehler und Schutz vor Doppelrequests.
- 23 synthetische UI-Szenarien bestanden jeweils auf iPhone und iPad unter iOS 26.5. Die neuen Szenarien prüfen fehlgeschlagene Übertragung mit manuellem Retry, direkten Abschluss einschließlich expliziter Kopieraktion, Prolific-Abschluss sowie eine fehlgeschlagene Codebestätigung mit Recovery.
- Das vollständige lokale Quality-Gate bestand einschließlich Debug-, Staging- und Release-Prüfung sowie sämtlicher Ressourcen-, Persistenz-, Netzwerk-, Notification- und Submission-Sicherheitsgates. Release-Analyze und ein unsignierter generischer Release-Gerätebuild waren ebenfalls erfolgreich.
- Automatisierte Tests verwenden ausschließlich synthetische Tokens, Werte, Codes und Service-Doubles. Es wurden keine produktiven oder Staging-Studienrequests ausgelöst und keine App-Tokens, Craving-Werte, Kompensationscodes oder Serverdetails protokolliert. Android, Backend und KI-PoC blieben unverändert.

**Annahmen und Review-Gate**

Der bestehende Backendvertrag und die bereits implementierte strikte Response-Decodierung wurden unverändert verwendet; es wurden weder Plattformfelder noch ein Versionssuffix oder neue Endpunkte ergänzt. Automatische Wiederherstellung erfolgt beim ersten aktiven App-Zustand vor der Freigabe einer neuen Situation. Bei einem ausstehenden direkten Abschluss hat die reine Codebestätigung Vorrang vor allen anderen Aktionen.

Das menschliche Review-Gate bleibt ausstehend. Erforderlich sind je eine freigegebene, zurücksetzbare Staging-Testregistrierung für direkten und Prolific-Abschluss sowie eine kontrollierte Netzwerkunterbrechung nach gespeichertem Self-Report und nach gespeichertem direkten Code. Dabei sind Fortschritt, Retry nach App-Neustart, serverseitige Duplikatfreiheit, dreisekündiger Staging-Cooldown und die Abschlussdarstellung zu prüfen. Ohne diese externen Voraussetzungen werden keine schreibenden E2E-Requests ausgeführt.

## 24.08.2026 – Korrektur der Cooldown-Persistenz

Nach einer erfolgreichen Self-Report-Antwort konnte der neu berechnete Cooldown-Zeitpunkt fälschlich als beschädigter lokaler Zustand bewertet werden. Das Domainmodell serialisiert Zeitpunkte in Millisekunden, hielt einen mit `Date()` erzeugten Wert im Speicher jedoch zunächst mit höherer Genauigkeit. Die schützende Schreibprüfung verglich die unmittelbar zurückgelesene Millisekundendarstellung exakt mit diesem höher aufgelösten Ausgangswert und brach deshalb fail-closed ab.

`StudyState` kanonisiert optionale Verfügbarkeitszeitpunkte nun bereits bei der Konstruktion auf die unverändert spezifizierte Millisekundenauflösung. Dadurch stimmen In-Memory-Zustand und persistierte Darstellung exakt überein; die atomare Schreib- und Rückleseprüfung wird nicht gelockert. Ein bereits vor dem Fehler gespeicherter Pending-Report bleibt unverändert erhalten. Da der Server Wiederholungen der Situationen 1 bis 19 nicht idempotent behandelt, muss eine durch diesen konkreten Fehler betroffene Testregistrierung vor einem erneuten Senden serverseitig geprüft und gegebenenfalls zurückgesetzt werden.

Drei Regressionstests prüfen die Domainkanonisierung, den geschützten Datei-Roundtrip und einen erfolgreichen Report mit realistischem Submillisekunden-Zeitstempel. Alle 169 Unit-Tests bestanden unter iOS 26.5 und iOS 17.5. Das vollständige Quality-Gate einschließlich Sicherheitsprüfungen, iPhone- und iPad-UI-Suiten sowie Release-Konfiguration bestand. Je ein fachfremder Aktivierungs-UI-Test war im ersten Simulatorlauf instabil und bestand im vom Gate vorgesehenen Wiederholungslauf. Es wurden keine Staging- oder Produktionsrequests ausgelöst.

Freigabe erfolgt am 24.8.26

## 24.08.2026 – Auftrag 11

**Freigabe und Umfang**

Auftrag 10 wurde durch den datierten Vermerk und den vollständig durchgespielten Studienablauf freigegeben. Auftrag 11 wurde auf Branch `codex/ios-auftrag-11` als systematische Sicherheits-, Datenschutz- und Accessibility-Härtung umgesetzt. Android, Backend, Studienparameter und Netzwerkverträge blieben unverändert.

**Datenschutz und Release-Härtung**

- Das Privacy Manifest deklariert konservativ E-Mail-Adresse, Benutzerkennung, Gesundheitsdaten und sonstige Nutzerinhalte. Sämtliche Kategorien sind ohne Tracking angegeben; auf eine Forschungs-Ausnahme für Gesundheitsdaten wird ohne im Repository nachgewiesenes Ethikvotum nicht zurückgegriffen. Required-Reason-Deklarationen für eigene Dateizeitstempel und App-Einstellungen bleiben erhalten.
- Die neue App-Store-Datenflussmatrix trennt App-Daten ausdrücklich von Daten des vorgelagerten Webformulars. Sie dokumentiert Quelle, Lebenszyklus, Übertragung, Zweck, Verknüpfbarkeit und Trackingstatus sowie die separat zu prüfenden technischen Servermetadaten.
- Ein zusätzliches Härtungsgate prüft Privacy Manifest, Trackingfreiheit, Datenkategorien, Logger-Quellen, erzwungene Swift-Operationen und verbotene Cloud-, HealthKit-, Werbe- und Tracking-APIs. Das vorhandene Release-Gate prüft zusätzlich die tatsächlich gebaute App auf ATS-Ausnahmen, unerlaubte Info.plist-Schlüssel und UI-Test-/Stagingreste.
- `verify_release_archive.sh` prüft ein signiertes Distributionsarchiv auf Signatur, Bundle-ID, Privacy Manifest, Debugberechtigung, iCloud, App Groups, HealthKit, Network Extensions, Push sowie Debug-/Staging-Inhalte. Die verbleibenden manuellen Entitlement-, Datenschutz-, Gerätesperr- und App-Switcher-Prüfungen sind in einer eigenen Review-Checkliste festgehalten.
- Die Simulatorauswahl bevorzugt auf der neuesten Runtime ein reguläres iPhone-Pro-Modell und das kleinste aktuelle iPad. Damit werden Xcode-Runner-Probleme des iPhone-Air-Simulators vermieden und zugleich der strengere adaptive iPad-Layoutfall geprüft.

**Accessibility und Darstellung**

- Die CueLens-Palette bleibt in hellem und dunklem Systemmodus identisch. Fest definierte sRGB-Werte erfüllen für Primär-, Sekundär-, Fehler- und Buttontexte mindestens das WCAG-AA-Kontrastverhältnis 4,5:1; dies wird als Unit-Test gesichert.
- Allgemeine Seiten und Formulare sind bei großen Accessibility-Schriftgrößen scrollbar und breitenbegrenzt. Primäraktionen und Sprachumschaltung besitzen mindestens 44 × 44 Punkte; Labeling-Aktionen wechseln bei Platzmangel von horizontaler zu vertikaler Anordnung.
- Fehler-, Support- und Erfolgsmeldungen übernehmen nach Zustandswechsel den Accessibility-Fokus. Der Privacy Curtain entfernt die verdeckte Oberfläche aus dem Accessibility-Baum.
- Demo- und produktive Craving-Slider werden mit eindeutiger Bezeichnung und ganzzahligem Wert vorgelesen; der separate visuelle Zahlenwert ist zur Vermeidung doppelter Ansagen ausgeblendet.
- Produktive Matching-Bilder erhalten ausschließlich die neutralen Bezeichnungen „erste“ beziehungsweise „zweite Bildoption“ und einen verständlichen Trial-Fortschritt. Es werden keine reizbezogenen oder suggestiven Beschreibungen ergänzt.

**Tests und technische Prüfung**

- 170 Unit-Tests bestanden unter iOS 26.5 und zusätzlich unter der Kompatibilitätsuntergrenze iOS 17.5. Die neue Kontrastprüfung ergänzt die bestehenden Netzwerk-, Persistenz-, Permission-, Recovery-, Pending- und Retry-Fehlerinjektionen.
- Je 25 synthetische UI-Szenarien bestanden auf iPhone 17 Pro und iPad mini unter iOS 26.5. Neu geprüft werden maximale Accessibility-Schriftgröße, Erreichbarkeit der Kernformulare, Apples automatisierter Audit für Kontrast, Elementerkennung und Touchflächen sowie die neutralen Bild- und Sliderbezeichnungen.
- Das vollständige lokale Quality-Gate bestand einschließlich Debug-, Staging- und Release-Build, sämtlichen Domain-, Persistenz-, Netzwerk-, Notification-, Aktivierungs-, Ressourcen-, Submission-, Privacy- und Härtungsgates.
- Xcode Analyze für Release und ein unsignierter generischer Release-Gerätebuild bestanden mit Warnungen-als-Fehler. Property Lists, String Catalog, Projektdatei und Shellskripte wurden zusätzlich syntaktisch geprüft.
- Alle Tests verwenden synthetische Daten und Test-Doubles. Es wurden keine schreibenden Staging- oder Produktionsrequests ausgelöst und keine Teilnehmerkennungen, Tokens, Gesundheitswerte oder Kompensationscodes protokolliert.

**Abgrenzung und Review-Gate**

Automatisch sind keine kritischen oder hohen offenen Befunde bekannt. Die spezifizierte Vier-Augen-Prüfung der Datenschutzmatrix und die manuelle Security-/Accessibility-Checkliste auf einem gültig signierten Release-Archiv bleiben das Review-Gate von Auftrag 11. Dazu gehören der Abgleich mit App Store Connect und realer Serverkonfiguration, VoiceOver in Deutsch und Englisch auf einem physischen Gerät, Gerätesperre, App-Switcher, Neuinstallation, Benachrichtigungsentzug und die Prüfung der Distribution-Signatur. Ohne lokale Distribution-Identität wurde kein signiertes Archiv erzeugt oder als geprüft ausgegeben.

## 24.08.2026 – Auftrag 12 – Releasevorbereitung

**Umfang und Source Candidate**

Auftrag 12 wurde auf Branch `codex/ios-auftrag-12` als reproduzierbares Release- und Evidenzpaket vorbereitet. Der unveränderte, vollständig geprüfte Source Candidate ist Auftrag-11-Commit `e66270a93a74fa435af03a8b2054f8f8738756cf`, App-Version `1.0.0`, Build `1`, Release-Konfiguration mit iOS-Mindestversion 17.0 und dreistündigem Cooldown. Eine bereits im Arbeitsbaum vorhandene, nicht zu Auftrag 12 gehörende automatische Xcode-Änderung am String Catalog wurde weder überschrieben noch in den Source Candidate aufgenommen.

**Release- und Studiennachweise**

- Das maschinenlesbare Release-Manifest fixiert Commit, Xcode 26.6 (17F113), Swift 6.3.3, macOS-Build, Version, Buildnummer, Bundle-ID, Konfiguration, Spezifikations- und Content-Hashes sowie die realen automatisierten Testergebnisse.
- Eine vollständige Matrix ordnet IOS-FUN-001 bis IOS-FUN-035 jeweils Produktionsimplementierung und mindestens einem automatisierten Nachweis zu. Ein separater DoD-Audit bewertet alle zehn Bereiche der Definition of Done und trennt Repositorynachweise von manuellen und externen Gates.
- Implementierte Architektur, Datenschutzdatenflüsse, Known Issues, formale Freigabecheckliste, ein datensparsames 14-Tage-Testprotokoll, TestFlight-/App-Review-Texte sowie ein Register für Ethik- und Studiennachweise wurden dokumentiert.
- `verify_release_documentation.sh` validiert Vollständigkeit, alle 35 Traceability-IDs, Git-Commit, Hashes, Appparameter, Testzahlen und den weiterhin blockierten Status. `verify_release_candidate.sh` verlangt einen unveränderten getrackten Arbeitsbaum, wiederholt Quality-Gate und Release Analyze und akzeptiert ausschließlich ein bestandenes Distribution-Archiv.
- Die aktuellen Apple-Vorgaben für TestFlight-Testinformationen, App Privacy, Reviewzugang und gesundheitsbezogene Forschung wurden am 24.08.2026 gegen offizielle Apple-Dokumentation geprüft. App-Texte vermeiden Therapie-, Diagnose- und Wirksamkeitsversprechen.

**Technische Prüfung**

Aus dem sauberen Source Candidate wurde mit der lokal vorhandenen Apple-Development-Identität ein signiertes Release-Archiv einschließlich dSYM erzeugt. Bundle-ID, Version, Build und Mindest-iOS stimmen. Das Archivgate wies es korrekt wegen `get-task-allow=true` zurück; es ist damit kein Distribution- oder TestFlight-Artefakt. Eine Distribution-Identität war lokal nicht vorhanden. Es erfolgte kein Upload und keine Einladung von Testpersonen.

Die bereits nachgewiesene Regression umfasst 170 Unit-Tests unter iOS 26.5 und iOS 17.5 sowie je 25 UI-Szenarien auf iPhone und iPad, Release Analyze, generischen Gerätebuild und das vollständige Quality-Gate. Das Gate wurde um die Release-Dokumentationsprüfung erweitert.

Im abschließenden erweiterten Gate bestanden beide UI-Suiten im vorgesehenen vollständigen Wiederholungslauf. Auf dem iPhone war im ersten Lauf ausschließlich `testActivationAcceptsProlificIDAndSwitchesLanguage`, auf dem iPad ausschließlich `testActivationDistinguishesGeneralFailureAndConfirmationTimeout` mit einem unspezifischen `XCTAssertTrue` instabil; jeweils 24 von 25 Szenarien bestanden bereits im ersten Lauf. Beide kompletten Wiederholungsläufe bestanden mit 25 von 25 Szenarien. Es gab keinen reproduzierbaren Produktfehler und keine Änderung am Aktivierungscode in Auftrag 12.

**Offene Release-Gates**

Auftrag 12 ist vorbereitet, aber nicht formal abgeschlossen. Release-blockierend bleiben unabhängiger Ethiknachweis und Einwilligungsunterlagen, Vier-Augen-Abgleich der Datenschutzmatrix mit Server und App Store Connect, Distribution-Signatur und Upload, TestFlight auf mindestens zwei realen Geräten, synthetische direkte und Prolific-Staging-Abschlüsse, der tatsächliche 14-Tage-Langzeittest sowie die datierte formale Freigabe. Diese Punkte erfordern Zeit, externe Systeme beziehungsweise fachliche Autorität und wurden deshalb nicht simuliert oder als bestanden markiert.
