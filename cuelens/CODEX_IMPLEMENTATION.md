# CueLens: Implementierungsanweisungen fuer Codex

Diese Datei beschreibt den Soll-Zustand der Android-App im Verzeichnis `cuelens` und dient zugleich als Vorlage fuer die spaetere technische Dokumentation. Die Reihenfolge orientiert sich zuerst an der bisherigen Git-Historie und anschliessend an Expose, aktuellem Masterarbeitsstand und Studienlogik.

## 1. Grundprinzipien

- Implementiere inkrementell, einfach, wartbar und testbar.
- Behandle CueLens als Studienprototyp, nicht als Therapie-App. UI-Texte duerfen keine Wirksamkeitsversprechen enthalten.
- Priorisiere Datensparsamkeit, robuste Studienlogik, reproduzierbare Reizpraesentation, nachvollziehbare Zustandsuebergaenge und geringe Anforderungen an reale Android-Endgeraete.
- Fuege Berechtigungen nur hinzu, wenn sie fuer eine konkrete Funktion zwingend erforderlich sind.
- Personenbezogene Registrierungs- und Abrechnungsdaten gehoeren nicht in die Android-App und nicht in die wissenschaftlichen Selbstberichte.
- Behandle Idempotenz als zentrale Anforderung. Netzwerkfehler duerfen nicht zu doppelten Craving-Werten, falschem Fortschritt oder einem verlorenen Abschluss-Token fuehren.
- Trenne den Abschluss- und Auszahlungstoken dauerhaft von den auswertbaren Craving-Werten. Eine temporaere Verbindung ist nur in der kurzlebigen Tabelle `submission` fuer den Drei-Wege-Handshake zulaessig.

## 2. Bisherige Git-Historie als Umsetzungsreihenfolge

### 2.1 Projektgeruest, Android-App und Craving-Endpunkt

Der erste relevante Entwicklungsschritt ist der Commit `1c27c1e6ade4c597ae56c6beb5ba6c6f228cb0b0` mit der Nachricht `CueLens Android app basic functionality, PHP craving endpoint`.

Soll-Zustand:

- Eigenstaendiges Android-Projekt im Verzeichnis `cuelens`.
- Native Android-App in Kotlin mit einer `MainActivity` und Jetpack Compose.
- Nur die fuer den Studienbetrieb erforderlichen Berechtigungen, im Grundbetrieb insbesondere Internet.
- Hochformat, damit Bilddarstellung, Antwortoptionen und Craving-Slider kontrolliert bleiben.
- Android-Backup deaktiviert, damit lokale Fortschrittsdaten nicht in allgemeine Geraete- oder Cloud-Backups gelangen.
- Craving-Werte werden ganzzahlig im Bereich 0 bis 100 erfasst.
- Produktive Uebertragungen an `submit.php` erfolgen per `PUT`, nicht per `POST`.
- Netzwerkanfragen laufen nicht auf dem UI-Thread.

### 2.2 Studien-MVP

Ein Durchgang besteht aus mehreren Reizaufgaben und einer anschliessenden Craving-Abfrage. In der Cue-Matching-Bedingung wird ein Zielbild mit zwei Bildoptionen kombiniert. In der Cue-Labeling-Bedingung wird ein Zielbild mit zwei Wortoptionen kombiniert. Nach jeder Auswahl wechselt die App zur naechsten Aufgabe. Nach Abschluss der Aufgaben erscheint die Craving-Abfrage mit Slider von 0 bis 100, Standardwert 50 und Button `Absenden`.

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
- Zwischen zwei Studiensituationen liegt im Produktivbetrieb ein Mindestabstand von drei Stunden.
- Insgesamt sind 20 Studiensituationen vorgesehen: zehn Cue-Matching-Situationen und zehn Cue-Labeling-Situationen.
- Jede Studiensituation enthaelt immer fuenf Aufgaben.
- Production-Werte bleiben fachlich konsistent: vier Sekunden Betrachtungs-Countdown beim Cue-Matching und drei Stunden Sperrzeit.

### 2.5 Build-Varianten und Endpunkte

- `staging` verwendet lokale oder interne Test-Endpunkte.
- `production` verwendet `https://cuelens.each-and-every.de/submit`.
- Endpunkte werden ueber `BuildConfig` oder eine vergleichbare Build-Konfiguration bereitgestellt.
- Klartextverkehr ist nur als abgegrenzte Staging-Ausnahme zulaessig.

## 3. Soll-Zustand der Android-App

### 3.1 Architektur

- `MainActivity` initialisiert die Compose-App.
- Studienphasen werden explizit modelliert, zum Beispiel `StartGate`, `ImageMatching`, `WordMatching` und `CravingSubmission`.
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

Fuer die auswertbare Studienfassung sollen stabile IDs fuer Cue, Optionen und Trials ergaenzt werden. Drawable-IDs sind keine dauerhaften wissenschaftlichen Kennungen.

### 3.3 Lokaler Zustand

Persistiere nur kleine, zweckgebundene Werte:

- `next_situation_available_at_millis`: fruehester Startzeitpunkt der naechsten Situation.
- `matching_order`: stabile zufaellige Reihenfolge der Cue-Matching-Aufgaben.
- `token_components`: vom Server zurueckgelieferte und von der App bestaetigte Token-Komponenten.
- `pending_submission`: abgeschlossener Durchgang, dessen initiale Serverantwort noch fehlt.
- `pending_confirmation_token`: Tokenstand oder Token-Komponente, die noch mit dem zweiten PUT bestaetigt werden muss.

`completed_situation_count` und `participant_app_token` sind nicht als autoritative lokale Zustaende zu verwenden. Der Abschlussstand wird aus den bestaetigten Token-Komponenten abgeleitet. Lokale Daten duerfen keine Namen, E-Mail-Adressen, Zahlungsdaten oder Freitexte enthalten.

### 3.4 Netzwerkanbindung und Drei-Wege-Handshake

Die auswertbare Uebertragung besteht aus drei Schritten:

1. **Initialer PUT der App**
   - Die App sendet Craving-Wert und technische Studienmetadaten an `submit.php`.
   - Die App sendet alle bisher bestaetigten Token-Komponenten mit. Beim ersten Wert ist die Liste leer.
   - Der Server validiert den Request, erzeugt beziehungsweise prueft den Token-Fortschritt und speichert Craving-Wert und Tokenbezug zunaechst nur temporaer in `submission`.
   - Der Server antwortet mit der naechsten Token-Komponente.

2. **Bestaetigungs-PUT der App**
   - Nach Erhalt der naechsten Token-Komponente sendet die App einen zweiten PUT.
   - Dieser Request enthaelt keine Craving- oder Studiendaten, sondern nur den erhaltenen Tokenstand beziehungsweise die erhaltene Token-Komponente gemaess Backend-Vertrag.
   - Der Bestaetigungs-PUT resultiert immer in HTTP 204, auch bei Wiederholung.

3. **Serverseitige Finalisierung**
   - Erst nach dem Bestaetigungs-PUT speichert der Server den Craving-Wert aus `submission` in `self_reports`.
   - Danach loescht der Server den zugehoerigen Eintrag aus `submission`.
   - Damit wird die temporaere Verbindung zwischen Token und Craving-Wert wieder verworfen.

Initialer Payload, bis zur naechsten Redundanzbereinigung:

```json
{
  "token_components": ["A1b", "9xQ"],
  "situation_index": 2,
  "condition": "CUE_MATCHING",
  "trial_count": 5,
  "craving": 50,
  "client_timestamp": "2026-06-28T12:00:00Z",
  "app_version": "1.0"
}
```

Bestaetigungspayload in der robusten Variante:

```json
{
  "confirm_token_components": ["A1b", "9xQ", "m7P"]
}
```

Der Bestaetigungspayload enthaelt bewusst keinen Craving-Wert, keine Bedingung, keinen Situationsindex und keine sonstigen Studiendaten.

## 4. Noch zu entwickelnde Anforderungen

### 4.1 Studienfreischaltung, Teilnahmeberechtigung und Tokenausgabe

- Die App verwendet keinen personenbezogenen Account und keinen vorab fest zugeteilten `participant_app_token`.
- Die Teilnahmeberechtigung wird organisatorisch ueber Registrierung, Einwilligung und Bereitstellung der App beziehungsweise Studienanleitung hergestellt.
- Der serverseitig verifizierte Token entsteht erst durch erfolgreiche Craving-Uebertragungen und deren Bestaetigung.
- `submit.php` erzeugt fuer eine neue App-Installation beim ersten gueltigen Craving-PUT einen Token aus 20 Komponenten mit jeweils drei alphanumerischen Zeichen.
- Die erste Komponente muss unter maximal 85 geplanten Teilnehmenden eindeutig sein.
- Die App zeigt den Token erst nach Erhalt und Bestaetigung aller 20 Komponenten an.
- Der Token ist Abschluss- und Abrechnungsnachweis, aber kein Auswertungsschluessel.

### 4.2 Serverseitige Tabellen

Token-Tabelle ohne dauerhafte Relation zur Craving-Tabelle:

```sql
CREATE TABLE app_tokens (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    first_component CHAR(3) NOT NULL UNIQUE,
    component_01 CHAR(3) NOT NULL,
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

Temporaere Zwischentabelle fuer den Handshake:

```sql
CREATE TABLE submission (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    token_id BIGINT UNSIGNED NOT NULL,
    component_index TINYINT UNSIGNED NOT NULL,
    token_prefix_hash CHAR(64) NOT NULL,
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

`submission` enthaelt keine personenbezogenen Daten. Sie verbindet Tokenbezug und Craving-Wert nur bis zur App-Bestaetigung. Nach erfolgreichem Bestaetigungs-PUT wird der Craving-Wert in `self_reports` gespeichert und der `submission`-Eintrag geloescht. Abgelaufene Eintraege werden per Cleanup entfernt oder als abgebrochen behandelt, ohne nach `self_reports` uebernommen zu werden.

### 4.3 Idempotente Serverlogik fuer `submit.php`

1. **Erster gueltiger PUT ohne Token-Komponenten**
   - Server erzeugt 20 Token-Komponenten.
   - Erste Komponente ist eindeutig.
   - Craving wird temporaer in `submission` gespeichert, nicht in `self_reports`.
   - `delivered_component_count = 1`, `confirmed_component_count = 0`.
   - Server gibt Komponente 1 zurueck.

2. **Normaler Folge-PUT mit `n` bisher bestaetigten Komponenten**
   - Voraussetzung: Prefix existiert und `n == confirmed_component_count`.
   - Server legt einen `submission`-Eintrag fuer Komponente `n + 1` an.
   - Server setzt `delivered_component_count = n + 1`.
   - Server gibt Komponente `n + 1` zurueck.

3. **Retry nach verlorener Token-Antwort**
   - Voraussetzung: Prefix existiert, `n == delivered_component_count - 1`, und passende unbestaetigte `submission` existiert.
   - Server speichert Craving nicht erneut.
   - Server gibt Komponente `n + 1` erneut zurueck.

4. **Bestaetigungs-PUT**
   - Request enthaelt nur Tokenstand beziehungsweise erhaltene Komponente, keine Craving- oder Studiendaten.
   - Server gibt immer HTTP 204 zurueck.
   - Falls passende unbestaetigte `submission` existiert, wird der Craving-Wert nach `self_reports` uebernommen, `confirmed_component_count` erhoeht und `submission` geloescht.
   - Falls keine passende `submission` existiert, ist der Request ein idempotenter No-op mit HTTP 204.

5. **Ungueltiger initialer PUT**
   - Nicht existente Prefixe, malformed Token-Komponenten, zu kurze oder zu lange Tokenstaende, ungueltige Craving-Werte oder unplausible Studienfelder resultieren in HTTP 400 `Bad Request`.
   - Dabei wird weder `submission` noch `self_reports` beschrieben.

6. **Abschlussfall**
   - Nach Bestaetigung der 20. Komponente ist die Teilnahme aus Sicht des Tokenmechanismus vollstaendig.
   - Weitere initiale PUTs mit 20 bestaetigten Komponenten speichern keine neuen Craving-Werte.
   - Bestaetigungs-PUTs bleiben idempotent und liefern HTTP 204.

### 4.4 App-Retry-Logik

- Vor dem initialen PUT legt die App lokal ein `PendingSubmission` an.
- Wenn vor der Tokenantwort ein Fehler auftritt, wird derselbe initiale PUT wiederholt.
- Wenn die Tokenantwort eintrifft, speichert die App die Komponente als `pending_confirmation_token` und sendet den Bestaetigungs-PUT.
- Wenn vor oder nach dem Bestaetigungs-PUT ein Fehler auftritt, wiederholt die App nur den Bestaetigungs-PUT.
- Erst nach HTTP 204 wird die Komponente dauerhaft in `token_components` uebernommen und `PendingSubmission` geloescht.
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
- Erster PUT ohne Token-Komponenten.
- Folge-PUTs mit bestaetigtem Prefix.
- Retry nach verlorener Tokenantwort ohne doppelte `submission`.
- Bestaetigungs-PUT mit HTTP 204.
- Uebernahme nach `self_reports` und Loeschung aus `submission`.
- Wiederholte Bestaetigungs-PUTs ohne doppelte Craving-Speicherung.
- HTTP 400 fuer ungueltige initiale PUTs.

### 4.8 Sicherheits- und Datenschutzhaertung

- Kein produktives Logging von Tokens, Craving-Werten, Serverantworten oder personenbezogenen Angaben.
- HTTPS in Production; Klartext nur als Staging-Ausnahme.
- Lokale Token-Komponenten, `PendingSubmission` und `pending_confirmation_token` verschluesseln, wenn sie als sensibel eingestuft werden.
- Keine sensiblen Daten in Zwischenablage, Screenshots, externem Speicher oder Mediengalerie, solange dies nicht ausdruecklich vorgesehen ist.
- Datenkategorien, Speicherorte und Uebertragungen parallel in der Masterarbeit dokumentieren.

### 4.9 Optionale KI-gestuetzte Bildklassifikation

Die KI-Funktion ist nachrangig gegenueber der stabilen Studienfassung. Beginne mit einer austauschbaren Schnittstelle, zum Beispiel `CueDetector`, und dokumentiere fuer jedes Modell Modellgroesse, Inferenzzeit, Speicherbedarf, Android-Mindestversion, Precision, Recall und F1.

## 5. Vorgeschlagene naechste Implementierungsreihenfolge

1. Production-Konstanten und Build-Profile bereinigen.
2. PUT-Vertrag fuer initiale Uebertragung und Bestaetigungs-PUT festlegen.
3. Tabellen `app_tokens` und `submission` einfuehren.
4. Drei-Wege-Handshake implementieren.
5. Payload fuer auswertbare Selbstberichte erweitern und danach Redundanzen gezielt bereinigen.
6. Idempotente Serverlogik fuer Erstuebertragung, Folgeuebertragung, Retry, Bestaetigung und HTTP-400-Faelle implementieren.
7. App-Zustand auf bestaetigte Token-Komponenten umstellen.
8. Retry-Logik fuer `PendingSubmission` und `pending_confirmation_token` implementieren.
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
- Craving-Werte werden bei Retry-Faellen nicht doppelt gespeichert.
- Craving-Werte werden erst nach Bestaetigungs-PUT in `self_reports` uebernommen.
- Die temporaere Tabelle `submission` wird nach erfolgreicher Uebernahme in `self_reports` bereinigt.
- Die Token-Tabelle enthaelt keine dauerhafte Relation zur Craving-Tabelle.
