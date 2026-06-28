# CueLens: Implementierungsanweisungen fuer Codex

Diese Datei beschreibt den Soll-Zustand der Android-App im Verzeichnis `cuelens` und dient zugleich als Vorlage fuer die spaetere technische Dokumentation. Die Reihenfolge orientiert sich zuerst an der bisherigen Git-Historie und anschliessend an Expose, aktuellem Masterarbeitsstand und Studienlogik.

## 1. Grundprinzipien

- Implementiere inkrementell, einfach, wartbar und testbar.
- Behandle CueLens als Studienprototyp, nicht als Therapie-App. UI-Texte duerfen keine Wirksamkeitsversprechen enthalten.
- Priorisiere Datensparsamkeit, robuste Studienlogik, reproduzierbare Reizpraesentation, nachvollziehbare Zustandsuebergaenge und geringe Anforderungen an reale Android-Endgeraete.
- Fuege Berechtigungen nur hinzu, wenn sie fuer eine konkrete Funktion zwingend erforderlich sind.
- Personenbezogene Registrierungs- und Abrechnungsdaten gehoeren nicht in die Android-App und nicht in die wissenschaftlichen Selbstberichte.
- Behandle Idempotenz als zentrale Anforderung. Netzwerkfehler duerfen nicht zu doppelten Selbstberichten, falschem Fortschritt oder einem verlorenen Abschluss-Token fuehren.
- Trenne den Abschluss- und Auszahlungstoken dauerhaft von den auswertbaren Selbstberichten. Eine temporaere Verbindung ist nur in der kurzlebigen Tabelle `submission` fuer den Drei-Wege-Handshake zulaessig.
- Uebertrage keine Felder, die serverseitig deterministisch ableitbar sind. Der Server leitet Situation, Bedingung und feste Trial-Anzahl aus dem bestaetigten Token-Fortschritt und der Studienkonfiguration ab.

## 2. Bisherige Git-Historie als Umsetzungsreihenfolge

### 2.1 Projektgeruest, Android-App und Endpunkt

Der erste relevante Entwicklungsschritt ist der Commit `1c27c1e6ade4c597ae56c6beb5ba6c6f228cb0b0` mit der Nachricht `CueLens Android app basic functionality, PHP craving endpoint`.

Soll-Zustand:

- Eigenstaendiges Android-Projekt im Verzeichnis `cuelens`.
- Native Android-App in Kotlin mit einer `MainActivity` und Jetpack Compose.
- Nur die fuer den Studienbetrieb erforderlichen Berechtigungen, im Grundbetrieb insbesondere Internet.
- Hochformat, damit Bilddarstellung, Antwortoptionen und Slider kontrolliert bleiben.
- Android-Backup deaktiviert, damit lokale Fortschrittsdaten nicht in allgemeine Geraete- oder Cloud-Backups gelangen.
- Der Selbstbericht wird ganzzahlig im Bereich 0 bis 100 erfasst.
- Produktive Uebertragungen an `submit.php` erfolgen per `PUT`, nicht per `POST`.
- Netzwerkanfragen laufen nicht auf dem UI-Thread.

### 2.2 Studien-MVP

Ein Durchgang besteht aus mehreren Reizaufgaben und einer anschliessenden Selbstbericht-Abfrage. In der Cue-Matching-Bedingung wird ein Zielbild mit zwei Bildoptionen kombiniert. In der Cue-Labeling-Bedingung wird ein Zielbild mit zwei Wortoptionen kombiniert. Nach jeder Auswahl wechselt die App zur naechsten Aufgabe. Nach Abschluss der Aufgaben erscheint die Abfrage mit Slider von 0 bis 100, Standardwert 50 und Button `Absenden`.

Cue-Bilder fuellen den sichtbaren Bildschirm durch eine Cover-Darstellung. Match-Bilder und Wortoptionen werden ueber dem Cue-Bild im unteren Bildschirmbereich dargestellt.

### 2.3 Ressourcen und Aufgabenlisten

- Cue-Matching-Items werden aus `cue_0nn`, `match_a_0nn` und `match_b_0nn` erzeugt.
- Ein Cue-Matching-Item ist nur gueltig, wenn alle drei Drawables vorhanden sind.
- Cue-Labeling-Items werden aus einem Cue-Bild und einem Labelpaar erzeugt.
- Labelpaare enthalten ein besser passendes und ein weniger passendes Label.
- Bild- und Wortoptionen werden innerhalb eines Items zufaellig links/rechts beziehungsweise in ihrer Reihenfolge vertauscht.

### 2.4 Studienfortschritt, Sperrzeit und Randomisierung

- Lokaler Fortschritt ist nur ein Cache. Autoritativ ist der serverseitig verifizierte und von der App bestaetigte Token-Fortschritt.
- Die App speichert lokal den naechsten erlaubten Startzeitpunkt, die zufaellige Cue-Matching-Reihenfolge und die bereits bestaetigten Token-Komponenten.
- Der Abschlussstand wird aus `token_components.size` abgeleitet. Ein separates persistentes `completed_situation_count` wird nicht verwendet.
- Zwischen zwei Studiensituationen liegt im Produktivbetrieb ein Mindestabstand von drei Stunden.
- Insgesamt sind 20 Studiensituationen vorgesehen: zehn Cue-Matching-Situationen und zehn Cue-Labeling-Situationen.
- Jede Studiensituation enthaelt immer fuenf Aufgaben. Diese Trial-Anzahl wird nicht uebertragen und nicht gespeichert, solange keine unvollstaendigen Situationen zugelassen werden.
- Production-Werte bleiben fachlich konsistent: vier Sekunden Betrachtungs-Countdown beim Cue-Matching und drei Stunden Sperrzeit.

### 2.5 Build-Varianten und Endpunkte

- `staging` verwendet lokale oder interne Test-Endpunkte.
- `production` verwendet `https://cuelens.each-and-every.de/submit`.
- Endpunkte werden ueber `BuildConfig` oder eine vergleichbare Build-Konfiguration bereitgestellt.
- Klartextverkehr ist nur als abgegrenzte Staging-Ausnahme zulaessig.

## 3. Soll-Zustand der Android-App

### 3.1 Architektur

- `MainActivity` initialisiert die Compose-App.
- Studienphasen werden explizit modelliert, zum Beispiel `StartGate`, `ImageMatching`, `WordMatching` und `SelfReport`.
- UI-Komponenten erhalten nur die fuer Darstellung und Rueckmeldung notwendigen Daten.
- Netzwerk-, Ressourcen- und Persistenzlogik sollen so gekapselt werden, dass sie spaeter in ViewModel-, Repository- oder Service-Klassen ausgelagert werden koennen.

### 3.2 Datenmodell

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

### 3.3 Lokaler Zustand

Persistiere nur kleine, zweckgebundene Werte:

- `next_situation_available_at_millis`: fruehester Startzeitpunkt der naechsten Situation.
- `matching_order`: stabile zufaellige Reihenfolge der Cue-Matching-Aufgaben.
- `token_components`: vom Server zurueckgelieferte und von der App bestaetigte Token-Komponenten.
- `pending_submission`: abgeschlossener Durchgang, dessen initiale Serverantwort noch fehlt.
- `pending_confirmation_token_components`: Token-Prefix inklusive neu erhaltener Komponente, der noch mit dem zweiten PUT bestaetigt werden muss.

`completed_situation_count` und `participant_app_token` sind nicht als autoritative lokale Zustaende zu verwenden. Der Abschlussstand wird aus den bestaetigten Token-Komponenten abgeleitet. Lokale Daten duerfen keine Namen, E-Mail-Adressen, Zahlungsdaten oder Freitexte enthalten.

### 3.4 Netzwerkanbindung und Drei-Wege-Handshake

Die auswertbare Uebertragung besteht aus drei Schritten:

1. **Initialer PUT der App**
   - Die App sendet den Selbstbericht und die bisher bestaetigten Token-Komponenten an `submit.php`.
   - Beim ersten Wert ist die Komponentenliste leer.
   - Der Server validiert den Request, erzeugt beziehungsweise prueft den Token-Fortschritt und speichert Selbstbericht und Tokenbezug zunaechst nur temporaer in `submission`.
   - Der Server antwortet mit der naechsten Token-Komponente.

2. **Bestaetigungs-PUT der App**
   - Nach Erhalt der naechsten Token-Komponente sendet die App einen zweiten PUT.
   - Dieser Request enthaelt keine Studiendaten, sondern nur den Token-Prefix inklusive der neu erhaltenen Komponente.
   - Der Bestaetigungs-PUT resultiert immer in HTTP 204, auch bei Wiederholung.

3. **Serverseitige Finalisierung**
   - Erst nach dem Bestaetigungs-PUT speichert der Server den Selbstbericht aus `submission` in `self_reports`.
   - Danach loescht der Server den zugehoerigen Eintrag aus `submission`.
   - Damit wird die temporaere Verbindung zwischen Token und Selbstbericht wieder verworfen.

Initialer Payload:

```json
{
  "token_components": ["A1b", "9xQ"],
  "craving": 50,
  "app_version": "1.0"
}
```

Optional kann ein Client-Zeitstempel ergaenzt werden, wenn er fuer Plausibilitaetspruefung oder Support benoetigt wird. Er ist nicht als vertrauenswuerdiger Ereigniszeitpunkt zu behandeln.

Bestaetigungspayload:

```json
{
  "confirm_token_components": ["A1b", "9xQ", "m7P"]
}
```

Der Server leitet aus der Laenge des bestaetigten Token-Prefixes ab:

- `situation_index = token_components.size` fuer den initialen PUT.
- `condition = CUE_MATCHING` fuer die ersten zehn Situationen, danach `CUE_LABELING`.
- `trial_count = 5` aus der festen Studienkonfiguration.

Diese Werte werden nicht von der App uebertragen. Der Server kann `situation_index` und `condition` materialisiert in `submission` und `self_reports` speichern, weil sie fuer Auswertung und Plausibilitaet nuetzlich sind. Quelle der Wahrheit bleibt aber der serverseitig validierte Token-Fortschritt.

## 4. Noch zu entwickelnde Anforderungen

### 4.1 Studienfreischaltung, Teilnahmeberechtigung und Tokenausgabe

- Die App verwendet keinen personenbezogenen Account und keinen vorab fest zugeteilten `participant_app_token`.
- Die Teilnahmeberechtigung wird organisatorisch ueber Registrierung, Einwilligung und Bereitstellung der App beziehungsweise Studienanleitung hergestellt.
- Der serverseitig verifizierte Token entsteht erst durch erfolgreiche Uebertragungen und deren Bestaetigung.
- `submit.php` erzeugt fuer eine neue App-Installation beim ersten gueltigen initialen PUT einen Token aus 20 Komponenten mit jeweils drei alphanumerischen Zeichen.
- Die erste Komponente muss unter maximal 85 geplanten Teilnehmenden eindeutig sein.
- Die App zeigt den Token erst nach Erhalt und Bestaetigung aller 20 Komponenten an.
- Der Token ist Abschluss- und Abrechnungsnachweis, aber kein Auswertungsschluessel.

### 4.2 Serverseitige Tabellen

Token-Tabelle ohne dauerhafte Relation zur Berichtstabelle:

```sql
CREATE TABLE app_tokens (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    component_01 CHAR(3) NOT NULL UNIQUE,
    component_02 CHAR(3) NOT NULL,
    component_03 CHAR(3) NOT NULL,
    component_04 CHAR(3) NOT NULL,
    component_05 CHAR(3) NOT NULL,
    component_06 CHAR(3) NOT NULL,
    component_07 CHAR(3) NOT NULL,
    component_08 CHAR(3) NOT NULL,
    component_09 CHAR(3) NOT NULL,
    component_10 CHAR(3) NOT NULL,
    component_11 CHAR(3) NOT NULL,
    component_12 CHAR(3) NOT NULL,
    component_13 CHAR(3) NOT NULL,
    component_14 CHAR(3) NOT NULL,
    component_15 CHAR(3) NOT NULL,
    component_16 CHAR(3) NOT NULL,
    component_17 CHAR(3) NOT NULL,
    component_18 CHAR(3) NOT NULL,
    component_19 CHAR(3) NOT NULL,
    component_20 CHAR(3) NOT NULL,
    delivered_component_count TINYINT UNSIGNED NOT NULL DEFAULT 0,
    confirmed_component_count TINYINT UNSIGNED NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CHECK (delivered_component_count BETWEEN 0 AND 20),
    CHECK (confirmed_component_count BETWEEN 0 AND 20),
    CHECK (confirmed_component_count <= delivered_component_count)
);
```

Die separate Spalte `first_component` wird nicht verwendet, weil `component_01` bereits die erste Komponente enthaelt und eindeutig ist.

Temporaere Zwischentabelle fuer den Handshake:

```sql
CREATE TABLE submission (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    token_id BIGINT UNSIGNED NOT NULL,
    component_index TINYINT UNSIGNED NOT NULL,
    craving TINYINT UNSIGNED NOT NULL,
    situation_index TINYINT UNSIGNED NOT NULL,
    condition_code ENUM('CUE_MATCHING', 'CUE_LABELING') NOT NULL,
    app_version VARCHAR(32) NULL,
    client_timestamp DATETIME NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    UNIQUE KEY uq_submission_token_component (token_id, component_index),
    CHECK (craving BETWEEN 0 AND 100),
    CHECK (component_index BETWEEN 1 AND 20)
);
```

`submission` enthaelt keine personenbezogenen Daten. Sie verbindet Tokenbezug und Selbstbericht nur bis zur App-Bestaetigung. Nach erfolgreichem Bestaetigungs-PUT wird der Selbstbericht in `self_reports` gespeichert und der `submission`-Eintrag geloescht. Abgelaufene Eintraege werden per Cleanup entfernt oder als abgebrochen behandelt, ohne nach `self_reports` uebernommen zu werden.

### 4.3 Idempotente Serverlogik fuer `submit.php`

1. **Erster gueltiger PUT ohne Token-Komponenten**
   - Server erzeugt 20 Token-Komponenten.
   - `component_01` ist eindeutig.
   - Der Selbstbericht wird temporaer in `submission` gespeichert, nicht in `self_reports`.
   - `delivered_component_count = 1`, `confirmed_component_count = 0`.
   - Server gibt Komponente 1 zurueck.

2. **Normaler Folge-PUT mit `n` bisher bestaetigten Komponenten**
   - Voraussetzung: Prefix existiert und `n == confirmed_component_count`.
   - Der Server leitet Situation und Bedingung aus `n` ab.
   - Server legt einen `submission`-Eintrag fuer Komponente `n + 1` an.
   - Server setzt `delivered_component_count = n + 1`.
   - Server gibt Komponente `n + 1` zurueck.

3. **Retry nach verlorener Token-Antwort**
   - Voraussetzung: Prefix existiert, `n == delivered_component_count - 1`, und passende unbestaetigte `submission` existiert.
   - Server speichert den Selbstbericht nicht erneut.
   - Server gibt Komponente `n + 1` erneut zurueck.

4. **Bestaetigungs-PUT**
   - Request enthaelt nur den Token-Prefix inklusive neu erhaltener Komponente, keine Studiendaten.
   - Server gibt immer HTTP 204 zurueck.
   - Falls passende unbestaetigte `submission` existiert, wird der Selbstbericht nach `self_reports` uebernommen, `confirmed_component_count` erhoeht und `submission` geloescht.
   - Falls keine passende `submission` existiert, ist der Request ein idempotenter No-op mit HTTP 204.

5. **Ungueltiger initialer PUT**
   - Nicht existente Prefixe, falsch formatierte Token-Komponenten, zu kurze oder zu lange Tokenstaende oder ungueltige Selbstbericht-Werte resultieren in HTTP 400 `Bad Request`.
   - Dabei wird weder `submission` noch `self_reports` beschrieben.

6. **Abschlussfall**
   - Nach Bestaetigung der 20. Komponente ist die Teilnahme aus Sicht des Tokenmechanismus vollstaendig.
   - Weitere initiale PUTs mit 20 bestaetigten Komponenten speichern keine neuen Selbstberichte.
   - Bestaetigungs-PUTs bleiben idempotent und liefern HTTP 204.

### 4.4 App-Retry-Logik

- Vor dem initialen PUT legt die App lokal ein `PendingSubmission` an.
- Wenn vor der Tokenantwort ein Fehler auftritt, wird derselbe initiale PUT wiederholt.
- Wenn die Tokenantwort eintrifft, speichert die App den neuen Prefix als `pending_confirmation_token_components` und sendet den Bestaetigungs-PUT.
- Wenn vor oder nach dem Bestaetigungs-PUT ein Fehler auftritt, wiederholt die App nur den Bestaetigungs-PUT.
- Erst nach HTTP 204 wird die neue Komponente dauerhaft in `token_components` uebernommen und `PendingSubmission` geloescht.
- Die App startet beim naechsten App-Start und vor einer neuen Studiensituation ausstehende Wiederholungen.

### 4.5 Mehrsprachigkeit Deutsch/Englisch

- Sichtbare UI-Texte aus Kotlin in Android-Stringressourcen verschieben.
- Mindestens `values/strings.xml` und `values-en/strings.xml` pflegen.
- Labelpaare erhalten Sprachzuordnung oder getrennte Ressourcen.
- Studienbegriffe bleiben zwischen App, Studieninformation und Datenschutzerklaerung konsistent.

### 4.6 Benachrichtigungen

Lokale Benachrichtigungen koennen nach stabiler Datenerfassung und Token-Idempotenz implementiert werden. Texte bleiben neutral und enthalten keine Angaben zu Rauchverlangen, Rauchstatus oder medizinischen Aussagen.

### 4.7 Tests

Vor produktiver Nutzung sind mindestens zu testen:

- Studiensequenz ueber 20 Situationen.
- Vollstaendigkeit der Bild- und Labelressourcen.
- Slider-Grenzen 0 bis 100.
- Initialer PUT ohne Token-Komponenten.
- Folge-PUTs mit bestaetigtem Prefix.
- Retry nach verlorener Tokenantwort ohne doppelte `submission`.
- Bestaetigungs-PUT mit HTTP 204.
- Uebernahme nach `self_reports` und Loeschung aus `submission`.
- Wiederholte Bestaetigungs-PUTs ohne doppelte Speicherung.
- HTTP 400 fuer ungueltige initiale PUTs.
- Ableitung von Situation und Bedingung aus der Prefix-Laenge.

### 4.8 Sicherheits- und Datenschutzhaertung

- Kein produktives Logging von Tokens, Selbstbericht-Werten, Serverantworten oder personenbezogenen Angaben.
- HTTPS in Production; Klartext nur als Staging-Ausnahme.
- Lokale Token-Komponenten, `PendingSubmission` und `pending_confirmation_token_components` verschluesseln, wenn sie als sensibel eingestuft werden.
- Keine sensiblen Daten in Zwischenablage, Screenshots, externem Speicher oder Mediengalerie, solange dies nicht ausdruecklich vorgesehen ist.
- Datenkategorien, Speicherorte und Uebertragungen parallel in der Masterarbeit dokumentieren.

### 4.9 Optionale KI-gestuetzte Bildklassifikation

Die KI-Funktion ist nachrangig gegenueber der stabilen Studienfassung. Beginne mit einer austauschbaren Schnittstelle, zum Beispiel `CueDetector`, und dokumentiere fuer jedes Modell Modellgroesse, Inferenzzeit, Speicherbedarf, Android-Mindestversion, Precision, Recall und F1.

## 5. Vorgeschlagene naechste Implementierungsreihenfolge

1. Production-Konstanten und Build-Profile bereinigen.
2. PUT-Vertrag fuer initiale Uebertragung und Bestaetigungs-PUT festlegen.
3. Tabellen `app_tokens` und `submission` einfuehren.
4. Drei-Wege-Handshake implementieren.
5. Serverseitige Ableitung von Situation und Bedingung aus dem Token-Fortschritt implementieren.
6. Idempotente Serverlogik fuer Erstuebertragung, Folgeuebertragung, Retry, Bestaetigung und HTTP-400-Faelle implementieren.
7. App-Zustand auf bestaetigte Token-Komponenten umstellen.
8. Retry-Logik fuer `PendingSubmission` und `pending_confirmation_token_components` implementieren.
9. Mehrsprachigkeit umsetzen.
10. Tests fuer Studienlogik, Tokenlogik und Ressourcenintegritaet ergaenzen.
11. Sicherheits- und Datenschutzhaertung abschliessen.
12. Optionale Erinnerungen implementieren.
13. KI-Schnittstelle vorbereiten.
14. Dokumentationsabgleich mit `PROJECT_PLAN.md`, `ASSUMPTIONS.md`, Kapitel 5 und Kapitel 6.

## 6. Definition of Done

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
- Die Token-Tabelle enthaelt keine dauerhafte Relation zur Berichtstabelle.
