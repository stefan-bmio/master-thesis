# CueLens iOS

Dieses Verzeichnis enthält die eigenständige native iOS-Portierung der CueLens-Studien-App. Das bestehende Android-Studio-Projekt liegt unverändert im Geschwisterverzeichnis `../cuelens/`.

## Verbindliche Grundlagen

- `PLATFORM_INDEPENDENT_SPECIFICATION.md`: fachliche, studienmethodische, datenschutzbezogene und sicherheitstechnische Sollfunktion.
- `IOS_ARCHITECTURE_AND_IMPLEMENTATION_PLAN.md`: native iOS-Architektur, Auftragsreihenfolge und Abnahmekriterien.
- Android-Referenz für Auftrag 0: `main`, Commit `9ef5f38ee341a0f59a1b2844773c8cadc8a807c2`.

## Studienressourcen

`Resources/Study/Assets/` enthält bytegleiche Kopien der 50 Cue-, 50 Match-A- und 50 Match-B-PNGs aus `../cuelens/app/src/main/res/drawable/`. Die Android-App verwendet weiterhin ihre eigenen Dateien. Hashes und Abmessungen stehen im Assetmanifest; Label- und Matching-Zuordnungen stehen im Contentmanifest.

Die Verzeichnisse `../cuelens/grouped/` und `../AI_PoC/` sind ausdrücklich keine Quellen für die iOS-Studienressourcen.

## Ressourcenprüfung aus Auftrag 0

```sh
cd cuelens-ios
python3 -m venv .venv
.venv/bin/python -m pip install -r Tools/requirements-dev.txt
.venv/bin/python Tools/generate_study_resources.py --check
.venv/bin/python Tools/verify_study_resources.py
```

Ohne `--check` erzeugt beziehungsweise aktualisiert der Generator die bytegleichen Kopien und die beiden JSON-Manifeste deterministisch. Nach der Erzeugung muss ein erneuter Lauf mit `--check` erfolgreich sein.

## Xcode-Projekt und lokales Quality-Gate aus Auftrag 1

Vorausgesetzt werden Xcode 26.6 (Build 17F113), Swift 6.3.3 und eine installierte iOS-Simulator-Runtime. Das Projekt hat ein Deployment Target von iOS/iPadOS 17.0, verwendet keine Drittanbieterabhängigkeiten und trennt `Debug`, `Staging` und `Release` über eingecheckte `.xcconfig`-Dateien. Debug verwendet absichtlich nicht routbare `.invalid`-Endpunkte. Staging verwendet das freigegebene lokale Testsystem; lokale HTTP-Verbindungen sind dort eng auf private Ziele begrenzt. Release bleibt ausschließlich HTTPS.

```sh
cd cuelens-ios
open CueLens.xcodeproj
./Scripts/quality_gate.sh
```

Das Gate prüft zuerst die technische Grenze des Pure-Swift-Domain-Moduls sowie Persistenz- und Netzwerk-Sicherheitsinvarianten, baut Debug und Staging, führt alle Unit-Tests und je einen UI-Smoke-Test auf einem verfügbaren iPhone- und iPad-Simulator aus und prüft das Release-Artefakt einschließlich Bundle ID, Mindestversion, Endpunktkonfiguration, Privacy Manifest, Ausrichtungen, verbotener Berechtigungsschlüssel, Abhängigkeiten und Compilerkonfiguration. Die Simulatoren werden deterministisch aus der neuesten installierten iOS-Runtime gewählt. Bei einer frisch installierten Runtime darf die einmalige System- und Accessibility-Initialisierung mehrere Minuten dauern; das Gate wiederholt ausschließlich einen dadurch fehlgeschlagenen UI-Smoke-Test genau einmal.

Die Kompatibilitätsuntergrenze wurde zusätzlich mit der installierten iOS-17.5-Runtime (Build 21F79) auf iPhone und iPad geprüft. Die aktuelle Testobergrenze ist iOS 26.5 (Build 23F77).

Für ein signiertes Release-Archiv wird `Config/LocalSigning.xcconfig.example` nach `Config/LocalSigning.xcconfig` kopiert und dort die lokale Apple-Team-ID eingetragen. Diese Datei bleibt ignoriert; Zertifikate und Provisioning Profiles werden nicht versioniert. Ohne Apple-Development- oder Distribution-Identität sind Simulator-Builds, Tests, Analyze und ein unsigniertes Gerätearchiv möglich, aber kein installierbares signiertes Release-Archiv.

## Reines Domain-Modul aus Auftrag 2

`CueLens/Domain/` enthält Zustände, Werttypen, Invarianten, Studienregeln und strikte Response-Parser ohne UI-, Netzwerk-, Keychain- oder Benachrichtigungsabhängigkeit. Es bleibt zur Vermeidung unnötiger Build-Komplexität ein logisch abgegrenzter Quellbereich im App-Target. Seine technische Unabhängigkeit lässt sich separat prüfen:

```sh
./Scripts/verify_domain_boundaries.sh
```

Die synthetischen JSON-Fixtures unter `Fixtures/messages/` und `Fixtures/submission/` decken gültige und ungültige Protokollantworten ab. Sie enthalten keine realen Teilnehmenden- oder Gesundheitsdaten.

## Sichere Persistenz aus Auftrag 3

Der App-Token liegt ausschließlich als nicht synchronisierbares Generic Password mit `WhenUnlockedThisDeviceOnly` im Keychain. Ein geschützter 32-Byte-Installationsmarker verhindert die unkontrollierte Wiederverwendung eines nach einer Neuinstallation verbliebenen Tokens. Der kleine Studienzustand wird deterministisch, atomar, vollständig dateigeschützt und aus Backups ausgeschlossen unter `Library/Application Support/CueLens/` gespeichert. Die App prüft diese Infrastruktur beim Start und bleibt bei Integritäts- oder Speicherfehlern fail-closed.

Das Privacy Manifest deklariert den Apple-Grund `C617.1`, weil die Schutzprüfung ausschließlich Metadaten der eigenen Dateien im App-Container liest. Das Release-Gate prüft diese Deklaration mit.

```sh
./Scripts/verify_persistence_security.sh
```

CoreSimulator bestätigt Keychain-Roundtrips und Backup-Ausschlüsse, meldet jedoch keine verlässliche effektive Data-Protection-Klasse. Gerätesperre, Update und Neuinstallation müssen deshalb zusätzlich auf einem echten Gerät geprüft werden.

## Netzwerkbasis aus Auftrag 4

`CueLens/Infrastructure/Network/` enthält den zentralen ephemeren `URLSession`-Client und die typisierten Services für Aktivierung, Informationsfeed, Feature-Konfiguration, Feedback und Studiensubmission. Sämtliche Redirects werden abgelehnt, Antworten während des Empfangs größenbegrenzt und fachliche JSON-Antworten strikt validiert. Der Logger erhält ausschließlich abstrakten Requesttyp, Status und technische Fehlerkategorie.

```sh
./Scripts/verify_network_security.sh
```

Die buildabhängigen Endpunkte werden aus den `.xcconfig`-Dateien in die eingecheckten minimalen Property Lists expandiert. Konfigurationsloader und HTTP-Client erzwingen gemeinsam dieselbe Transportpolicy. Debug bleibt nicht routbar, Staging darf nach der systemseitigen Local-Network-Privacy-Freigabe das freigegebene private LAN-Testsystem verwenden und ausschließlich Release enthält die produktiven HTTPS-Endpunkte. Auftrag 4 stellt die Services bereit, beginnt aber noch keine produktiven Schreibrequests aus der App-Oberfläche.

## App-Shell und Informationsfeed aus Auftrag 5

Der App-Start lädt Sprache und unkritische Einstellungen, validiert den geschützten Studienzustand und ruft anschließend im aktiven Vordergrund den Informationsfeed ab. Nachrichten werden sortiert als einzelne Seiten angezeigt. Dauerhaft gespeichert werden ausschließlich positive ausgeblendete beziehungsweise bekannte IDs, niemals Nachrichtentexte. Feedfehler führen zu einem neutralen Hinweis, blockieren die Startseite aber nicht.

Deutsch und Englisch lassen sich ohne Neustart umschalten; die Auswahl bleibt in `UserDefaults` erhalten. Das Privacy Manifest deklariert dafür den Apple-Grund `CA92.1` für ausschließlich app-eigene Einstellungen. Bei inaktiver oder im Hintergrund befindlicher App verdeckt ein undurchsichtiger Privacy Curtain die gesamte Oberfläche. Die erweiterten UI-Tests verwenden synthetische Debug-Feeds und lösen keine Backendrequests aus.

```sh
./Scripts/verify_staging_configuration.sh
```

Die Oberfläche verwendet die festgelegte CueLens-Farbpalette unabhängig von der iOS-Systemdarstellung. Dadurch bleiben insbesondere Nachrichtentexte auch bei aktiviertem dunklem Systemmodus dunkel und auf dem hellen Hintergrund lesbar.

## Optionale Benachrichtigungen aus Auftrag 6

Nach einem erfolgreichen ersten Feedabschluss zeigt die App genau einmal einen eigenen Benachrichtigungsdialog. Nur bei aktivierter Option folgt die iOS-Systemanfrage; Ablehnung oder ein späterer Entzug beeinträchtigen die Kernfunktionen nicht. Die lokal gespeicherte Einstellung gilt gemeinsam für generische Hinweise auf neue Informationen und Studienerinnerungen.

`NotificationCoordinator` verwendet ausschließlich Alert-Benachrichtigungen ohne Ton, Badge, sensible Nutzdaten oder Push-Registrierung. Studienerinnerungen besitzen deterministische Kennungen und werden nur für einen fachlich zulässigen, aktivierten Studienzustand geplant. Sprachwechsel ersetzen eine ausstehende Erinnerung, deaktivierte Berechtigungen oder nicht zulässige Zustände entfernen sie. Das Öffnen einer Erinnerung führt nur zur Startseite; das Öffnen eines Informationshinweises lädt den Feed erneut.

Die best-effort Hintergrundprüfung nutzt `BGAppRefreshTask` ungefähr täglich. Ihr tatsächlicher Ausführungszeitpunkt wird von iOS bestimmt; der Feedabruf beim Aktivieren der App bleibt deshalb autoritativ. Die produktive Studienzustandsanbindung für Erinnerungen erfolgt über den bereits implementierten Reconcile-Einstieg, sobald Aktivierung und Studiendurchführung in den Folgeaufträgen verfügbar sind.

```sh
./Scripts/verify_notification_security.sh
```

## Sichere Aktivierung aus Auftrag 7

Nicht aktivierte Apps bieten eine deutsch/englisch lokalisierte Aktivierungsseite für eine syntaktisch gültige E-Mail-Adresse oder eine 24-stellige alphanumerische Prolific-ID. Ein actor-gekapselter Koordinator führt exakt einen zweistufigen Handshake aus. Der vom ersten Request gelieferte UUID-v4-Token bleibt flüchtig und wird erst nach der erfolgreichen `204`-Bestätigung im gerätegebundenen Keychain gespeichert. Eingaben werden weder in `UserDefaults` noch in Dateien oder Logs übernommen und nach Abschluss beziehungsweise Fehler aus dem AppModel entfernt.

Vor der Bestätigung wird ein inhaltlich neutraler Marker vollständig dateigeschützt und vom Backup ausgeschlossen gespeichert. Bei Bestätigungstimeout, Prozessabbruch oder Keychainfehler wird eine möglicherweise widersprüchliche erneute Aktivierung sowohl im laufenden Prozess als auch nach dem nächsten Start verhindert. Ein bereits sicher vorhandener Token hat Vorrang und bereinigt einen verbliebenen Marker. Allgemeine Fehler bleiben wiederholbar; ein Timeout im Bestätigungsschritt führt zum Supporthinweis.

```sh
./Scripts/verify_activation_security.sh
```

Die automatisierten Aktivierungsszenarien verwenden ausschließlich synthetische Test-Doubles und erzeugen keine Backendrequests. Das Staging-Review benötigt deshalb weiterhin je eine freigegebene, zurücksetzbare E-Mail- und Prolific-Testregistrierung sowie eine kontrollierbare Simulation des Bestätigungstimeouts.

## Startseite, lokale Demo und Feedback aus Auftrag 8

Die zustandsabhängige Startseite bietet Aktivierung, Demo und Feedback vor Studienabschluss sowie Feedback auch nach Abschluss an. Ein isolierter Token- oder Aktivierungs-Recoveryfehler sperrt Aktivierung und produktive Nutzung fail-closed, lässt die rein lokale Demo und das getrennte Feedback jedoch erreichbar.

Die Demo verwendet ausschließlich die vier unveränderten kanonischen Assets `cue_000`, `cue_001`, `match_a_000` und `match_b_000`. Auswahlreihenfolgen werden einmal je Schritt zufällig festgelegt. Der fünfsekündige Matching-Countdown zählt nur sichtbare Vordergrundzeit; Auswahl, Label und Rauchverlangenswert werden beim Verlassen vollständig verworfen und weder gespeichert noch übertragen.

Feedback wird vor dem Request als `FeedbackDraft` auf 500 beziehungsweise 5.000 Unicode-Skalare validiert. Der serialisierte Request enthält ausschließlich die belegten Felder `source`, `comment` und die unveränderte App-Version. Fehler erhalten das flüchtige Formular für einen manuellen Retry; Erfolg verwirft es. Datenschutzlinks werden sprachabhängig aus der Build-Konfiguration ausgewählt, ausschließlich als HTTPS-Allowlist geöffnet und der Rechtekontakt verwendet ein nicht vorbefülltes `mailto:`.

```sh
./Scripts/verify_prestudy_security.sh
```

## Lokaler produktiver Studienablauf aus Auftrag 9

Debug und Staging laden die beiden kanonischen JSON-Manifeste einmalig und validieren deren Struktur, Version, vollständige Itemmengen sowie alle 150 dekodierbaren 512-x-512-PNGs. Situationen 1 bis 10 verwenden eine einmal persistierte Permutation aller 50 Matching-Items in Blöcken zu fünf. Situationen 11 bis 20 verwenden die festgelegten aufeinanderfolgenden Labeling-Blöcke. Die Optionsposition wird je Trial neu zufällig festgelegt; die konkrete Auswahl bleibt ausschließlich flüchtig und wird weder gespeichert noch übertragen.

Jeder Matching-Trial sperrt die Auswahl für vier sichtbare Vordergrundsekunden. Nach exakt fünf Trials folgt der ganzzahlige Rauchverlangensslider von 0 bis 100 mit Standardwert 50. Auftrag 9 verwendete für die isolierte Ablaufprüfung zunächst einen lokalen Fake-Service; Auftrag 10 ersetzt ihn in allen regulären Buildvarianten durch den bestehenden Submission-Vertrag.

```sh
./Scripts/verify_productive_study_security.sh
```

Ein Prozessabbruch vor dem Absenden persistiert weder Trialposition noch Auswahl und beginnt den unbestätigten Durchgang erneut. Die produktive Oberfläche verwendet zentriertes `scaledToFill`, vollständige Auswahlbilder, sprachstabile Zufallspositionen und den bestehenden Sichtschutz.

## Submission, Recovery und Abschluss aus Auftrag 10

Vor dem ersten Submission-Request wird ausschließlich der ganzzahlige Craving-Wert atomar im geschützten Studienzustand als Pending gespeichert. Der Request liest den UUID-v4-App-Token erst aus dem Keychain und enthält genau `app_token`, `craving` und die unveränderte `app_version`; Situation, Bedingung, Auswahl, Sprache und Plattform werden nicht gesendet. Der bestehende strikte Parser prüft Erfolg, ganzzahligen erwarteten Situationindex, zugehörige Bedingung und Abschlusskombination, bevor lokaler Fortschritt verändert wird.

Ein Pending-Wert blockiert neue Durchgänge, wird beim nächsten aktiven App-Start automatisch erneut gesendet und bleibt nach Netzwerk- oder Protokollfehler für einen manuellen Retry erhalten. Situationen 1 bis 19 erhalten erst nach gültiger Antwort einen atomar persistierten Fortschritt und den buildkonfigurierten Cooldown von drei Stunden in Release beziehungsweise drei Sekunden in Debug und Staging. Der Reminderabgleich erfolgt nach jeder Zustandsänderung.

Beim direkten Abschluss wird der UUID-v4-Kompensationscode zunächst als ausstehende Bestätigung geschützt persistiert. Erst danach erfolgt der separate PUT, der exakt HTTP 204 ohne Body erfordert. Ein Bestätigungsfehler erhält den verborgenen Code für den Retry; erst der bestätigte Abschluss zeigt ihn an. Die Zwischenablage wird ausschließlich nach dem sichtbaren Kopier-Tap gesetzt. Der Prolific-Abschluss speichert keinen Code und zeigt stattdessen den spezifizierten Zwei-Tage-Hinweis. Feedback bleibt in beiden Abschlussmodi erreichbar.

```sh
./Scripts/verify_submission_security.sh
```

## Sicherheits-, Datenschutz- und Accessibility-Härtung aus Auftrag 11

Das konservative Privacy Manifest deklariert die durch die App übertragenen Kategorien E-Mail-Adresse, Benutzerkennung, Gesundheitsdaten und sonstige Nutzerinhalte ohne Tracking. Die zugehörige [App-Store-Datenflussmatrix](Documentation/APP_PRIVACY_DATA_FLOW_MATRIX.md) trennt App-Daten von Angaben des vorgelagerten Webformulars. Vor der Einreichung müssen Matrix und App-Store-Connect-Angaben im Vier-Augen-Prinzip gegen die reale Serverkonfiguration geprüft werden.

Die Oberfläche verwendet in hellem und dunklem Systemmodus dieselbe kontrastgeprüfte Palette. Allgemeine Formulare sind bei maximaler Accessibility-Schriftgröße scrollbar, Statusmeldungen übernehmen den VoiceOver-Fokus und Studienbilder werden ausschließlich als neutrale erste beziehungsweise zweite Bildoption bezeichnet. Der sichtbare Sliderwert wird für VoiceOver genau einmal mit fachlicher Bezeichnung ausgegeben.

```sh
./Scripts/verify_hardening_security.sh
./Scripts/quality_gate.sh
xcodebuild -project CueLens.xcodeproj -scheme CueLens -configuration Release \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO analyze
./Scripts/verify_release_archive.sh /path/to/CueLens.xcarchive
```

Das letzte Skript ist absichtlich ein Gate für ein signiertes Distributionsarchiv. Es prüft Signatur, Bundle, Privacy Manifest, unerlaubte Entitlements und Debug-/Staging-Reste; die ergänzenden manuellen Prüfungen stehen in [Security-, Datenschutz- und Accessibility-Review](Documentation/SECURITY_ACCESSIBILITY_REVIEW_CHECKLIST.md).

## Datenschutz und Abgrenzung

Dieses Verzeichnis darf keine echten Teilnehmendenkennungen, App-Tokens oder Gesundheitsdaten enthalten. Domain und SwiftUI-Views enthalten keine direkten Keychain- oder Dateizugriffe; sichere lokale Zugriffe sind ausschließlich in der Infrastruktur gekapselt.
