# CueLens: Implementierungsanweisungen fuer Codex

Diese Datei beschreibt den implementierten technischen Stand der Android-App im Verzeichnis `cuelens` und des zugehoerigen PHP-Backends. Sie dient zugleich als Vorlage fuer die spaetere technische Dokumentation.

## 1. Grundprinzipien

- Implementiere inkrementell, einfach, wartbar und testbar.
- Behandle CueLens als Studienprototyp, nicht als Therapie-App. UI-Texte duerfen keine Wirksamkeitsversprechen enthalten.
- Priorisiere Datensparsamkeit, robuste Studienlogik, reproduzierbare Reizpraesentation, nachvollziehbare Zustandsuebergaenge und geringe Anforderungen an reale Android-Endgeraete.
- Fuege Berechtigungen nur hinzu, wenn sie fuer eine konkrete Funktion zwingend erforderlich sind.
- Personenbezogene Registrierungs- und Abrechnungsdaten gehoeren nicht in die Android-App und nicht in die wissenschaftlichen Selbstberichte.
- Behandle Netzwerkfehler als zentrale Robustheitsanforderung. Die App muss ausstehende Selbstberichte erneut senden koennen und einen erhaltenen Abrechnungscode bis zur Bestaetigung lokal zwischenspeichern.
- Trenne die Registrierung dauerhaft von den auswertbaren Selbstberichten. Der Server gibt nach erfolgreicher Freischaltung ein App-Token aus, speichert dieses Token aber nicht in der Registrierung.
- Uebertrage keine Felder, die serverseitig deterministisch ableitbar sind. Der Server leitet den Studienfortschritt aus der Anzahl bereits gespeicherter Selbstberichte fuer die pseudonyme Kennung ab.
- Speichere in `self_reports` nicht das App-Token selbst, sondern nur den daraus abgeleiteten SHA-256-Hash als `participant_id`.

## 2. Sicherheitskonzepte

### 2.1. Pseudonymisierungsziel

Die technische Datenschutzarchitektur beschreibt keine vollstaendige Anonymisierung, sondern eine Pseudonymisierung der wissenschaftlichen Selbstberichte. Das ist fuer das Within-Subject-Design erforderlich, weil mehrere Selbstberichte derselben App-Installation zusammengefuehrt werden muessen. Die Selbstberichte enthalten keine direkten Identifikatoren wie Name, E-Mail-Adresse, IBAN oder BIC. Sie enthalten jedoch mit `participant_id` eine pseudonyme Kennung. Datenschutzfachlich bleiben die Selbstberichte deshalb als personenbezogene beziehungsweise gesundheitsbezogene Daten mit reduziertem Identifizierungsrisiko zu behandeln.

Die Pseudonymisierung beruht auf folgenden technischen und organisatorischen Massnahmen:

- Direkte Registrierungs- und Abrechnungsdaten liegen ausschliesslich in `register` und werden nicht in die App oder die Berichtstabelle uebernommen.
- Das App-Token wird nach der initialen Freischaltung nur lokal in der App gespeichert und serverseitig nicht dauerhaft persistiert.
- Die auswertbare Kennung `participant_id` wird in `submit.php` als `hash('sha256', strtolower($appToken))` aus dem App-Token abgeleitet und in `self_reports` gespeichert.
- Die App uebertraegt das App-Token bei jedem Selbstbericht, damit der Server die stabile pseudonyme Kennung erneut berechnen kann.
- Die Registrierung enthaelt nur den Zeitpunkt der Token-Ausgabe in `app_token_issued_at`, nicht aber das App-Token selbst und nicht dessen Hash.
- Eine Wiederzuordnung zu einer natuerlichen Person soll ohne Zusatzinformationen aus Registrierung, lokaler App-Installation, Zahlungsabwicklung, Serverlogs oder aktivem Supportvorgang nicht moeglich sein. Diese Zusatzinformationen sind organisatorisch und technisch getrennt zu halten.

### 2.2. Grundsaetze

- Kein produktives Logging von E-Mail-Adressen, App-Tokens, Hashes, Selbstbericht-Werten, Serverantworten oder personenbezogenen Angaben.
- HTTPS in Production; Klartext nur als Staging-Ausnahme.
- Datenbankzugangsdaten liegen serverseitig in `config`, nicht im Repository und nicht in Web-auslieferbaren Verzeichnissen.
- Lokale App-Werte wie App-Token, ausstehender Selbstbericht und Abrechnungscode verschluesseln, wenn sie als sensibel eingestuft werden.
- Keine sensiblen Daten in Zwischenablage, Screenshots, externem Speicher oder Mediengalerie, solange dies nicht ausdruecklich vorgesehen ist.

### 2.3. lokaler Zustand

Persistiere nur kleine, zweckgebundene Werte:

- `app_token`: UUID, die beim initialen Freischaltungsrequest vom Server ausgeliefert und nur in der App persistiert wird.
- `next_situation_available_at_millis`: fruehester Startzeitpunkt der naechsten Situation.
- `confirmed_situation_count`: lokal bestaetigte Anzahl erfolgreich uebermittelter Studiensituationen.
- `matching_order`: stabile zufaellige Reihenfolge der Cue-Matching-Aufgaben.
- `pending_submission_craving`: abgeschlossener Durchgang, dessen Serverantwort noch fehlt.
- `compensation_code`: nach dem letzten Selbstbericht erhaltener Abrechnungscode, solange dessen Bestaetigung noch aussteht.

Lokale Daten duerfen keine Namen, Zahlungsdaten oder Freitexte enthalten. Die E-Mail-Adresse wird nur fuer den initialen Freischaltungsrequest verwendet und danach nicht in der App als Studienzustand benoetigt.

### 2.4. App-Token und Teilnehmerkennung

Der Server erzeugt bei der Freischaltung ein zufaelliges UUID-v4-App-Token und gibt es an die App zurueck. Dieses Token wird danach nur lokal in der App gespeichert. Bei Selbstberichten sendet die App das Token erneut an `submit.php`. Der Server validiert das UUID-Format und berechnet daraus die pseudonyme Auswertungskennung:

```php
$participantId = hash('sha256', strtolower($appToken));
```

Der Hash normalisiert die UUID auf Kleinschreibung, damit dieselbe App-Installation unabhaengig von der Schreibweise dieselbe `participant_id` erhaelt. Der rohe App-Token wird nicht in `self_reports` gespeichert. Zur Rueckwaertskompatibilitaet aktualisiert `submit.php` beim naechsten Selbstbericht alte `self_reports`-Zeilen, deren `participant_id` noch dem rohen App-Token entspricht, auf den SHA-256-Hash.

### 2.5. Initiale Freischaltung per E-Mail-Adresse

Der allererste Request dient nur der Ausgabe des App-Tokens:

```json
{
  "email": "participant@example.org"
}
```

Serververhalten:

- Der Server prueft, ob die E-Mail-Adresse in `register` vorhanden und die Teilnahme freigegeben ist.
- Wenn die E-Mail-Adresse nicht vorhanden, nicht freigegeben oder bereits als tokenisiert markiert ist, wird kein App-Token ausgeliefert.
- Wenn die E-Mail-Adresse gueltig ist, erzeugt der Server ein neues `app_token` als UUID.
- Der Server gibt `app_token` an die App zurueck, persistiert aber weder das App-Token noch dessen Hash in Bezug zur E-Mail-Adresse.
- In `register` wird `app_token_issued_at` gesetzt, damit dieselbe Registrierung nicht erneut aktiviert werden kann.

### 2.6. Selbstbericht-Uebertragung

Die App sendet pro Studiensituation einen `PUT`-Request an `submit.php`:

```json
{
  "app_token": "550e8400-e29b-41d4-a716-446655440000",
  "craving": 50,
  "app_version": "1.0"
}
```

Der Server berechnet aus dem App-Token die `participant_id`, zaehlt die bereits vorhandenen Selbstberichte fuer diese Kennung und bestimmt daraus `situation_index = submitted_count + 1`. Fuer die Situationen 1 bis 10 wird `condition_code = CUE_MATCHING` gesetzt, fuer die Situationen 11 bis 20 `condition_code = CUE_LABELING`. Die App uebertraegt weder Situation noch Bedingung.

`app_version` wird als optionales String-Feld akzeptiert und validiert, aber im derzeitigen Tabellenschema nicht gespeichert.

Bei Situation 20 erzeugt der Server einen UUID-v4-Abrechnungscode, speichert ihn in `compensation_code` und gibt ihn an die App zurueck. Die App bestaetigt diesen Code anschliessend mit einem separaten `PUT`; der Server setzt dabei `confirmed_at`.

## 3. Implementierungsdetails der Android-App

### 3.1 Projektgeruest, Endpunkt-Prototyp

- Eigenstaendiges Android-Projekt im Verzeichnis `cuelens`.
- Native Android-App in Kotlin mit einer `MainActivity` und Jetpack Compose.
- Nur die fuer den Studienbetrieb erforderlichen Berechtigungen, im Grundbetrieb insbesondere Internet.
- Hochformat, damit Bilddarstellung, Antwortoptionen und Slider kontrolliert bleiben.
- Android-Backup deaktiviert, damit lokale Fortschrittsdaten nicht in allgemeine Geraete- oder Cloud-Backups gelangen.
- Der Selbstbericht wird ganzzahlig im Bereich 0 bis 100 erfasst.
- Produktive Uebertragungen an `submit.php` erfolgen per `PUT`.
- Netzwerkanfragen laufen nicht auf dem UI-Thread.

### 3.2 Studien-MVP

Ein Durchgang besteht aus mehreren Reizaufgaben und einer anschliessenden Selbstbericht-Abfrage. In der Cue-Matching-Bedingung wird ein Zielbild mit zwei Bildoptionen kombiniert. In der Cue-Labeling-Bedingung wird ein Zielbild mit zwei Wortoptionen kombiniert. Nach jeder Auswahl wechselt die App zur naechsten Aufgabe. Nach Abschluss der Aufgaben erscheint die Abfrage mit Slider von 0 bis 100, Standardwert 50 und Button `Absenden`.

Cue-Bilder fuellen den sichtbaren Bildschirm durch eine Cover-Darstellung. Match-Bilder und Wortoptionen werden ueber dem Cue-Bild im unteren Bildschirmbereich dargestellt.

### 3.3 Ressourcen und Aufgabenlisten

- Cue-Matching-Items werden aus `cue_0nn`, `match_a_0nn` und `match_b_0nn` erzeugt.
- Ein Cue-Matching-Item ist nur gueltig, wenn alle drei Drawables vorhanden sind.
- Cue-Labeling-Items werden aus einem Cue-Bild und einem Labelpaar erzeugt.
- Labelpaare enthalten ein besser passendes und ein weniger passendes Label.
- Bild- und Wortoptionen werden innerhalb eines Items zufaellig links/rechts beziehungsweise in ihrer Reihenfolge vertauscht.

### 3.4 Studienfortschritt, Sperrzeit und Randomisierung

- Lokaler Fortschritt ist ein App-Cache. Autoritativ fuer die serverseitige Auswertung ist die Anzahl der in `self_reports` gespeicherten Selbstberichte pro `participant_id`.
- Die App speichert lokal den naechsten erlaubten Startzeitpunkt, die Anzahl bestaetigter Studiensituationen, die zufaellige Cue-Matching-Reihenfolge und das App-Token.
- Bei Netzwerkfehlern speichert die App den ausstehenden Craving-Wert, damit derselbe Selbstbericht erneut uebertragen werden kann.
- Zwischen zwei Studiensituationen liegt im Produktivbetrieb ein Mindestabstand von drei Stunden.
- Insgesamt sind 20 Studiensituationen vorgesehen: zehn Cue-Matching-Situationen und zehn Cue-Labeling-Situationen.
- Jede Studiensituation enthaelt fuenf Aufgaben. 
- Production-Werte bleiben fachlich konsistent: vier Sekunden Betrachtungs-Countdown beim Cue-Matching und drei Stunden Sperrzeit.

### 3.5 Build-Varianten und Endpunkte

- `staging` verwendet lokale oder interne Test-Endpunkte.
- `production` verwendet `https://cuelens.each-and-every.de/submit`.
- Endpunkte werden ueber `BuildConfig` oder eine vergleichbare Build-Konfiguration bereitgestellt.
- Klartextverkehr ist nur als abgegrenzte Staging-Ausnahme zulaessig.

### 3.6 Architektur

- `MainActivity` initialisiert die Compose-App.
- Studienphasen werden explizit modelliert, zum Beispiel `StartGate`, `ImageMatching`, `WordMatching` und `SelfReport`.
- UI-Komponenten erhalten nur die fuer Darstellung und Rueckmeldung notwendigen Daten.
- Netzwerk-, Ressourcen- und Persistenzlogik sollen so gekapselt werden, dass sie spaeter in ViewModel-, Repository- oder Service-Klassen ausgelagert werden koennen.

### 3.7 Datenmodell

Mindestens erforderliche Datenklassen:

```kotlin
data class ImageMatchItem(
    @DrawableRes val cueResId: Int,
    @DrawableRes val matchAResId: Int,
    @DrawableRes val matchBResId: Int
)

data class WordMatchItem(
    @DrawableRes val cueResId: Int,
    val fittingLabel: String,
    val lessFittingLabel: String,
    val language: String = "de"
)

enum class StudyCondition { CUE_MATCHING, CUE_LABELING }
```

Fuer die auswertbare Studienfassung sollen stabile IDs fuer Cue, Optionen und Trials ergaenzt werden. Drawable-IDs sind keine dauerhaften wissenschaftlichen Kennungen. Diese IDs muessen nicht im regulaeren Submit-Payload enthalten sein, solange sie fuer den Server nicht zur Validierung oder Auswertung benoetigt werden.


## 4. Serverseitige Tabellen

### 4.1 Registrierung

Die bestehende Tabelle `register` enthaelt Teilnahmeinformationen ohne Bezug zu Craving-Werten und ohne Bezug zu App-Tokens.
```sql
CREATE TABLE register (
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    email VARCHAR(255) COLLATE utf8mb4_general_ci NOT NULL,
    name VARCHAR(255) COLLATE utf8mb4_general_ci NOT NULL,
    iban VARCHAR(255) COLLATE utf8mb4_general_ci NOT NULL,
    bic VARCHAR(255) COLLATE utf8mb4_general_ci NOT NULL,
    age INTEGER NOT NULL,
    cigarettes INTEGER NOT NULL,
    studyinfo tinyint(1) NULL,
    dataprot tinyint(1) NULL,
    doi_token VARCHAR(255) COLLATE utf8mb4_general_ci NOT NULL,
    doi tinyint(1) NOT NULL,
    app_token_issued_at TIMESTAMP NULL
);
```

### 4.2 Selbstberichte

```sql
CREATE TABLE self_reports (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    participant_id CHAR(64) NOT NULL,
    condition_code ENUM('CUE_MATCHING', 'CUE_LABELING') NOT NULL,
    craving TINYINT NOT NULL,
    CHECK(craving BETWEEN 0 AND 100)   
);
```

`self_reports` ist die pseudonymisierte Auswertungstabelle. `participant_id` ist der SHA-256-Hash des normalisierten App-Tokens und nicht der rohe Token. Die Tabelle enthaelt keine Kontakt- oder Zahlungsdaten, erlaubt aber die Zusammenfuehrung mehrerer Selbstberichte derselben App-Installation. Sie darf deshalb nicht als anonymisierte Datensammlung beschrieben werden.

### 4.3 Abrechnungscodes
```sql
CREATE TABLE compensation_code (
    compensation_code CHAR(36) NOT NULL PRIMARY KEY,
    confirmed_at TIMESTAMP NULL 
);
```

## 5. Serverlogik fuer `activate.php` und `submit.php`

1. **Freischaltungsrequest mit E-Mail-Adresse**
   - Voraussetzung: E-Mail-Adresse existiert in `register`, Teilnahme ist freigegeben, `app_token_issued_at` ist noch leer.
   - Server erzeugt ein UUID-App-Token.
   - Server gibt das App-Token zurueck, speichert das App-Token aber nicht.
   - Server setzt `app_token_issued_at`, damit dieselbe Registrierung nicht mehrfach aktiviert werden kann.

2. **Selbstbericht mit App-Token**
   - Voraussetzung: Der Request enthaelt ein formal gueltiges UUID-App-Token und einen ganzzahligen Craving-Wert von 0 bis 100.
   - Server berechnet `participant_id = hash('sha256', strtolower($appToken))`.
   - Server aktualisiert alte `self_reports`-Zeilen, deren `participant_id` noch dem rohen App-Token entspricht, auf den neuen Hash.
   - Server zaehlt die vorhandenen Selbstberichte fuer `participant_id` unter Transaktionsschutz.
   - Wenn bereits 20 Selbstberichte vorhanden sind, wird der Request mit HTTP 400 abgelehnt.
   - Andernfalls wird `situation_index = submitted_count + 1` berechnet.
   - Fuer `situation_index <= 10` wird `condition_code = CUE_MATCHING` gespeichert, danach `condition_code = CUE_LABELING`.
   - Server speichert `participant_id`, `condition_code` und `craving` in `self_reports`.

3. **Abschlussfall**
   - Bei Situation 20 erzeugt der Server einen UUID-Abrechnungscode.
   - Der Code wird in `compensation_code` gespeichert und in der Antwort an die App zurueckgegeben.
   - Die App bestaetigt den Code in einem separaten `PUT`.
   - Der Server setzt `confirmed_at = CURRENT_TIMESTAMP`, falls der Code existiert, und antwortet mit HTTP 204.

4. **Ungueltige Requests**
   - Fehlende App-Tokens, falsch formatierte UUIDs, fehlende oder ungueltige Craving-Werte und nicht unterstuetzte Payloads resultieren in HTTP 400 `Bad Request`.
   - Unsupported HTTP-Methoden resultieren in HTTP 405.
   - Dabei wird kein neuer Selbstbericht gespeichert.

## 6. App-Retry-Logik

- Vor dem Selbstbericht-PUT legt die App lokal den ausstehenden Craving-Wert ab.
- Wenn vor der Serverantwort ein Fehler auftritt, wird derselbe Selbstbericht erneut uebertragen.
- Nach erfolgreicher Serverantwort entfernt die App den ausstehenden Craving-Wert, erhoeht lokal die Anzahl bestaetigter Situationen und setzt die naechste Sperrzeit.
- Wenn die Antwort den Abschlussstatus enthaelt, speichert die App den Abrechnungscode lokal und bestaetigt ihn mit einem separaten `PUT`.
- Wenn die Bestaetigung des Abrechnungscodes fehlschlaegt, wiederholt die App nur diese Bestaetigung.
- Nach erfolgreicher Bestaetigung des Abrechnungscodes markiert die App die Studie lokal als abgeschlossen.
- Die App startet beim naechsten App-Start und vor einer neuen Studiensituation ausstehende Wiederholungen.

Die Selbstbericht-Uebertragung ist im derzeitigen Backend nicht vollstaendig idempotent. Wenn der Server einen Selbstbericht erfolgreich speichert, die Antwort aber vor dem Erreichen der App verloren geht, kann ein erneuter PUT als naechste Studiensituation gespeichert werden. Diese Vereinfachung ist eine bewusste Folge des Verzichts auf Hash-Chain und Drei-Wege-Bestaetigung und muss bei Test, Monitoring und Interpretation beruecksichtigt werden.

## 7. Mehrsprachigkeit Deutsch/Englisch

- Sichtbare UI-Texte aus Kotlin in Android-Stringressourcen verschieben.
- Mindestens `values/strings.xml` und `values-en/strings.xml` pflegen.
- Labelpaare erhalten Sprachzuordnung oder getrennte Ressourcen.
- Studienbegriffe bleiben zwischen App, Studieninformation und Datenschutzerklaerung konsistent.

## 8. Benachrichtigungen

Lokale Benachrichtigungen koennen nach stabiler Datenerfassung implementiert werden. Texte bleiben neutral und enthalten keine Angaben zu Rauchverlangen, Rauchstatus oder medizinischen Aussagen.

## 9. Tests

Vor produktiver Nutzung sind mindestens zu testen:

- Freischaltungsrequest nur fuer in `register` vorhandene und freigegebene E-Mail-Adressen.
- Keine dauerhafte Speicherung des App-Tokens auf dem Server.
- Freischaltung setzt `app_token_issued_at` und gibt ein UUID-v4-App-Token zurueck.
- Ableitung von `participant_id` als SHA-256-Hash des normalisierten App-Tokens.
- Migration alter `self_reports`-Zeilen vom rohen App-Token auf den App-Token-Hash.
- Studiensequenz ueber 20 Situationen.
- Vollstaendigkeit der Bild- und Labelressourcen.
- Slider-Grenzen 0 bis 100.
- Selbstbericht mit gueltigem App-Token und Craving-Wert.
- Retry-Verhalten bei Netzwerkfehlern, einschliesslich des Risikos doppelter Speicherung nach verlorener Serverantwort.
- Speicherung in `self_reports` ohne rohes App-Token.
- Ableitung von Situation und Bedingung aus der Anzahl gespeicherter Selbstberichte.
- Kein weiterer Selbstbericht nach 20 gespeicherten Selbstberichten.
- Ausgabe eines Abrechnungscodes bei Situation 20.
- Bestaetigung des Abrechnungscodes mit HTTP 204.
- HTTP 400 fuer ungueltige Selbstbericht-PUTs.

## 10. Definition of Done

Eine Aenderung gilt nur dann als abgeschlossen, wenn alle zutreffenden Punkte erfuellt sind:

- Die App baut in Staging und Production.
- Die Studienlogik wurde nicht unbeabsichtigt veraendert.
- Neue Datenfelder sind im Code, Backend-Vertrag und in der Dokumentation beschrieben.
- Neue lokale Speicherungen sind nach Zweck, Lebensdauer und Schutzbedarf dokumentiert.
- Fehlerfaelle fuehren zu einem eindeutigen UI-Zustand.
- Tests oder manuelle Acceptance Checks decken den Kernpfad ab.
- `self_reports.participant_id` enthaelt den App-Token-Hash, nicht den rohen App-Token.
- Die Datenbank enthaelt keine dauerhafte Relation zwischen Registrierung, App-Token und Berichtstabelle.
