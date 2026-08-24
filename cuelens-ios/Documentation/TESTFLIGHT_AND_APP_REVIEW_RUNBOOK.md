# CueLens iOS – TestFlight- und App-Review-Runbook

Stand: 24.08.2026. Die Schritte orientieren sich an den aktuellen offiziellen Apple-Unterlagen zu [TestFlight](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview), [App Privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/) und [App Review](https://developer.apple.com/app-store/review/).

## 1. Freigabevoraussetzungen

- Source Commit und Buildnummer sind im Release-Manifest fixiert.
- `quality_gate.sh`, Release Analyze und `verify_release_documentation.sh` sind grün.
- unabhängiges Ethikvotum und Einwilligungsunterlagen sind im Evidence Register als geprüft markiert;
- Datenschutzmatrix ist mit Hosting-/Serveraufbewahrung und App Store Connect abgeglichen;
- Apple-Distribution-Signatur, App-ID und Provisioning sind verfügbar;
- keine echten Kennungen oder Secrets befinden sich in Repository, Reviewnotizen oder Screenshots.

## 2. Archiv und Upload

```sh
xcodebuild -project CueLens.xcodeproj \
  -scheme CueLens \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$PWD/build/CueLens.xcarchive" \
  archive

./Scripts/verify_release_archive.sh "$PWD/build/CueLens.xcarchive"
```

Der Export beziehungsweise Upload erfolgt erst nach bestandenem Archivgate über Xcode Organizer oder eine lokal gepflegte, nicht eingecheckte App-Store-Connect-Konfiguration. Zugangsdaten, API-Schlüssel, ExportOptions mit Teamdaten und Provisioning Profiles werden nicht versioniert. Nach Upload sind Buildnummer, Processing-Status und Export-Compliance-Entscheidung im Releaseprotokoll festzuhalten.

Für den automatischen Export kann `Config/ExportOptions-AppStore.example.plist` in eine ignorierte lokale Datei kopiert und bei Bedarf um nicht versionierte Team-/Provisioningangaben ergänzt werden:

```sh
xcodebuild -exportArchive \
  -archivePath "$PWD/build/CueLens.xcarchive" \
  -exportOptionsPlist "$PWD/Config/ExportOptions-AppStore.local.plist" \
  -exportPath "$PWD/build/export"
```

## 3. TestFlight-Testinformationen

### Beta-Beschreibung Deutsch

CueLens ist eine Studien-App zur Untersuchung des Benennens alltäglicher Rauchreize. Die App richtet sich ausschließlich an vorab registrierte Studienteilnehmende. Sie ist kein Medizinprodukt, stellt keine Diagnose und ersetzt keine medizinische oder therapeutische Beratung.

### Beta Description English

CueLens is a research app studying the labeling of everyday smoking cues. Access is limited to participants registered in advance. The app is not a medical device, does not provide a diagnosis, and does not replace medical or therapeutic advice.

### Zu testen / What to test

- Aktivierung mit der über einen sicheren Kanal bereitgestellten synthetischen Testkennung;
- Informationsfeed, Sprachwechsel und optionale Benachrichtigungen;
- Demo ohne Datenübertragung;
- produktiver Ablauf, Cooldown, Pending-Retry und App-Neustart;
- direkter beziehungsweise Prolific-Abschluss entsprechend der Testregistrierung;
- App-Switcher-Sichtschutz, VoiceOver und große Schrift;
- Feedback nur mit synthetischem Inhalt.

Feedbackkontakt: `cuelens@each-and-every.de`.

## 4. Geräte- und Abschlussmatrix

| Build | Gerät | iOS/iPadOS | Registrierung | Abschluss | Pending-Retry | Notifications | Ergebnis |
|---|---|---|---|---|---|---|---|
| `[ausstehend]` | reales Gerät 1 |  | direkt |  |  |  |  |
| `[ausstehend]` | reales Gerät 2 |  | Prolific |  |  |  |  |

Ein Simulatorlauf zählt nicht als TestFlight-Gerätetest. Beide Zeilen müssen vor der formalen Freigabe bestanden sein.

## 5. App-Review-Unterlagen

### Kurzbeschreibung Deutsch

Studien-App zur Untersuchung von Cue-Labeling bei Rauchverlangen im Alltag.

### Short description English

Research app investigating cue labeling for smoking craving in everyday life.

### Reviewhinweise

- Zugriff ist auf vorab registrierte Studienteilnehmende beschränkt.
- Eine gültige synthetische Reviewkennung wird ausschließlich im geschützten App-Review-Informationsfeld bereitgestellt, niemals im Repository.
- Die vorausgehende Forschungsinformation und Einwilligung erfolgen im externen Registrierungsprozess.
- Die App erfasst keine Kamera-, Foto-, Standort-, Mikrofon-, HealthKit- oder Trackingdaten.
- Übertragen werden je nach Zugang E-Mail-Adresse oder Prolific-ID zur Aktivierung, ein pseudonymer App-Token, zwanzig Craving-Selbstberichte und optional getrenntes Freitextfeedback.
- Die App erhebt keine Trialauswahlen oder Reaktionszeiten und enthält keine Werbung, Analytics oder Drittanbieter-SDKs.
- CueLens behauptet keine therapeutische Wirksamkeit, stellt keine Diagnose und gibt keine medizinische Behandlungsempfehlung.
- Ein Nachweis der unabhängigen ethischen Prüfung wird auf Anforderung über App Store Connect bereitgestellt.

### App-Store-Datenschutz

App Store Connect muss mindestens die in `APP_PRIVACY_DATA_FLOW_MATRIX.md` konservativ festgelegten Kategorien abbilden. „Keine Daten erhoben“ ist unzulässig. Vor Veröffentlichung werden Privacy-Policy-URLs, Serveraufbewahrung, Verknüpfbarkeit und Zwecke im Vier-Augen-Prinzip bestätigt.

## 6. Noch nicht erfüllter Status

- Distribution-Archiv: `AUSSTEHEND`
- Upload/Processing: `AUSSTEHEND`
- TestFlight auf mehreren realen Geräten: `AUSSTEHEND`
- direkter und Prolific-E2E-Abschluss: `AUSSTEHEND`
