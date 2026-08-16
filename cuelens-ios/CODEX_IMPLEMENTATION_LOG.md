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
Ausstehend; vor Beginn von Auftrag 5 ist das Review-Gate freizugeben.
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
Ausstehend; vor Beginn von Auftrag 6 ist das Review-Gate freizugeben.

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
