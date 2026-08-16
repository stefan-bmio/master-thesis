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

Vorausgesetzt werden Xcode 26.6 (Build 17F113), Swift 6.3.3 und eine installierte iOS-Simulator-Runtime. Das Projekt hat ein Deployment Target von iOS/iPadOS 17.0, verwendet keine Drittanbieterabhängigkeiten und trennt `Debug`, `Staging` und `Release` über eingecheckte `.xcconfig`-Dateien. Debug und Staging verwenden absichtlich nicht routbare `.invalid`-Endpunkte.

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

Die buildabhängigen Endpunkte werden aus den `.xcconfig`-Dateien in die eingecheckte minimale `Info.plist` expandiert. Debug und Staging bleiben nicht routbar; ausschließlich Release enthält die produktiven HTTPS-Endpunkte. Auftrag 4 stellt die Services bereit, beginnt aber noch keine produktiven Netzwerkrequests aus der App-Oberfläche.

## Datenschutz und Abgrenzung

Dieses Verzeichnis darf keine echten Teilnehmendenkennungen, App-Tokens oder Gesundheitsdaten enthalten. Domain und SwiftUI-Views enthalten keine direkten Keychain- oder Dateizugriffe; sichere lokale Zugriffe sind ausschließlich in der Infrastruktur gekapselt.
