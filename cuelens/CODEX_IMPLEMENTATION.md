# CueLens: Implementierungsanweisungen fuer Codex

Diese Datei beschreibt den Soll-Zustand der Android-App im Verzeichnis `cuelens` und dient zugleich als Vorlage fuer die spaetere technische Dokumentation. Die Reihenfolge orientiert sich zuerst an der bisherigen Git-Historie und anschliessend an Expose, aktuellem Masterarbeitsstand und Studienlogik.

## 1. Grundprinzipien

- Implementiere inkrementell, einfach, wartbar und testbar.
- Behandle CueLens als Studienprototyp, nicht als Therapie-App. UI-Texte duerfen keine Wirksamkeitsversprechen enthalten.
- Priorisiere Datensparsamkeit, robuste Studienlogik, reproduzierbare Reizpraesentation, nachvollziehbare Zustandsuebergaenge und geringe Anforderungen an reale Android-Endgeraete.
- Fuege Berechtigungen nur hinzu, wenn sie fuer eine konkrete Funktion zwingend erforderlich sind.
- Personenbezogene Registrierungs- und Abrechnungsdaten gehoeren nicht in die Android-App und nicht in die wissenschaftlichen Selbstberichte.
- Behandle Idempotenz als zentrale Anforderung. Netzwerkfehler duerfen nicht zu doppelten Selbstberichten, falschem Fortschritt oder einem verlorenen Abschlussnachweis fuehren.
- Trenne die Registrierung dauerhaft von den auswertbaren Selbstberichten. Eine temporaere Verbindung zwischen gueltigem Hash und Selbstbericht ist nur in der kurzlebigen Tabelle `submission` fuer den Drei-Wege-Handshake zulaessig.
- Uebertrage keine Felder, die serverseitig deterministisch ableitbar sind. Der Server leitet Situation, Bedingung und feste Trial-Anzahl aus dem gueltigen HMAC-Kettenschritt und der Studienkonfiguration ab.
- Speichere das HMAC-Secret ausschliesslich serverseitig im geschuetzten Verzeichnis `config`. Das App-Token wird nur in der App gespeichert und nicht dauerhaft auf dem Server persistiert.

## 2. Sicherheitskonzepte

### 2.1. Grundsaetze

- Kein produktives Logging von E-Mail-Adressen, App-Tokens, Hashes, Selbstbericht-Werten, Serverantworten oder personenbezogenen Angaben.
- HTTPS in Production; Klartext nur als Staging-Ausnahme.
- HMAC-Secret nur serverseitig in `config`, nicht im Repository und nicht in Web-auslieferbaren Verzeichnissen.
- Lokale App-Werte wie App-Token, aktueller Hash, `PendingSubmission` und `pending_confirmation_hash` verschluesseln, wenn sie als sensibel eingestuft werden.
- Keine sensiblen Daten in Zwischenablage, Screenshots, externem Speicher oder Mediengalerie, solange dies nicht ausdruecklich vorgesehen ist.

### 2.2. lokaler Zustand

Persistiere nur kleine, zweckgebundene Werte:

- `app_token`: UUID, die beim initialen Freischaltungsrequest vom Server ausgeliefert und nur in der App persistiert wird.
- `current_hash`: aktuell gueltiger, beim naechsten Selbstbericht vorzulegender HMAC-Kettenwert.
- `next_situation_available_at_millis`: fruehester Startzeitpunkt der naechsten Situation.
- `matching_order`: stabile zufaellige Reihenfolge der Cue-Matching-Aufgaben.
- `pending_submission`: abgeschlossener Durchgang, dessen initiale Serverantwort noch fehlt.
- `pending_confirmation_hash`: vom Server neu ausgelieferter Hash, der noch mit dem zweiten PUT bestaetigt werden muss.

Lokale Daten duerfen keine Namen, Zahlungsdaten oder Freitexte enthalten. Die E-Mail-Adresse wird nur fuer den initialen Freischaltungsrequest verwendet und danach nicht in der App als Studienzustand benoetigt.

### 2.3. HMAC-Hash-Chain

Die Anzahl der Uebermittlungen wird mittels App-Token in Form einer UUID und einer HMAC-Hash-Chain geprueft:

```text
h_1 = HMAC(secret, app_token)
h_i = HMAC(secret, h_(i-1) || app_token) fuer i = 2..20
```

Anforderungen:

- Verwende einen ausreichend langen kodierten HMAC-Wert, zum Beispiel einen vollstaendigen SHA-256-HMAC als Hex- oder Base64url-Wert.
- Das Secret wird nur serverseitig im geschuetzten Verzeichnis `config` gespeichert.
- Das App-Token wird serverseitig nicht persistiert.
- Der Server speichert immer nur den naechsten gueltigen, von der App vorzulegenden Hash in `valid_hashes`.
- Eine Tabelle `final_hashes` wird nicht verwendet. Ob ein uebertragener Hash `h_20` ist, wird waehrend der Pruefung gegen die aus dem App-Token berechnete Kette festgestellt.
- Der uebermittelte Hash wird zeitkonstant gegen die erwarteten Kettenwerte geprueft, zum Beispiel mit `hash_equals` oder einer vergleichbaren konstantzeitnahen Vergleichsfunktion. Die Pruefschleife soll alle 20 moeglichen Kettenwerte berechnen und nicht nach dem ersten Treffer abbrechen.

### 2.4. Initiale Freischaltung per E-Mail-Adresse

Der allererste Request dient nur der Ausgabe des App-Tokens und des ersten gueltigen Hashs:

```json
{
  "email": "participant@example.org"
}
```

Serververhalten:

- Der Server prueft, ob die E-Mail-Adresse in `register` vorhanden und die Teilnahme freigegeben ist.
- Wenn die E-Mail-Adresse nicht vorhanden, nicht freigegeben oder bereits als tokenisiert markiert ist, wird kein App-Token ausgeliefert.
- Wenn die E-Mail-Adresse gueltig ist, erzeugt der Server ein neues `app_token` als UUID und berechnet `h_1 = HMAC(secret, app_token)`.
- Der Server gibt `app_token` und `h_1` an die App zurueck, persistiert aber weder das App-Token noch `h_1` in Bezug zur E-Mail-Adresse.
- Die App bestaetigt den Erhalt von App-Token und `h_1` in einem zweiten PUT. Erst nach dieser Bestaetigung wird in `register` gespeichert, dass ein App-Token ausgeliefert wurde. Der Token selbst wird dort nicht gespeichert.
- Nach erfolgreicher Bestaetigung speichert der Server `h_1` in `valid_hashes`. Damit ist `h_1` der gueltige Nachweis fuer den ersten Selbstbericht.

Bestaetigung der initialen Freischaltung:

```json
{
  "email": "participant@example.org",
  "app_token": "550e8400-e29b-41d4-a716-446655440000",
  "confirmed_hash": "h_1"
}
```

Der Server prueft, ob `confirmed_hash` zeitkonstant dem aus `app_token` berechneten `h_1` entspricht. Anschliessend setzt er ein technisches Flag oder einen Zeitstempel in `register`, zum Beispiel `app_token_issued_at`, ohne das App-Token zu speichern.

### 2.5. Drei-Wege-Handshake fuer Selbstberichte

Die auswertbare Uebertragung besteht aus drei Schritten:

1. **Initialer PUT der App**
   - Die App sendet `app_token`, den aktuell gueltigen Hash und den Selbstbericht an `submit.php`.
   - Der Server sucht den uebermittelten Hash in `valid_hashes`.
   - Der Server berechnet mit dem uebermittelten App-Token die HMAC-Kette `h_1` bis `h_20` und prueft zeitkonstant, ob der uebermittelte Hash zu dieser Kette gehoert.
   - Der Server leitet aus dem gefundenen Kettenindex Situation und Bedingung ab.
   - Der Server speichert Selbstbericht, Kettenindex und den naechsten Hash zunaechst nur temporaer in `submission`.
   - Der Server loescht den verbrauchten Hash aus `valid_hashes` und antwortet mit dem naechsten Hash. Bei `h_20` antwortet der Server mit einem Abschlussstatus und speichert keinen weiteren gueltigen Hash.

2. **Bestaetigungs-PUT der App**
   - Nach Erhalt des naechsten Hashs sendet die App einen zweiten PUT.
   - Dieser Request enthaelt keine Studiendaten, sondern `app_token` und den neu erhaltenen Hash. Bei Abschluss nach `h_20` enthaelt der Request den Abschlussnachweis gemaess Backend-Vertrag.
   - Der Bestaetigungs-PUT resultiert immer in HTTP 204, auch bei Wiederholung.

3. **Serverseitige Finalisierung**
   - Erst nach dem Bestaetigungs-PUT speichert der Server den Selbstbericht aus `submission` in `self_reports`.
   - Fuer die Schritte 1 bis 19 speichert der Server den neu bestaetigten Hash in `valid_hashes`; dieser Hash ist beim naechsten Selbstbericht vorzulegen.
   - Fuer Schritt 20 wird kein weiterer Hash gespeichert.
   - Danach loescht der Server den zugehoerigen Eintrag aus `submission`.
   - Damit wird die temporaere Verbindung zwischen Hash und Selbstbericht wieder verworfen.

Initialer Payload fuer einen Selbstbericht:

```json
{
  "app_token": "550e8400-e29b-41d4-a716-446655440000",
  "hash": "current_valid_hash",
  "craving": 50,
  "app_version": "1.0"
}
```

Bestaetigungspayload fuer Schritt 1 bis 19:

```json
{
  "app_token": "550e8400-e29b-41d4-a716-446655440000",
  "confirmed_hash": "next_valid_hash"
}
```

Der Server leitet aus dem Kettenindex  `condition = CUE_MATCHING` fuer die ersten zehn Situationen, danach `CUE_LABELING` ab.

Diese Werte werden nicht von der App uebertragen. Quelle der Wahrheit bleibt immer die serverseitig validierte HMAC-Kette.

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

- Lokaler Fortschritt ist nur ein App-Cache. Autoritativ ist, ob die App den naechsten gueltigen HMAC-Kettenwert besitzt.
- Die App speichert lokal den naechsten erlaubten Startzeitpunkt, die zufaellige Cue-Matching-Reihenfolge, das App-Token und den aktuell vorzulegenden Hash.
- Ein separates persistentes `completed_situation_count` wird nicht verwendet.
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
    created_at DATETIME NOT NULL DEFAULT NOW(),
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

### 4.2 Gueltige Hashes

```sql
CREATE TABLE valid_hashes (
    hash_value CHAR(64) NOT NULL PRIMARY KEY,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

`valid_hashes` enthaelt nur den jeweils naechsten gueltigen, vorzulegenden Hash. Es gibt keine Spalte fuer App-Token, E-Mail-Adresse, Teilnehmenden-ID, Situation oder Bedingung. Aus der Tabelle allein soll der Fortschritt 1 bis 19 nicht nachvollziehbar sein.

### 4.3 Temporaere Submissions

```sql
CREATE TABLE submission (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    consumed_hash CHAR(64) NOT NULL UNIQUE,
    next_hash CHAR(64) NULL,
    craving TINYINT UNSIGNED NOT NULL,
    condition_code ENUM('CUE_MATCHING', 'CUE_LABELING') NOT NULL,
    app_version VARCHAR(32) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (craving BETWEEN 0 AND 100)
);
```

`submission` enthaelt keine personenbezogenen Daten und kein App-Token. Sie verbindet Hashbezug und Selbstbericht nur bis zur App-Bestaetigung. Nach erfolgreichem Bestaetigungs-PUT wird der Selbstbericht in `self_reports` gespeichert und der `submission`-Eintrag geloescht. Abgelaufene Eintraege werden per Cleanup entfernt oder als abgebrochen behandelt, ohne nach `self_reports` uebernommen zu werden.

### 4.4 Abrechnungscodes
```sql
CREATE TABLE compensation_code (
    compensation_code CHAR(64) NOT NULL PRIMARY KEY,
    confirmmed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

## 5. Idempotente Serverlogik fuer `submit.php`

1. **Freischaltungsrequest mit E-Mail-Adresse**
   - Voraussetzung: E-Mail-Adresse existiert in `register`, Teilnahme ist freigegeben, `app_token_issued_at` ist noch leer.
   - Server erzeugt ein UUID-App-Token und berechnet `h_1`.
   - Server gibt App-Token und `h_1` zurueck, speichert das App-Token aber nicht.
   - Nach Bestaetigung setzt der Server `app_token_issued_at` und speichert `h_1` in `valid_hashes`.

2. **Initialer Selbstbericht mit gueltigem Hash**
   - Voraussetzung: Der uebermittelte Hash existiert in `valid_hashes` und passt zeitkonstant geprueft zur aus `app_token` berechneten Kette.
   - Server bestimmt den Kettenindex durch vollstaendige Pruefung der 20 Kettenwerte.
   - Server legt einen `submission`-Eintrag an, loescht den verbrauchten Hash aus `valid_hashes` und gibt fuer Index 1 bis 19 den naechsten Hash zurueck.
   - Bei Index 20 wird der Selbstbericht unmittelbar in `self_reports` gespeichert. Es wird kein `submission`-Eintrag erstellt und kein naechster Hash erzeugt; die Antwort enthaelt eine UUID als Abrechnungscode, der auch in der Tabelle `compensation_code` gespeichert wird.

3. **Retry nach verlorener Serverantwort**
   - Wenn der uebermittelte Hash nicht mehr in `valid_hashes`, aber als `consumed_hash` in einer offenen `submission` vorhanden ist, speichert der Server nichts erneut.
   - Der Server gibt denselben `next_hash` beziehungsweise denselben Abschlussstatus erneut zurueck.

4. **Bestaetigungs-PUT**
   - Fuer Index 1 bis 19 enthaelt die Bestaetigung den neu erhaltenen Hash. Der Server sucht diesen Hash als `next_hash` in einer offenen `submission`.
   - Fuer Index 20 bestaetigt die App den Abrechnungscode; der Server setzt das `confirmed_at` in der Tabelle `compensation_code`.
   - Falls eine passende offene `submission` existiert, wird der Selbstbericht nach `self_reports` uebernommen, der `next_hash` fuer Index 1 bis 19 in `valid_hashes` gespeichert und `submission` geloescht.
   - Falls keine passende `submission` existiert, ist der Request ein idempotenter No-op.
   - Der Server gibt immer HTTP 204 zurueck.

5. **Ungueltiger initialer Selbstbericht**
   - Nicht vorhandene Hashes, falsch formatierte Hashes, nicht zur HMAC-Kette passende Hashes, fehlende App-Tokens oder ungueltige Selbstbericht-Werte resultieren in HTTP 400 `Bad Request`.
   - Dabei wird weder `submission` noch `self_reports` beschrieben.

6. **Abschlussfall**
   - Nach Bestaetigung von `h_20` ist die Teilnahme aus Sicht des Tokenmechanismus vollstaendig.
   - Es wird kein weiterer gueltiger Hash gespeichert.
   - Weitere Selbstberichte mit verbrauchten oder unbekannten Hashes speichern keine neuen Selbstberichte.

## 6. App-Retry-Logik

- Vor dem initialen Selbstbericht-PUT legt die App lokal ein `PendingSubmission` an.
- Wenn vor der Serverantwort ein Fehler auftritt, wird derselbe initiale PUT wiederholt.
- Wenn die Serverantwort eintrifft, speichert die App den neu erhaltenen Hash als `pending_confirmation_hash` und sendet den Bestaetigungs-PUT.
- Wenn vor oder nach dem Bestaetigungs-PUT ein Fehler auftritt, wiederholt die App nur den Bestaetigungs-PUT.
- Erst nach HTTP 204 wird `current_hash` auf den neu bestaetigten Hash gesetzt und `PendingSubmission` geloescht.
- Beim Abschluss nach `h_20` markiert die App die Studie nach HTTP 204 als abgeschlossen und zeigt den vorgesehenen Abschlussnachweis gemaess UI-Konzept an.
- Die App startet beim naechsten App-Start und vor einer neuen Studiensituation ausstehende Wiederholungen.

## 7. Mehrsprachigkeit Deutsch/Englisch

- Sichtbare UI-Texte aus Kotlin in Android-Stringressourcen verschieben.
- Mindestens `values/strings.xml` und `values-en/strings.xml` pflegen.
- Labelpaare erhalten Sprachzuordnung oder getrennte Ressourcen.
- Studienbegriffe bleiben zwischen App, Studieninformation und Datenschutzerklaerung konsistent.

## 8. Benachrichtigungen

Lokale Benachrichtigungen koennen nach stabiler Datenerfassung und Token-Idempotenz implementiert werden. Texte bleiben neutral und enthalten keine Angaben zu Rauchverlangen, Rauchstatus oder medizinischen Aussagen.

## 9. Tests

Vor produktiver Nutzung sind mindestens zu testen:

- Freischaltungsrequest nur fuer in `register` vorhandene und freigegebene E-Mail-Adressen.
- Keine dauerhafte Speicherung des App-Tokens auf dem Server.
- Bestaetigung der Freischaltung setzt `app_token_issued_at` und speichert `h_1` in `valid_hashes`.
- HMAC-Kettenberechnung fuer `h_1` bis `h_20`.
- Zeitkonstante Pruefung des uebermittelten Hashs gegen alle 20 moeglichen Kettenwerte.
- Studiensequenz ueber 20 Situationen.
- Vollstaendigkeit der Bild- und Labelressourcen.
- Slider-Grenzen 0 bis 100.
- Initialer Selbstbericht mit gueltigem Hash.
- Retry nach verlorener Serverantwort ohne doppelte `submission`.
- Retries mehrerer nicht erfolgreich uebermittelter Selbstberichte.
- Bestaetigungs-PUT mit HTTP 204.
- Uebernahme nach `self_reports` und Loeschung aus `submission`.
- Speicherung des naechsten gueltigen Hashs erst nach Bestaetigung.
- Kein weiterer gueltiger Hash nach `h_20`.
- HTTP 400 fuer ungueltige Selbstbericht-PUTs.
- Ableitung von Bedingung aus dem Kettenindex.

## 10. Definition of Done

Eine Aenderung gilt nur dann als abgeschlossen, wenn alle zutreffenden Punkte erfuellt sind:

- Die App baut in Staging und Production.
- Die Studienlogik wurde nicht unbeabsichtigt veraendert.
- Neue Datenfelder sind im Code, Backend-Vertrag und in der Dokumentation beschrieben.
- Neue lokale Speicherungen sind nach Zweck, Lebensdauer und Schutzbedarf dokumentiert.
- Fehlerfaelle fuehren zu einem eindeutigen UI-Zustand.
- Tests oder manuelle Acceptance Checks decken den Kernpfad ab.
- Selbstberichte werden bei Retry-Faellen nicht doppelt gespeichert.
- Selbstberichte werden erst nach Bestaetigungs-PUT in `self_reports` uebernommen.
- Die temporaere Tabelle `submission` wird nach erfolgreicher Uebernahme in `self_reports` bereinigt.
- Die Datenbank enthaelt keine dauerhafte Relation zwischen Registrierung, App-Token, HMAC-Kette und Berichtstabelle.
