# CueLens: Implementierungsanweisungen fuer Codex

Diese Datei beschreibt den Soll-Zustand der Android-App im Verzeichnis `cuelens` und dient zugleich als arbeitsnahe Vorlage fuer die spaetere technische Dokumentation der Masterarbeit. Die Reihenfolge orientiert sich zuerst an der bisherigen Git-Historie des Prototyps und anschliessend an den Anforderungen aus Expose, aktuellem LaTeX-Stand der Masterarbeit und Studienlogik.

## 1. Grundprinzipien fuer alle Aenderungen

- Arbeite inkrementell und halte die App als nativen Android-Prototyp in Kotlin mit Jetpack Compose einfach, wartbar und testbar.
- Behandle die App als Studienprototyp, nicht als Therapie-App. UI-Texte duerfen keine Heilungs-, Entwoehnungs- oder Wirksamkeitsversprechen enthalten.
- Priorisiere Datensparsamkeit, robuste Studienlogik, reproduzierbare Reizpraesentation, nachvollziehbare Zustandsuebergaenge und geringe technische Anforderungen an reale Android-Endgeraete.
- Nutze keine zusaetzlichen Berechtigungen, solange sie nicht fuer eine konkrete Funktion zwingend erforderlich sind. Jede neue Berechtigung muss im Quelltext, in dieser Datei und spaeter in der Arbeit begruendet werden.
- Verarbeite sensible Daten nur zweckgebunden. Personenbezogene Registrierungs- und Abrechnungsdaten gehoeren nicht in die Android-App und nicht in die wissenschaftlichen Selbstberichte.
- Halte alle Endpunkte, Build-Varianten und Konstanten so strukturiert, dass lokale Tests, Staging und Produktion getrennt nachvollziehbar bleiben.

## 2. Bisherige Git-Historie als Umsetzungsreihenfolge

### 2.1 Projektgeruest, Android-App und Craving-Endpunkt

Der erste relevante Entwicklungsschritt ist der Commit `1c27c1e6ade4c597ae56c6beb5ba6c6f228cb0b0` mit der Nachricht `CueLens Android app basic functionality, PHP craving endpoint`. Daraus ergibt sich fuer die Android-App folgender Soll-Zustand:

- Das Verzeichnis `cuelens` enthaelt ein eigenstaendiges Android-Projekt mit Gradle-Konfiguration, App-Modul, Android-Manifest und Kotlin-Quelltext.
- Die App ist eine native Android-Anwendung mit einer einzigen `MainActivity`.
- Die Benutzeroberflaeche wird mit Jetpack Compose aufgebaut.
- Die App darf im Studienprototyp nur die Internet-Berechtigung benoetigen.
- Die App ist fuer Hochformat ausgelegt, damit Bilddarstellung, Antwortoptionen und Craving-Slider unter kontrollierten Layoutbedingungen verwendet werden.
- Die automatische Android-Sicherung ist deaktiviert, damit lokale Fortschrittsdaten nicht ueber allgemeine Geraete- oder Cloud-Backups in weitere Kontexte uebertragen werden.
- Der Craving-Wert wird als ganzzahliger Wert im Bereich 0 bis 100 erhoben und per `application/x-www-form-urlencoded` an den konfigurierten Submit-Endpunkt uebertragen.
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

- Der lokale Fortschritt umfasst mindestens die Anzahl abgeschlossener Studiensituationen, den Zeitpunkt der naechsten freigegebenen Situation und die Reihenfolge der Cue-Matching-Aufgaben.
- Der Fortschritt wird lokal persistiert, damit App-Neustarts nicht zu einer Wiederholung oder zum Verlust der Studiensequenz fuehren.
- Die App stellt vor Beginn eines Durchgangs dar, ob die naechste Studiensituation gestartet werden kann.
- Zwischen zwei Studiensituationen liegt im Produktivbetrieb ein Mindestabstand von drei Stunden.
- Insgesamt sind 20 Studiensituationen vorgesehen: zehn Cue-Matching-Situationen und zehn Cue-Labeling-Situationen.
- Jede Studiensituation enthaelt fuenf Aufgaben, sodass insgesamt 50 Cue-Matching-Zuweisungen, 50 Cue-Labeling-Zuweisungen und 20 Craving-Selbstberichte entstehen.
- Die zufaellige Reihenfolge der Cue-Matching-Aufgaben wird einmal erzeugt und lokal gespeichert, damit sie ueber App-Neustarts hinweg stabil bleibt.
- Fuer Entwicklungs- oder Demonstrationszwecke duerfen kuerzere Wartezeiten nur ueber eindeutig benannte Debug- oder Staging-Konfigurationen aktiviert werden. Die Produktionswerte bleiben fachlich konsistent: vier Sekunden Betrachtungs-Countdown beim Cue-Matching und drei Stunden Sperrzeit zwischen Studiensituationen.

### 2.5 Build-Varianten und Endpunkte

Die Android-Konfiguration unterscheidet Umgebungen:

- `staging` verwendet einen lokalen oder internen Test-Endpunkt und darf eine abweichende Application-ID erhalten.
- `production` verwendet den produktiven HTTPS-Endpunkt `https://cuelens.each-and-every.de/submit`.
- Der Submit-Endpunkt wird nicht hart im UI-Code dupliziert, sondern ueber `BuildConfig` oder eine vergleichbare Build-Konfiguration bereitgestellt.
- Produktivvarianten duerfen keine Klartext-Kommunikation benoetigen. Falls Staging temporar HTTP verwendet, muss dies im Manifest und in der Dokumentation als lokale Testausnahme klar abgrenzbar sein.

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

Der lokale Zustand dient nur der Durchfuehrung der Studie und der Vermeidung ungueltiger Mehrfachdurchlaeufe:

- `completed_situation_count`: Anzahl abgeschlossener Studiensituationen.
- `next_situation_available_at_millis`: fruehester Startzeitpunkt der naechsten Situation.
- `matching_order`: stabile zufaellige Reihenfolge der Cue-Matching-Aufgaben.
- `participant_app_token` oder aequivalenter pseudonymer App-Schluessel: nur falls fuer Freischaltung, Plausibilitaet oder Abrechnung erforderlich.

Lokale Daten sollen klein bleiben und keine Namen, E-Mail-Adressen, IBANs, BICs oder Freitexte enthalten. Fuer produktive Studiendaten ist zu pruefen, ob `EncryptedSharedPreferences` oder ein anderes Jetpack-Security-Verfahren erforderlich und mit dem Studienprototyp vereinbar ist. Fuer besonders sensible Bildschirmansichten ist `FLAG_SECURE` zu pruefen.

### 3.4 Netzwerkanbindung

Die App sendet Studienereignisse ausschliesslich an definierte Backend-Endpunkte:

- Craving-Selbstberichte werden per POST uebertragen.
- Die Payload bleibt minimal und maschinenlesbar.
- Jede Uebertragung wird clientseitig und serverseitig validiert.
- Die App zeigt keine internen Server-, SQL- oder Stacktrace-Details an.
- Der UI-Zustand nach einem Netzwerkfehler muss eindeutig sein: Entweder bleibt der Selbstbericht als noch nicht uebertragen markiert, oder die App erklaert, dass die Uebermittlung erneut versucht werden muss.

Fuer die auswertbare Studienfassung soll der bisherige reine `craving`-POST zu einem strukturierten Studienereignis erweitert werden. Minimal sinnvoll ist:

```json
{
  "app_token": "pseudonymous-random-token",
  "situation_index": 0,
  "condition": "CUE_MATCHING",
  "trial_count": 5,
  "craving": 50,
  "client_timestamp": "2026-06-28T12:00:00Z",
  "app_version": "1.0"
}
```

Die konkrete Ausgestaltung muss mit dem Datenschutzkonzept abgestimmt werden. Falls eine Trennung zwischen wissenschaftlichen Selbstberichten und Abrechnungsnachweis vorgesehen ist, darf der Abrechnungstoken nicht ohne Not direkt mit Craving-Werten verknuepft werden.

## 4. Noch zu entwickelnde Anforderungen aus Expose und aktuellem Masterarbeitsstand

### 4.1 Studienfreischaltung und Teilnahmeberechtigung

Implementiere eine datensparsame Freischaltung der App-Nutzung:

1. Die App bietet beim ersten Start eine Eingabe oder Uebergabe eines pseudonymen App-Tokens an.
2. Der Token wird nicht aus Name, E-Mail-Adresse oder Bankdaten abgeleitet, sondern zufaellig erzeugt beziehungsweise serverseitig zugeteilt.
3. Die App prueft vor dem Start einer Studiensituation, ob der Token freigeschaltet ist und die Einwilligung nicht widerrufen wurde.
4. Bei fehlender Freischaltung zeigt die App einen neutralen Hinweis auf die Registrierung und die Studienfreigabe.
5. Der Token wird lokal gespeichert und kann ueber eine Support- oder Abbruchfunktion entfernt werden.

Diese Funktion steht in der Implementierungsreihenfolge vor der produktiven Datenerhebung, weil die aktuelle Studienbeschreibung voraussetzt, dass die App-Nutzung fuer die verknuepfte E-Mail-Adresse beziehungsweise Teilnahmefreigabe kontrolliert wird.

### 4.2 Uebermittlung auswertbarer Studienmetadaten

Erweitere die Datenerfassung so, dass die statistische Auswertung die Bedingungen eindeutig unterscheiden kann:

1. Jeder Craving-Selbstbericht enthaelt eine Bedingung (`CUE_MATCHING` oder `CUE_LABELING`).
2. Jeder Selbstbericht enthaelt den Studiensituationsindex von 0 bis 19 oder 1 bis 20. Die Zaehlweise muss in App, Backend und Auswertung identisch sein.
3. Jeder Selbstbericht enthaelt die Anzahl tatsaechlich bearbeiteter Aufgaben in dieser Situation.
4. Optional werden Trial-IDs oder Cue-IDs uebermittelt, wenn dies fuer Plausibilitaetspruefung und Dokumentation erforderlich ist.
5. Der Server verhindert oder markiert doppelte Selbstberichte derselben Situation.
6. Die App aktualisiert den lokalen Fortschritt erst dann endgueltig, wenn die Uebermittlung erfolgreich abgeschlossen oder ein lokaler Retry-Zustand angelegt wurde.

### 4.3 Robuste Offline- und Retry-Logik

Alltagstauglichkeit erfordert, dass kurzzeitige Netzwerkprobleme nicht zu Datenverlust oder unklarer Studienteilnahme fuehren:

1. Ein abgeschlossener Durchgang wird lokal als `PendingSubmission` gespeichert, wenn die Uebertragung nicht erfolgreich ist.
2. Pending-Datensaetze enthalten nur die fuer die Uebermittlung erforderlichen pseudonymen und experimentellen Angaben.
3. Die App versucht die erneute Uebertragung beim naechsten Start und vor Beginn einer neuen Studiensituation.
4. Der Nutzer oder die Nutzerin sieht einen knappen Status, ohne technische Details.
5. Nach erfolgreicher Uebertragung wird der Pending-Datensatz geloescht.
6. Der Server behandelt wiederholte Uebertragungen idempotent, beispielsweise ueber `app_token + situation_index`.

### 4.4 Mehrsprachigkeit Deutsch/Englisch

Die Studie setzt Deutsch- oder Englischkenntnisse voraus. Die App soll deshalb mehrsprachig dokumentierbar und nutzbar sein:

1. Verschiebe sichtbare UI-Texte aus Kotlin in Android-Stringressourcen.
2. Fuehre mindestens `values/strings.xml` fuer Deutsch und `values-en/strings.xml` fuer Englisch.
3. Labelpaare erhalten eine Sprachzuordnung oder getrennte Ressourcen fuer Deutsch und Englisch.
4. Die App folgt der Systemsprache, sofern Deutsch oder Englisch verfuegbar ist.
5. Bei nicht unterstuetzter Systemsprache verwendet die App Deutsch oder eine klar definierte Standardsprache.
6. Studienrelevante Begriffe bleiben zwischen App, Studieninformation und Datenschutzerklaerung konsistent.

### 4.5 Benachrichtigungen als optionale Erinnerungsfunktion

Push- beziehungsweise lokale Benachrichtigungen sind als Standardfeature im Expose genannt und koennen die Durchfuehrung der Studie unterstuetzen. Implementiere sie erst nach stabiler Freischaltung und Datenerfassung:

1. Verwende lokale Android-Benachrichtigungen, keine externen Push-Dienste, solange kein serverseitiger Push-Zweck erforderlich ist.
2. Frage die Benachrichtigungsberechtigung nur an, wenn die App die Erinnerungsfunktion erklaert.
3. Plane Erinnerungen anhand von `next_situation_available_at_millis`.
4. Benachrichtigungstexte bleiben neutral und stigmatisierungsarm, zum Beispiel `CueLens: Eine neue Studiensituation ist verfuegbar.`
5. Benachrichtigungen duerfen keine sensiblen Details wie Rauchverlangen, Rauchstatus oder medizinische Aussagen enthalten.
6. Die App funktioniert auch ohne Benachrichtigungsberechtigung.

### 4.6 Produktionskonstanten und Build-Absicherung

Stelle sicher, dass Debug- und Produktionsverhalten nicht versehentlich vermischt werden:

1. Fuehre Konstanten fuer Countdown, Sperrzeit, Situationszahl und Aufgabenanzahl zentral zusammen.
2. Lege produktive Werte in der Production-Variante fest: 4 Sekunden Cue-Betrachtung vor aktiven Bildoptionen, 3 Stunden Sperrzeit, 20 Situationen, 5 Aufgaben pro Situation.
3. Erlaube kuerzere Werte nur in Staging- oder Debug-Varianten.
4. Schreibe Unit-Tests oder Build-Konfigurationschecks, die Production-Werte pruefen.
5. Dokumentiere jede Abweichung in `ASSUMPTIONS.md` oder in dieser Datei.

### 4.7 Tests fuer Studienlogik und Ressourcenintegritaet

Die App soll vor produktiver Nutzung automatisiert pruefen lassen, ob die Studienlogik konsistent ist:

1. Unit-Test fuer `canStartSituation` ueber alle 20 Situationen.
2. Unit-Test fuer die Randomisierungs- und Persistenzlogik der Cue-Matching-Reihenfolge.
3. Test fuer die Vollstaendigkeit der Cue-Matching-Tripletts.
4. Test fuer die Vollstaendigkeit der Cue-Labeling-Labelpaare.
5. Test fuer die Slider-Grenzen 0 bis 100 und Integer-Rundung.
6. Test fuer die Zuordnung von Bedingung und Situationsindex in der Payload.
7. Instrumentierter Smoke-Test fuer Startbildschirm, eine Matching-Aufgabe, eine Labeling-Aufgabe und Craving-Screen.

### 4.8 Sicherheits- und Datenschutzhaertung der Android-App

Setze die fuer eine Gesundheits- beziehungsweise Studiendaten-App angemessenen Mindestmassnahmen um:

1. Entferne produktiv unnoetiges Logging oder reduziere es auf nicht-sensitive technische Statusmeldungen.
2. Keine Ausgabe von Tokens, Craving-Werten, Serverantworten oder personenbezogenen Angaben in Logcat.
3. Verwende HTTPS in Production und begrenze Klartextverkehr auf Staging, idealerweise ueber `network_security_config`.
4. Pruefe `FLAG_SECURE` fuer Bildschirme, auf denen sensible Studiendaten, Token oder persoenliche Hinweise angezeigt werden.
5. Speichere lokale Token und Pending-Submissions verschluesselt, wenn sie als sensibel eingestuft werden.
6. Keine sensiblen Daten in Zwischenablage, Screenshots, externem Speicher oder Mediengalerie.
7. Bei spaeterer Kamera- oder Dateinutzung muessen Metadaten mit Datenschutzbezug entfernt und Zugriffe anderer Apps vermieden werden.
8. Dokumentiere alle Datenkategorien, Speicherorte und Uebertragungen parallel in der Masterarbeitstabelle `Datenherkunft und Speicherorte`.

### 4.9 Optionale KI-gestuetzte Bildklassifikation

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
2. **Payload fuer auswertbare Selbstberichte erweitern**: Bedingung, Situationsindex, App-Version und pseudonymer Token ergaenzen; Backend-Vertrag parallel festlegen.
3. **Teilnahmefreischaltung implementieren**: App-Token speichern, Serverfreigabe pruefen, widerrufene Teilnahme sperren.
4. **Retry- und Idempotenzlogik einfuehren**: Pending-Submissions lokal speichern und idempotent uebertragen.
5. **Mehrsprachigkeit umsetzen**: UI-Texte und Labelpaare fuer Deutsch und Englisch strukturieren.
6. **Tests fuer Studienlogik und Ressourcenintegritaet ergaenzen**: Unit- und Instrumentierungstests fuer die Studiensequenz.
7. **Sicherheits- und Datenschutzhaertung abschliessen**: Logging, Klartextverkehr, lokale Speicherung, Screenshots und Netzwerkregeln pruefen.
8. **Optionale Erinnerungen implementieren**: lokale Benachrichtigungen anhand des naechsten freigegebenen Durchgangs.
9. **KI-Schnittstelle vorbereiten**: erst Stub, dann ML Kit oder LiteRT hinter austauschbarer Schnittstelle evaluieren.
10. **Dokumentationsabgleich**: Nach jeder technischen Aenderung diese Datei, `PROJECT_PLAN.md`, relevante Tabellen in Kapitel 5 und die Studienlogik in Kapitel 6 synchronisieren.

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
- Die Dokumentation vermeidet Formulierungen wie `nur vorlaeufig`, `TODO` oder `spaeter klaeren`, wenn stattdessen eine konkrete Annahme, Begrenzung oder naechste Implementierung angegeben werden kann.
