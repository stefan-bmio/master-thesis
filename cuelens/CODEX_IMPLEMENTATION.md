# CueLens: Implementierungsanweisungen fuer Codex

Diese Datei beschreibt den Soll-Zustand der Android-App im Verzeichnis `cuelens` und dient zugleich als arbeitsnahe Vorlage fuer die spaetere technische Dokumentation der Masterarbeit. Die Reihenfolge orientiert sich zuerst an der bisherigen Git-Historie des Prototyps und anschliessend an den Anforderungen aus Expose, aktuellem LaTeX-Stand der Masterarbeit und Studienlogik.

## 1. Grundprinzipien fuer alle Aenderungen

- Arbeite inkrementell und halte die App als nativen Android-Prototyp in Kotlin mit Jetpack Compose einfach, wartbar und testbar.
- Behandle die App als Studienprototyp, nicht als Therapie-App. UI-Texte duerfen keine Heilungs-, Entwoehnungs- oder Wirksamkeitsversprechen enthalten.
- Priorisiere Datensparsamkeit, robuste Studienlogik, reproduzierbare Reizpraesentation, nachvollziehbare Zustandsuebergaenge und geringe technische Anforderungen an reale Android-Endgeraete.
- Nutze keine zusaetzlichen Berechtigungen, solange sie nicht fuer eine konkrete Funktion zwingend erforderlich sind. Jede neue Berechtigung muss im Quelltext, in dieser Datei und spaeter in der Arbeit begruendet werden.
- Verarbeite sensible Daten nur zweckgebunden. Personenbezogene Registrierungs- und Abrechnungsdaten gehoeren nicht in die Android-App und nicht in die wissenschaftlichen Selbstberichte.
- Halte alle Endpunkte, Build-Varianten und Konstanten so strukturiert, dass lokale Tests, Staging und Produktion getrennt nachvollziehbar bleiben.
- Behandle Idempotenz als zentrale Anforderung der Studiendatenuebertragung. Ein Netzwerkfehler nach erfolgreicher serverseitiger Speicherung darf nicht zu doppelten Craving-Werten, falschem Fortschritt oder einem verlorenen Abrechnungstoken fuehren.

## 2. Bisherige Git-Historie als Umsetzungsreihenfolge

### 2.1 Projektgeruest, Android-App und Craving-Endpunkt

Der erste relevante Entwicklungsschritt ist der Commit `1c27c1e6ade4c597ae56c6beb5ba6c6f228cb0b0` mit der Nachricht `CueLens Android app basic functionality, PHP craving endpoint`. Daraus ergibt sich fuer die Android-App folgender Soll-Zustand:

- Das Verzeichnis `cuelens` enthaelt ein eigenstaendiges Android-Projekt mit Gradle-Konfiguration, App-Modul, Android-Manifest und Kotlin-Quelltext.
- Die App ist eine native Android-Anwendung mit einer einzigen `MainActivity`.
- Die Benutzeroberflaeche wird mit Jetpack Compose aufgebaut.
- Die App darf im Studienprototyp nur die Internet-Berechtigung benoetigen.
- Die App ist fuer Hochformat ausgelegt, damit Bilddarstellung, Antwortoptionen und Craving-Slider unter kontrollierten Layoutbedingungen verwendet werden.
- Die automatische Android-Sicherung ist deaktiviert, damit lokale Fortschrittsdaten nicht ueber allgemeine Geraete- oder Cloud-Backups in weitere Kontexte uebertragen werden.
- Der Craving-Wert wird als ganzzahliger Wert im Bereich 0 bis 100 erhoben und per `PUT` an den konfigurierten Submit-Endpunkt uebertragen.
- Die Netzwerkanfrage laeuft ausserhalb des UI-Threads, damit die App bedienbar bleibt.

### 2.2 Studien-MVP: Cue-Matching, Cue-Labeling und Craving-Abfrage

Die MVP-Logik folgt dem vorhandenen Projektplan und wird als deterministischer, ressourcenbasierter Ablauf verstanden:

- Ein Durchgang besteht aus mehreren Reizaufgaben und einer anschliessenden Craving-Abfrage.
- In der Cue-Matching-Bedingung wird ein Zielbild angezeigt und die teilnehmende Person waehlt zwischen zwei Bildoptionen.
- In der Cue-Labeling-Bedingung wird ein Zielbild angezeigt und die teilnehmende Person waehlt zwischen zwei Wortoptionen.
- Nach jeder Auswahl wechselt die App ohne weitere Bestaetigung zur naechsten Aufgabe.
- Nach Abschluss der Aufgaben erscheint die Craving-Abfrage mit der Frage `Wie hoch ist in diesem Moment Ihr Rauchverlangen?`, einem Slider von 0 bis 100, dem Standardwert 50 und dem Button `Absenden`.
- Cue-Bilder fuellen den sichtbaren Bildschirm durch eine Cover-Darstellung. Horizontales Zuschneiden ist zulaessig, leere Raender sind zu vermeiden.
- Match-Bilder bleiben vollstaendig sichtbar und werden ueber dem Cue-Bild im unteren Bildschirmbereich dargestellt.
- Wortoptionen werden ebenfalls ueber dem Cue-Bild im unteren Bildschirmbereich dargestellt.

### 2.3 Dynamische Ressourcen und Aufgabenlisten

Die Aufgabenlogik soll nicht von einer manuell gepflegten Vollstaendigkeitsliste der Drawables abhaengen:

- Cue-Matching-Items werden aus Drawables mit dem Namensschema `cue_0nn`, `match_a_0nn` und `match_b_0nn` erzeugt.
- Ein Cue-Matching-Item ist nur gueltig, wenn Cue-Bild und beide Match-Bilder vorhanden sind.
- Cue-Labeling-Items werden aus einem Cue-Bild und einem Labelpaar erzeugt.
- Die Labelpaare enthalten jeweils ein besser passendes und ein weniger passendes Label.
- Die Datenstruktur fuer Labelpaare muss spaeter ohne grundlegende Aenderung der UI auf weitere Sprachen, Kategorien, Scores oder externe Metadaten erweitert werden koennen.
- Bild- und Wortoptionen werden innerhalb eines Items zufaellig links/rechts beziehungsweise in der Reihenfolge vertauscht, um Positionsartefakte zu reduzieren.

### 2.4 Studienfortschritt, Sperrzeit und Randomisierung

Die App fuehrt die Teilnehmenden durch einen Within-Subject-Ablauf mit wiederholten Studiensituationen:

- Die App darf den Studienfortschritt lokal zwischenspeichern, betrachtet `completed_situation_count` aber nicht als autoritative Quelle. Der autoritative Fortschritt ergibt sich aus der vom Server verifizierten Anzahl akzeptierter Craving-Uebertragungen und der Anzahl gueltiger Token-Komponenten, die die App erhalten hat.
- Die App speichert lokal den Zeitpunkt der naechsten freigegebenen Situation, die Reihenfolge der Cue-Matching-Aufgaben und die bereits erhaltenen Token-Komponenten. Diese Werte sind ein Cache fuer Bedienbarkeit und Offline-Faelle, nicht die alleinige Grundlage der Auswertbarkeit.
- Die App stellt vor Beginn eines Durchgangs dar, ob die naechste Studiensituation gestartet werden kann. Die Freigabe ist nur dann produktiv gueltig, wenn der lokale Zustand mit dem serverseitig verifizierten Token- und Fortschrittszustand vereinbar ist.
- Zwischen zwei Studiensituationen liegt im Produktivbetrieb ein Mindestabstand von drei Stunden.
- Insgesamt sind 20 Studiensituationen vorgesehen: zehn Cue-Matching-Situationen und zehn Cue-Labeling-Situationen.
- Jede Studiensituation enthaelt immer fuenf Aufgaben, sodass insgesamt 50 Cue-Matching-Zuweisungen, 50 Cue-Labeling-Zuweisungen und 20 Craving-Selbstberichte entstehen.
- Die zufaellige Reihenfolge der Cue-Matching-Aufgaben wird einmal erzeugt und lokal gespeichert, damit sie ueber App-Neustarts hinweg stabil bleibt.
- Fuer Entwicklungs- oder Demonstrationszwecke duerfen kuerzere Wartezeiten nur ueber eindeutig benannte Debug- oder Staging-Konfigurationen aktiviert werden. Die Produktionswerte bleiben fachlich konsistent: vier Sekunden Betrachtungs-Countdown beim Cue-Matching und drei Stunden Sperrzeit zwischen Studiensituationen.

### 2.5 Build-Varianten und Endpunkte

Die Android-Konfiguration unterscheidet Umgebungen:

- `staging` verwendet einen lokalen oder internen Test-Endpunkt und darf eine abweichende Application-ID erhalten.
- `production` verwendet den produktiven HTTPS-Endpunkt `https://cuelens.each-and-every.de/submit`.
- Der Submit-Endpunkt wird nicht hart im UI-Code dupliziert, sondern ueber `BuildConfig` oder eine vergleichbare Build-Konfiguration bereitgestellt.
- Produktivvarianten duerfen keine Klartext-Kommunikation benoetigen. Falls Staging temporar HTTP verwendet, muss dies im Manifest und in der Dokumentation als lokale Testausnahme klar abgrenzbar sein.
- Craving-Uebertragungen an `submit.php` erfolgen per `PUT`. `POST` wird fuer die auswertbare App-Uebertragung nicht mehr verwendet.

## 3. Soll-Zustand der aktuellen Android-App

### 3.1 Architektur

- `MainActivity` initialisiert die Compose-App und delegiert die Studienlogik an klar getrennte Composables und Hilfsfunktionen.
- Die Phasen werden explizit modelliert, beispielsweise als `StartGate`, `ImageMatching`, `WordMatching` und `CravingSubmission`.
- UI-Komponenten erhalten nur die fuer ihre Darstellung und Rueckmeldung notwendigen Daten.
- Netzwerk-, Ressourcen- und Persistenzlogik werden so gekapselt, dass sie spaeter in ViewModel-, Repository- oder Service-Klassen ausgelagert werden koennen, ohne das Studienverhalten zu veraendern.
- Der aktuelle Prototyp darf kompakt bleiben; neue Funktionalitaet soll jedoch nicht weiter in eine monolithische `MainActivity.kt` wachsen, wenn dadurch Testbarkeit und Dokumentierbarkeit leiden.

### 3.2 Datenmodell fuer Reizaufgaben

Verwende fuer die interne Studienlogik explizite Datenklassen. Mindestens erforderlich sind:

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
```

Fuer die auswertbare Studienfassung soll das Datenmodell um stabile IDs erweitert werden:

```kotlin
data class StudyTrial(
    val trialId: String,
    val situationIndex: Int,
    val condition: StudyCondition,
    val cueId: String,
    val optionAId: String,
    val optionBId: String,
    val correctOrFittingOptionId: String?
)

enum class StudyCondition { CUE_MATCHING, CUE_LABELING }
```

Die stabile ID ist fuer Dokumentation, Plausibilitaetspruefung und Auswertung wichtiger als die aktuelle Drawable-ID, weil Drawable-IDs nicht als dauerhafte wissenschaftliche Kennungen geeignet sind.

### 3.3 Lokaler Zustand

Der lokale Zustand dient nur der Durchfuehrung der Studie, der Wiederaufnahme nach App-Neustarts und der Vermeidung ungueltiger Mehrfachdurchlaeufe. Er ist nicht die autoritative Quelle fuer Auszahlung oder Auswertung:

- `verified_completed_situation_count`: Anzahl der vom Server akzeptierten Craving-Uebertragungen. Dieser Wert wird aus Serverantworten abgeleitet und darf nicht allein durch lokale UI-Aktionen erhoeht werden.
- `next_situation_available_at_millis`: fruehester Startzeitpunkt der naechsten Situation.
- `matching_order`: stabile zufaellige Reihenfolge der Cue-Matching-Aufgaben.
- `token_components`: die vom Server bereits zurueckgelieferten Token-Komponenten. Vor der ersten erfolgreichen Uebertragung ist diese Liste leer. Nach 20 erfolgreichen Uebertragungen besteht sie aus 20 Komponenten mit jeweils drei alphanumerischen Zeichen.
- `pending_submission`: ein abgeschlossener Durchgang, dessen Serverantwort noch nicht erfolgreich verarbeitet wurde.

Der bisherige Begriff `participant_app_token` wird fuer die produktive App nicht mehr als vorab vergebener Teilnehmenden-Token verwendet. Die App erhaelt den Auszahlungstoken komponentenweise vom Submit-Endpunkt. Dieser Token ist ein serverseitig verifizierter Nachweis der abgeschlossenen App-Uebertragungen, aber keine direkte Relation zu den Craving-Werten.

Lokale Daten sollen klein bleiben und keine Namen, E-Mail-Adressen, IBANs, BICs oder Freitexte enthalten. Fuer produktive Studiendaten ist zu pruefen, ob `EncryptedSharedPreferences` oder ein anderes Jetpack-Security-Verfahren erforderlich und mit dem Studienprototyp vereinbar ist. Fuer besonders sensible Bildschirmansichten, insbesondere die abschliessende Token-Anzeige, ist `FLAG_SECURE` zu pruefen.

### 3.4 Netzwerkanbindung und serverseitig verifizierter Token-Fortschritt

Die App sendet Studienereignisse ausschliesslich an definierte Backend-Endpunkte:

- Craving-Selbstberichte werden per `PUT` uebertragen.
- Die Payload ist maschinenlesbar und enthaelt nur die fuer Studienauswertung, Idempotenz und Token-Fortschritt erforderlichen Angaben.
- Jede Uebertragung wird clientseitig und serverseitig validiert.
- Die App zeigt keine internen Server-, SQL- oder Stacktrace-Details an.
- Der UI-Zustand nach einem Netzwerkfehler muss eindeutig sein: Ein abgeschlossener Durchgang bleibt als noch nicht bestaetigt gespeichert, bis der Server entweder eine neue Token-Komponente oder bei Retry dieselbe ausstehende Token-Komponente erneut zurueckliefert.

Fuer die auswertbare Studienfassung wird der bisherige reine `craving`-Request durch ein strukturiertes PUT-Ereignis ersetzt. Der fachlich benoetigte Payload umfasst:

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

Bedeutung der Felder:

- `token_components`: alle Token-Komponenten, die die App bis zu diesem Zeitpunkt vom Server erhalten hat. Beim ersten Craving-Wert ist die Liste leer.
- `situation_index`: Index der abgeschlossenen Studiensituation. Die Zaehlweise muss in App, Backend und Auswertung identisch dokumentiert werden.
- `condition`: experimentelle Bedingung der abgeschlossenen Situation.
- `trial_count`: immer `5`; das Feld wird dennoch uebertragen, damit unvollstaendige oder manipulierte Durchgaenge serverseitig erkannt werden koennen.
- `craving`: ganzzahliger Wert von 0 bis 100.
- `client_timestamp`: technischer Zeitstempel der App zur Plausibilitaetspruefung, nicht als medizinisch exakter Ereigniszeitpunkt zu interpretieren.
- `app_version`: Version der App zur Nachvollziehbarkeit technischer Aenderungen.

Die konkrete Ausgestaltung folgt dem datensparsamen Token-Konzept: Craving-Werte und Token-Tabelle duerfen nicht relational miteinander verknuepft werden. Der Token dient der spaeteren Teilnahme- und Auszahlungspruefung, nicht der wissenschaftlichen Analyse des Rauchverlangens.

## 4. Noch zu entwickelnde Anforderungen aus Expose und aktuellem Masterarbeitsstand

### 4.1 Studienfreischaltung, Teilnahmeberechtigung und Tokenausgabe

Implementiere die Teilnahmefreischaltung so, dass die App keine personenbezogenen Registrierungsdaten speichern muss und der Abschlussnachweis erst nach erfolgreicher App-Nutzung entsteht:

1. Die App bietet beim ersten Start keine Eingabe eines personenbezogenen Accounts und keinen vorab fest zugeteilten `participant_app_token` an.
2. Die Teilnahmeberechtigung wird organisatorisch ueber Registrierung, Einwilligung und Bereitstellung der App beziehungsweise Studienanleitung hergestellt. Die App selbst verarbeitet dafuer keine Namen, E-Mail-Adressen oder Zahlungsdaten.
3. Der serverseitig verifizierte Token entsteht erst durch erfolgreiche Craving-Uebertragungen an `submit.php`.
4. `submit.php` erzeugt fuer eine neue App-Installation beim ersten gueltigen Craving-PUT einen Token aus 20 Komponenten mit jeweils drei alphanumerischen Zeichen.
5. Die erste Token-Komponente muss unter den maximal 85 geplanten Teilnehmenden eindeutig sein. Die Datenbank erzwingt diese Eindeutigkeit, und der Server generiert bei Kollisionen neu.
6. Der Server gibt bei der ersten gueltigen Uebertragung die erste Token-Komponente zurueck.
7. Bei jeder folgenden Uebertragung sendet die App alle bisher erhaltenen Token-Komponenten mit. Der Server prueft diese Komponenten gegen die Token-Tabelle und gibt die jeweils naechste Komponente zurueck.
8. Die App zeigt den Token den Teilnehmenden erst nach Abschluss aller 20 Studiensituationen beziehungsweise nach Erhalt aller 20 Komponenten an.
9. Die abschliessende Token-Anzeige muss kopier- und abschreibbar sein, aber keine Craving-Werte, Bedingungen oder Zeitpunkte enthalten.
10. Der Token ist ein Abschluss- und Abrechnungsnachweis. Er darf in der wissenschaftlichen Craving-Tabelle nicht als Fremdschluessel, Teilnehmer-ID oder Auswertungsschluessel gespeichert werden.

Empfohlene serverseitige Token-Tabelle, ohne Relation zur Craving-Tabelle:

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
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CHECK (delivered_component_count BETWEEN 0 AND 20)
);
```

Hinweis zur Datensparsamkeit: Die Tabelle enthaelt keine E-Mail-Adresse, keinen Namen, keine Zahlungsdaten, keine Craving-Werte, keinen Fremdschluessel zur Craving-Tabelle und keinen Durchgangsinhalt. `delivered_component_count` speichert ausschliesslich, wie viele Komponenten an die App ausgeliefert wurden, damit eine verlorene Serverantwort idempotent wiederholt werden kann.

### 4.2 Uebermittlung auswertbarer Studienmetadaten

Erweitere die Datenerfassung so, dass die statistische Auswertung die Bedingungen eindeutig unterscheiden kann und der Server gleichzeitig die App-Uebertragungen verifiziert:

1. Jeder Craving-Selbstbericht wird per `PUT` gesendet.
2. Jeder Craving-Selbstbericht enthaelt eine Bedingung (`CUE_MATCHING` oder `CUE_LABELING`).
3. Jeder Selbstbericht enthaelt den Studiensituationsindex von 0 bis 19 oder 1 bis 20. Die Zaehlweise muss in App, Backend und Auswertung identisch sein.
4. Jeder Selbstbericht enthaelt `trial_count = 5`. Andere Werte werden serverseitig abgelehnt oder als nicht verwertbar markiert.
5. Die App sendet bei jeder Uebertragung alle bisher erhaltenen Token-Komponenten. Beim ersten Selbstbericht ist diese Liste leer.
6. Optional werden Trial-IDs oder Cue-IDs uebermittelt, wenn dies fuer Plausibilitaetspruefung und Dokumentation erforderlich ist. Diese IDs duerfen keine Relation zur Token-Tabelle herstellen.
7. Der Server verhindert doppelte Craving-Speicherung durch die Token-Komponentenlogik und den gespeicherten `delivered_component_count`.
8. Die App aktualisiert `verified_completed_situation_count` und die lokale Token-Komponentenliste erst nach einer gueltigen Serverantwort.
9. Nach 20 gueltigen Uebertragungen zeigt die App den aus 20 Komponenten bestehenden Token an und markiert die Studie lokal als abgeschlossen.

### 4.3 Idempotente Serverlogik fuer `submit.php`

`submit.php` ist fuer die auswertbare App-Uebertragung von POST auf PUT umzustellen. Der Endpunkt liest den Request-Body, validiert JSON und gibt JSON zurueck. Die serverseitige Logik folgt diesen Regeln:

1. **Erster gueltiger PUT ohne Token-Komponenten**
   - Voraussetzung: `token_components` ist eine leere Liste, `craving` liegt zwischen 0 und 100, `trial_count` ist 5, Bedingung und Situationsindex sind plausibel.
   - Der Server generiert 20 Token-Komponenten mit jeweils drei alphanumerischen Zeichen.
   - Die erste Komponente ist in `app_tokens.first_component` eindeutig. Bei Kollision generiert der Server einen neuen Token.
   - Der Server speichert den Craving-Wert in der Craving-Tabelle.
   - Der Server legt den Token in `app_tokens` an, setzt `delivered_component_count = 1` und gibt Komponente 1 zurueck.

2. **Normaler Folge-PUT mit `n` bisher erhaltenen Komponenten**
   - Voraussetzung: Der uebermittelte Komponenten-Prefix existiert in `app_tokens`, und `n == delivered_component_count`.
   - Der Server speichert den neuen Craving-Wert.
   - Der Server erhoeht `delivered_component_count` auf `n + 1`.
   - Der Server gibt die Komponente `n + 1` zurueck.

3. **Retry nach verlorener Token-Antwort**
   - Voraussetzung: Der uebermittelte Komponenten-Prefix existiert in `app_tokens`, und `n == delivered_component_count - 1`.
   - Der Server speichert den Craving-Wert nicht erneut.
   - Der Server veraendert `delivered_component_count` nicht.
   - Der Server gibt erneut die Komponente `n + 1` zurueck.

4. **Ungueltige oder nicht aus der App ableitbare Uebertragung**
   - Token-Prefix existiert nicht.
   - Token ist kuerzer als nach `delivered_component_count` zulaessig, also `n < delivered_component_count - 1`.
   - Token ist laenger als serverseitig ausgeliefert, also `n > delivered_component_count`.
   - Einzelne Komponenten haben nicht exakt drei alphanumerische Zeichen.
   - `trial_count` ist nicht 5 oder der Craving-Wert liegt ausserhalb 0 bis 100.
   - Ergebnis: HTTP 400 `Bad Request`, ohne Craving-Speicherung und ohne Aenderung der Token-Tabelle.

5. **Abschlussfall**
   - Nach Rueckgabe der 20. Komponente ist die App-Teilnahme aus Sicht des Tokenmechanismus vollstaendig.
   - Weitere PUTs mit 20 Komponenten werden nicht als neue Craving-Werte gespeichert.
   - Die konkrete Serverantwort fuer bereits abgeschlossene Tokens ist in `ASSUMPTIONS.md` festzuhalten, bis sie implementiert ist.

Die Craving-Tabelle speichert nur wissenschaftlich erforderliche Werte, zum Beispiel Craving-Wert, Bedingung, Situationsindex, Trial-Count, technische Zeitstempel und App-Version. Sie enthaelt keinen Fremdschluessel auf `app_tokens` und keine Token-Komponente. Dadurch bleibt der spaetere Abrechnungsnachweis technisch von den Craving-Werten getrennt.

### 4.4 Robuste Offline- und Retry-Logik der App

Alltagstauglichkeit erfordert, dass kurzzeitige Netzwerkprobleme nicht zu Datenverlust oder unklarer Studienteilnahme fuehren:

1. Ein abgeschlossener Durchgang wird lokal als `PendingSubmission` gespeichert, bevor die App den PUT sendet.
2. `PendingSubmission` enthaelt Craving-Wert, Bedingung, Situationsindex, `trial_count = 5`, App-Version, Zeitstempel und die zum Zeitpunkt der Uebertragung lokal bekannten Token-Komponenten.
3. Wenn der Server eine neue oder erneut ausgelieferte Token-Komponente zurueckgibt, fuegt die App diese Komponente lokal an, loescht `PendingSubmission` und erhoeht `verified_completed_situation_count` auf die Anzahl der lokalen Token-Komponenten.
4. Wenn die Verbindung abbricht oder die Serverantwort nicht verarbeitet werden kann, bleibt `PendingSubmission` erhalten und wird unveraendert erneut gesendet.
5. Die App versucht die erneute Uebertragung beim naechsten Start und vor Beginn einer neuen Studiensituation.
6. Der Nutzer oder die Nutzerin sieht einen knappen Status, ohne technische Details.
7. Der Server behandelt wiederholte Uebertragungen idempotent ueber den Komponenten-Prefix und `delivered_component_count`, nicht ueber eine direkte Relation zwischen Token und Craving-Wert.

### 4.5 Mehrsprachigkeit Deutsch/Englisch

Die Studie setzt Deutsch- oder Englischkenntnisse voraus. Die App soll deshalb mehrsprachig dokumentierbar und nutzbar sein:

1. Verschiebe sichtbare UI-Texte aus Kotlin in Android-Stringressourcen.
2. Fuehre mindestens `values/strings.xml` fuer Deutsch und `values-en/strings.xml` fuer Englisch.
3. Labelpaare erhalten eine Sprachzuordnung oder getrennte Ressourcen fuer Deutsch und Englisch.
4. Die App folgt der Systemsprache, sofern Deutsch oder Englisch verfuegbar ist.
5. Bei nicht unterstuetzter Systemsprache verwendet die App Deutsch oder eine klar definierte Standardsprache.
6. Studienrelevante Begriffe bleiben zwischen App, Studieninformation und Datenschutzerklaerung konsistent.

### 4.6 Benachrichtigungen als optionale Erinnerungsfunktion

Push- beziehungsweise lokale Benachrichtigungen sind als Standardfeature im Expose genannt und koennen die Durchfuehrung der Studie unterstuetzen. Implementiere sie erst nach stabiler Datenerfassung und Token-Idempotenz:

1. Verwende lokale Android-Benachrichtigungen, keine externen Push-Dienste, solange kein serverseitiger Push-Zweck erforderlich ist.
2. Frage die Benachrichtigungsberechtigung nur an, wenn die App die Erinnerungsfunktion erklaert.
3. Plane Erinnerungen anhand von `next_situation_available_at_millis`.
4. Benachrichtigungstexte bleiben neutral und stigmatisierungsarm, zum Beispiel `CueLens: Eine neue Studiensituation ist verfuegbar.`
5. Benachrichtigungen duerfen keine sensiblen Details wie Rauchverlangen, Rauchstatus oder medizinische Aussagen enthalten.
6. Die App funktioniert auch ohne Benachrichtigungsberechtigung.

### 4.7 Produktionskonstanten und Build-Absicherung

Stelle sicher, dass Debug- und Produktionsverhalten nicht versehentlich vermischt werden:

1. Fuehre Konstanten fuer Countdown, Sperrzeit, Situationszahl und Aufgabenanzahl zentral zusammen.
2. Lege produktive Werte in der Production-Variante fest: 4 Sekunden Cue-Betrachtung vor aktiven Bildoptionen, 3 Stunden Sperrzeit, 20 Situationen, 5 Aufgaben pro Situation.
3. Erlaube kuerzere Werte nur in Staging- oder Debug-Varianten.
4. Schreibe Unit-Tests oder Build-Konfigurationschecks, die Production-Werte pruefen.
5. Dokumentiere jede Abweichung in `ASSUMPTIONS.md` oder in dieser Datei.

### 4.8 Tests fuer Studienlogik, Tokenlogik und Ressourcenintegritaet

Die App soll vor produktiver Nutzung automatisiert pruefen lassen, ob die Studienlogik konsistent ist:

1. Unit-Test fuer `canStartSituation` ueber alle 20 Situationen.
2. Unit-Test fuer die Randomisierungs- und Persistenzlogik der Cue-Matching-Reihenfolge.
3. Test fuer die Vollstaendigkeit der Cue-Matching-Tripletts.
4. Test fuer die Vollstaendigkeit der Cue-Labeling-Labelpaare.
5. Test fuer die Slider-Grenzen 0 bis 100 und Integer-Rundung.
6. Test fuer die Zuordnung von Bedingung, Situationsindex und `trial_count = 5` in der Payload.
7. Test fuer den ersten PUT ohne Token-Komponenten und die Rueckgabe der ersten Token-Komponente.
8. Test fuer normale Folge-PUTs mit `n == delivered_component_count`.
9. Test fuer Retry-PUTs mit `n == delivered_component_count - 1`, ohne doppelte Craving-Speicherung.
10. Test fuer ungueltige Token-Prefixe, zu kurze Tokens und zu lange Tokens mit HTTP 400.
11. Instrumentierter Smoke-Test fuer Startbildschirm, eine Matching-Aufgabe, eine Labeling-Aufgabe, Craving-Screen und abschliessende Token-Anzeige.

### 4.9 Sicherheits- und Datenschutzhaertung der Android-App

Setze die fuer eine Gesundheits- beziehungsweise Studiendaten-App angemessenen Mindestmassnahmen um:

1. Entferne produktiv unnoetiges Logging oder reduziere es auf nicht-sensitive technische Statusmeldungen.
2. Keine Ausgabe von Tokens, Craving-Werten, Serverantworten oder personenbezogenen Angaben in Logcat.
3. Verwende HTTPS in Production und begrenze Klartextverkehr auf Staging, idealerweise ueber `network_security_config`.
4. Pruefe `FLAG_SECURE` fuer Bildschirme, auf denen sensible Studiendaten, Token oder persoenliche Hinweise angezeigt werden.
5. Speichere lokale Token-Komponenten und Pending-Submissions verschluesselt, wenn sie als sensibel eingestuft werden.
6. Keine sensiblen Daten in Zwischenablage, Screenshots, externem Speicher oder Mediengalerie, solange dies fuer die Tokenuebergabe nicht ausdruecklich vorgesehen und dokumentiert ist.
7. Bei spaeterer Kamera- oder Dateinutzung muessen Metadaten mit Datenschutzbezug entfernt und Zugriffe anderer Apps vermieden werden.
8. Dokumentiere alle Datenkategorien, Speicherorte und Uebertragungen parallel in der Masterarbeitstabelle `Datenherkunft und Speicherorte`.

### 4.10 Optionale KI-gestuetzte Bildklassifikation

Die KI-Funktion wird nachrangig gegenueber der auswertbaren Studienfassung behandelt. Implementiere sie nur, wenn die Grundstudie stabil laeuft:

1. Fuehre eine Schnittstelle fuer Reizerkennung ein, zum Beispiel `CueDetector` mit `detect(image): List<CueDetection>`.
2. Beginne mit einem Stub oder regelbasierten Mock, damit UI und Datenmodell testbar bleiben.
3. Kapsle ML Kit, LiteRT oder ein eigenes TFLite-Modell hinter derselben Schnittstelle.
4. Dokumentiere fuer jedes Modell mindestens Modellgroesse, Inferenzzeit, Speicherbedarf, Android-Mindestversion, Precision, Recall und F1.
5. Nutze KI-Ergebnisse nur zur Auswahl von Labels oder Vergleichsreizen, nicht zur Speicherung selbst aufgenommener Bilder, solange dies nicht datenschutzrechtlich explizit vorgesehen ist.
6. Verarbeite Kamerabilder moeglichst lokal auf dem Geraet.
7. Entferne EXIF- und Standortmetadaten, falls Dateien verarbeitet oder zwischengespeichert werden.
8. Biete weiterhin einen Studienmodus mit lokal gebuendelten Reizbildern ohne KI an, damit auch aeltere oder leistungsschwaechere Endgeraete teilnehmen koennen.

## 5. Vorgeschlagene naechste Implementierungsreihenfolge

1. **Produktionskonstanten und Build-Profile bereinigen**: Production-Werte fuer 4 Sekunden und 3 Stunden absichern; Staging-Werte getrennt halten.
2. **PUT-Vertrag fuer `submit.php` festlegen**: JSON-Request, JSON-Response, Statuscodes, Token-Komponentenformat und Fehlerfaelle definieren.
3. **Serverseitige Token-Tabelle einfuehren**: 20 Komponenten erzeugen, erste Komponente eindeutig halten, `delivered_component_count` speichern, keine Relation zu Craving-Werten herstellen.
4. **Payload fuer auswertbare Selbstberichte erweitern**: Bedingung, Situationsindex, `trial_count = 5`, App-Version und bisherige Token-Komponenten ergaenzen.
5. **Idempotente Submit-Logik implementieren**: Erstuebertragung, Folgeuebertragung, Retry nach verlorener Antwort und HTTP-400-Faelle sauber trennen.
6. **App-Zustand auf serverseitige Verifikation umstellen**: `verified_completed_situation_count` aus erhaltenen Token-Komponenten ableiten und lokale Fortschrittserhoehung erst nach gueltiger Serverantwort durchfuehren.
7. **Retry-Logik in der App einfuehren**: `PendingSubmission` lokal speichern, unveraendert erneut senden und nach Tokenantwort bereinigen.
8. **Mehrsprachigkeit umsetzen**: UI-Texte und Labelpaare fuer Deutsch und Englisch strukturieren.
9. **Tests fuer Studienlogik, Tokenlogik und Ressourcenintegritaet ergaenzen**: Unit-, Backend- und Instrumentierungstests fuer die Studiensequenz.
10. **Sicherheits- und Datenschutzhaertung abschliessen**: Logging, Klartextverkehr, lokale Speicherung, Screenshots und Netzwerkregeln pruefen.
11. **Optionale Erinnerungen implementieren**: lokale Benachrichtigungen anhand des naechsten freigegebenen Durchgangs.
12. **KI-Schnittstelle vorbereiten**: erst Stub, dann ML Kit oder LiteRT hinter austauschbarer Schnittstelle evaluieren.
13. **Dokumentationsabgleich**: Nach jeder technischen Aenderung diese Datei, `PROJECT_PLAN.md`, `ASSUMPTIONS.md`, relevante Tabellen in Kapitel 5 und die Studienlogik in Kapitel 6 synchronisieren.

## 6. Definition of Done fuer Codex-Aenderungen

Eine Aenderung gilt nur dann als abgeschlossen, wenn alle zutreffenden Punkte erfuellt sind:

- Die App baut in mindestens einer Staging- und einer Production-Variante.
- Die Aenderung veraendert die Studienlogik nicht unbeabsichtigt.
- Neue Datenfelder sind im Code benannt, im Backend-Vertrag beschrieben und fuer die Auswertung begruendet.
- Neue lokale Speicherungen sind nach Zweck, Lebensdauer und Schutzbedarf dokumentiert.
- Neue Berechtigungen sind technisch notwendig und dokumentiert.
- UI-Texte sind stigmatisierungsarm und enthalten keine Therapie- oder Wirksamkeitsversprechen.
- Fehlerfaelle fuehren zu einem eindeutigen UI-Zustand.
- Tests oder manuelle Acceptance Checks decken den Kernpfad ab.
- Craving-Werte werden bei Retry-Faellen nicht doppelt gespeichert.
- Die Token-Tabelle enthaelt keine Relation zur Craving-Tabelle.
- Die Dokumentation vermeidet Formulierungen wie `nur vorlaeufig`, `TODO` oder `spaeter klaeren`, wenn stattdessen eine konkrete Annahme, Begrenzung oder naechste Implementierung angegeben werden kann.
