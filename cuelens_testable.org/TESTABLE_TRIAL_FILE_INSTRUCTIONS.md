# CueLens – Instruktionen zur Erstellung der Testable-Trial-Files

## 1. Zweck und Geltungsbereich

Dieses Dokument definiert die Anforderungen für die spätere Erstellung eines oder mehrerer Trial Files für `testable.org`, mit denen der **produktive Studienablauf der CueLens-App methodisch 1:1 nachgestellt** werden soll.

Die Referenz ist der aktuelle `main`-Stand des Repositorys `stefan-bmio/master-thesis`, insbesondere:

- `cuelens/app/src/main/java/de/eachandevery/cuelens/MainActivity.kt` – produktiver Studienablauf,
- `cuelens/app/src/main/res/values/strings.xml` und `values-en/strings.xml` – deutsche und englische Texte,
- `cuelens/app/build.gradle.kts` – produktiver Mindestabstand zwischen Durchgängen,
- `cuelens-ios/PLATFORM_INDEPENDENT_SPECIFICATION.md` – plattformunabhängige Formalisierung der Studieninvarianten.

Nicht Gegenstand der Trial Files sind App-Aktivierung, Infofeed, Feedbackformular, Push-Benachrichtigungen, App-Token-Verwaltung oder das CueLens-PHP-Backend. Diese Funktionen gehören nicht zur eigentlichen experimentellen Aufgabe und sollen nicht künstlich in Testable nachgebaut werden.

Datenschutz- und Sicherheitsfunktionen, die eindeutig von Testable selbst bereitgestellt oder konfiguriert werden, werden in diesem Dokument nicht technisch nachimplementiert. Für die Trial Files gilt jedoch weiterhin **Datenminimierung**: Es dürfen nur Daten erhoben werden, die für Durchführung, Zuordnung und Auswertung der Studie erforderlich sind.

---

## 2. Priorität der Anforderungen

Bei Widersprüchen gilt folgende Reihenfolge:

1. **Studienmethodische Invarianten der produktiven CueLens-App** dürfen nicht verändert werden.
2. Das tatsächliche Verhalten der Android-Referenzimplementierung hat Vorrang vor einer vereinfachten Testable-Umsetzung.
3. Die Testable-Implementierung soll vorhandene native Testable-Funktionen bevorzugen.
4. Eine technische Einschränkung von Testable darf **nicht stillschweigend durch eine methodische Abweichung** ersetzt werden.
5. Ist eine 1:1-Umsetzung einer studienrelevanten Eigenschaft nicht möglich, muss dies vor der Erzeugung der finalen Trial Files ausdrücklich dokumentiert und entschieden werden.

---

## 3. Verbindliche Studieninvarianten

| Merkmal | Verbindlicher Wert |
|---|---:|
| Design | Within-Subject |
| Produktive Durchgänge insgesamt | 20 |
| Cue-Matching-Durchgänge | 10 |
| Cue-Labeling-Durchgänge | 10 |
| Reihenfolge der Bedingungen | zuerst 10 × Cue-Matching, danach 10 × Cue-Labeling |
| Trials je Durchgang | 5 |
| Cue-Matching-Trials insgesamt | 50 |
| Cue-Labeling-Trials insgesamt | 50 |
| Selbstberichte zum Rauchverlangen | 20 |
| Rauchverlangensskala | ganzzahlig 0–100 |
| Startwert des Sliders | 50 |
| Mindestabstand zwischen bestätigten Durchgängen | 3 Stunden |
| Auswahl-Sperrzeit beim produktiven Cue-Matching | 4 Sekunden |
| Auswahl-Sperrzeit beim Cue-Labeling | keine |
| technisch erzwungene maximale Durchgänge pro Tag | keine |
| wissenschaftlich zu speichernde Matching-/Labeling-Auswahl | keine |
| primärer wissenschaftlicher Messwert | Rauchverlangen je Durchgang |

Die organisatorische Studienanweisung kann bis zu drei Durchgänge pro Tag vorsehen. Die App erzwingt jedoch **nur** den Mindestabstand von drei Stunden. Testable darf daher ebenfalls keine zusätzliche kalendertägliche Begrenzung einführen.

---

## 4. Kritische Machbarkeitsprüfungen vor Erstellung der finalen Trial Files

Die folgenden Punkte sind vor einer produktiven Umsetzung mit Testable zu verifizieren. Solange einer dieser Punkte ungeklärt ist, darf eine Trial-File-Lösung nur als Prototyp gelten.

### 4.1 Mehrtägige Teilnahme und persistenter 3-Stunden-Abstand

CueLens ist keine einmalige kurze Webaufgabe. Die 20 Durchgänge werden über mehrere Tage durchgeführt. Nach jedem erfolgreich abgeschlossenen Durchgang beginnt ein **wall-clock-basierter Mindestabstand von drei Stunden**.

Die Testable-Dokumentation beschreibt eine `Participation time limit`, innerhalb derer Teilnehmende zu einer begonnenen Teilnahme zurückkehren können. Sie dokumentiert jedoch nicht hinreichend eindeutig, dass sich damit der CueLens-Cooldown über Browser-Schließen, Geräte-Sperren oder erneutes Öffnen exakt wie in der App persistieren lässt.

Vor der finalen Umsetzung muss deshalb geprüft werden:

- Wird beim erneuten Öffnen exakt an der richtigen Stelle der laufenden Teilnahme fortgesetzt?
- Bleibt ein einmal gestarteter 3-Stunden-Cooldown über Schließen und erneutes Öffnen erhalten?
- Kann der nächste Durchgang zuverlässig bis zum ursprünglichen Freischaltzeitpunkt blockiert werden?
- Wird der Cooldown **nicht** beim Reload oder erneuten Öffnen auf drei Stunden zurückgesetzt?
- Muss der Browser während der drei Stunden geöffnet bleiben? Falls ja, ist die Anforderung nicht erfüllt.

Ein einfacher 3-Stunden-Countdown, der nur bei geöffnetem Browser korrekt läuft, ist **kein** 1:1-Ersatz.

### 4.2 Keine Speicherung der Matching- und Labeling-Auswahl

Die CueLens-App verwendet die Auswahlreaktionen nur zur Navigation zum nächsten Trial. Sie werden **weder dauerhaft gespeichert noch an das Forschungsbackend übertragen**.

Die öffentlich dokumentierten Testable-Funktionen beschreiben die Speicherung von Trial- und Response-Daten, zeigen aber derzeit keine eindeutig dokumentierte per-Trial-Option, mit der eine zur Navigation notwendige Antwort vollständig von der Ergebnisspeicherung ausgeschlossen werden kann.

Vor der finalen Umsetzung muss daher geklärt werden, ob die Reaktionen der 100 Matching-/Labeling-Trials vollständig aus den gespeicherten Ergebnissen ausgeschlossen werden können.

**MUSS-Kriterium:** Wenn Testable diese Reaktionen zwingend speichert und keine geeignete Nicht-Speichern-Funktion anbietet, ist die gewünschte 1:1-Umsetzung hinsichtlich Datenminimierung nicht erreicht. In diesem Fall darf die zusätzliche Datenerhebung nicht stillschweigend akzeptiert werden.

### 4.3 Zwischenspeicherung bereits abgeschlossener Durchgänge

Die CueLens-App überträgt nach jedem Durchgang genau einen Craving-Wert. Ein bereits bestätigter Durchgang bleibt auch dann erhalten, wenn die Teilnahme später abgebrochen wird.

Testable dokumentiert für Ergebnisexporte, dass Ergebnisse erst nach Erreichen des Debrief-Screens bereitgestellt werden und partielle Ergebnisse nicht gespeichert werden. Für eine mehrtägige 20-Durchgänge-Teilnahme ist deshalb vorab zu klären, ob bereits abgeschlossene Durchgänge serverseitig zuverlässig erhalten bleiben, wenn die Person die Gesamtstudie nicht bis zum letzten Durchgang abschließt.

**MUSS-Kriterium:** Bereits bestätigte Craving-Werte dürfen durch einen späteren Studienabbruch nicht verloren gehen, wenn der Testable-Ablauf das App-Verhalten wirklich 1:1 nachbilden soll.

### 4.4 Konsequenz für die Projektarchitektur

Erst nach Klärung der Punkte 4.1–4.3 wird entschieden, ob die Umsetzung aus

- **einem Testable-Projekt mit einem mehrtägigen Trial File** oder
- **mehreren Testable-Projekten/Trial Files**

bestehen kann.

Eine Aufteilung in 20 einzelne Projekte darf nur gewählt werden, wenn dabei nachweislich

- dieselben Teilnehmenden durch alle 20 Durchgänge geführt werden können,
- die Reihenfolge 1–20 erhalten bleibt,
- der 3-Stunden-Abstand erzwungen werden kann,
- die globale Matching-Randomisierung über die ersten 10 Durchgänge erhalten bleibt und
- die Daten über alle Durchgänge eindeutig derselben pseudonymen Testable-Teilnahme zugeordnet werden können.

Testable-Minds-`Sessions` sind hierfür **nicht automatisch geeignet**: Nach aktueller Testable-Dokumentation werden Teilnehmende von weiteren Sessions derselben Studie ausgeschlossen. Eine Session darf daher nicht mit einem CueLens-Durchgang gleichgesetzt werden.

---

## 5. Vorgesehene Dateistruktur

Sofern die Machbarkeitsprüfung eine Umsetzung erlaubt, soll die Definition möglichst modular bleiben.

Empfohlene Dateien:

```text
cuelens_testable/
├── cuelens_trials.csv
├── matching_items.csv
├── labeling_items.csv
└── assets/
    ├── cue_000 ... cue_049
    ├── match_a_000 ... match_a_049
    └── match_b_000 ... match_b_049
```

Falls Testable für Deutsch und Englisch keine saubere Laufzeitumschaltung innerhalb desselben Projekts erlaubt, dürfen zwei sprachspezifische Trial Files erstellt werden:

```text
cuelens_trials_de.csv
cuelens_trials_en.csv
```

Die beiden Sprachfassungen müssen **inhaltlich, methodisch, zeitlich und strukturell identisch** sein. Nur die sichtbaren Texte und Labels dürfen sich unterscheiden.

### 5.1 `matching_items.csv`

Enthält genau 50 vollständige Cue-Matching-Items. Pro Item werden nur die für die Darstellung erforderlichen statischen Angaben geführt, beispielsweise:

- `item_id` (`000`–`049`),
- Cue-Datei,
- Match-A-Datei,
- Match-B-Datei.

Es dürfen keine Teilnehmerdaten in dieser Datei stehen.

### 5.2 `labeling_items.csv`

Enthält genau die 50 Cue-Label-Zuordnungen der Referenz-App. Pro Item werden mindestens benötigt:

- `item_id`,
- Cue-Datei,
- Label A Deutsch,
- Label B Deutsch,
- Label A Englisch,
- Label B Englisch.

Die Labels sind **nicht neu zu formulieren**, sondern aus der Referenzimplementierung beziehungsweise deren Mapping zu übernehmen.

### 5.3 `cuelens_trials.csv`

Das Haupt-Trial-File bildet Navigation, Trialreihenfolge, Timing, Stimulusdarstellung und die 20 Craving-Abfragen ab.

Testable verwendet CSV-basierte Trial Files. Nach der aktuellen Dokumentation entspricht grundsätzlich jede Zeile einem Trial, einer Instruktionsseite oder einer Formularfrage; nur die Spalte `type` ist zwingend erforderlich. Zusätzliche Spalten sollen nur verwendet werden, wenn sie für die Umsetzung notwendig sind.

---

## 6. Ablauf eines produktiven Durchgangs

Jeder der 20 Durchgänge muss diesem Zustandsmodell folgen:

```text
Start-Gate
   ↓
5 Matching- oder Labeling-Trials
   ↓
Craving-Abfrage 0–100
   ↓
aktive Bestätigung / Absenden
   ↓
Durchgang gilt als abgeschlossen
   ↓
3-Stunden-Cooldown
   ↓
Start-Gate des nächsten Durchgangs
```

Für Durchgang 20 folgt nach bestätigter Craving-Angabe der Studienabschluss statt eines weiteren Cooldowns.

### 6.1 Start-Gate

Vor jedem Durchgang soll funktional das Verhalten der App nachgebildet werden:

- Anzeige des Fortschritts `Durchgang n von 20` / `Run n of 20`,
- Start des nächsten Durchgangs nur, wenn der vorherige Durchgang bestätigt wurde,
- während des Cooldowns kein Start möglich,
- nach Ablauf des Cooldowns aktive Schaltfläche `Durchgang starten` / `Start run`.

Ein globaler Testable-Fortschrittsbalken soll nicht zusätzlich eingeblendet werden, wenn er in der Referenz-App nicht vorhanden ist.

---

## 7. Cue-Matching: Durchgänge 1–10

### 7.1 Globale Randomisierung der 50 Items

Beim ersten produktiven Cue-Matching-Zugriff muss **pro teilnehmender Person genau eine zufällige Permutation der 50 Cue-Matching-Item-Indizes** erzeugt werden.

Anforderungen:

1. Jeder Index `000`–`049` kommt genau einmal vor.
2. Die Permutation gilt über alle zehn Matching-Durchgänge hinweg.
3. Durchgang 1 verwendet Position 1–5 der Permutation, Durchgang 2 Position 6–10 usw.
4. Über zehn Durchgänge wird jeder der 50 Cues genau einmal gezeigt.
5. Ein Neuladen oder Unterbrechen darf nicht versehentlich eine neue globale 50er-Permutation erzeugen, wenn dadurch bereits verwendete Cues wiederholt oder andere ausgelassen würden.

Testable unterstützt Randomisierung sowie Listen/Wildcards. Für die finale Datei darf jedoch nur eine Konstruktion verwendet werden, die **ohne Zurücklegen und teilnehmerbezogen über alle 50 Matching-Trials konsistent** arbeitet.

### 7.2 Einzelner Matching-Trial

Für jedes Item:

1. Das Cue-Bild wird angezeigt.
2. Die beiden zugehörigen Match-Bilder werden gleichzeitig als Auswahl angeboten.
3. Die Reihenfolge/Position der beiden Match-Bilder wird **bei jeder Darbietung zufällig** bestimmt.
4. Das Cue-Bild ist sofort sichtbar.
5. Die Auswahl der Match-Bilder ist während der ersten **4.000 ms** deaktiviert.
6. Nach exakt vier Sekunden werden beide Optionen auswählbar.
7. Ein Tap/Klick auf eine aktive Option führt unmittelbar zum nächsten Trial.
8. Es gibt kein Feedback zu „richtig“ oder „falsch“.
9. Die Auswahl selbst darf nicht als wissenschaftlicher Messwert gespeichert werden.

Die Testable-Dokumentation verwendet Millisekunden für Timingparameter. Die 4-Sekunden-Sperre ist daher als `4000 ms` umzusetzen, nicht als ungefährer UI-Countdown.

---

## 8. Cue-Labeling: Durchgänge 11–20

Im Gegensatz zum Matching werden die Cue-Labeling-Cues **nicht global randomisiert**.

Verbindliche Reihenfolge:

- Durchgang 11: `cue_000`–`cue_004`,
- Durchgang 12: `cue_005`–`cue_009`,
- …
- Durchgang 20: `cue_045`–`cue_049`.

Für jeden Labeling-Trial:

1. Cue-Bild anzeigen.
2. Genau zwei zum Cue gehörende sprachabhängige Labels anbieten.
3. Reihenfolge/Position der beiden Labels bei jeder Darbietung zufällig bestimmen.
4. Beide Optionen sind **sofort** auswählbar.
5. Keine künstliche 4-Sekunden-Sperre hinzufügen.
6. Ein Tap/Klick führt unmittelbar zum nächsten Trial.
7. Kein richtig/falsch-Feedback.
8. Gewähltes Label nicht als wissenschaftlichen Messwert speichern.

---

## 9. Rauchverlangensabfrage nach jedem Durchgang

Nach dem fünften Trial jedes Durchgangs erscheint genau eine Craving-Abfrage.

### 9.1 Wortlaut

Deutsch:

> Wie hoch ist in diesem Moment Ihr Rauchverlangen?

Englisch:

> How strong is your craving to smoke at this moment?

### 9.2 Interaktion

- Slider von `0` bis `100`,
- ausschließlich ganzzahlige Werte,
- Startwert `50`,
- aktueller Zahlenwert sichtbar,
- keine zusätzliche verbale Kategorisierung der Skala einführen,
- Wert wird erst nach aktiver Betätigung von `Absenden` / `Submit` übernommen,
- genau ein Craving-Wert pro Durchgang.

Testable unterstützt in Forms `responseType=slider`. Die konkrete Slider-Konfiguration ist vor Erzeugung der Datei gegen die dann aktuelle Testable-Dokumentation zu prüfen; insbesondere müssen Mindestwert, Höchstwert, Schrittweite, Startwert und sichtbare Wertanzeige dem App-Verhalten entsprechen.

---

## 10. Visuelle Umsetzung

### 10.1 Farbschema

Das aktuelle CueLens-Farbschema soll soweit Testable dies ohne methodische Nebenwirkungen erlaubt übernommen werden:

| Element | CueLens-Wert |
|---|---|
| Hintergrund | `#D7ECE9` |
| Primärfarbe / Buttons / Akzente | `#006269` |
| Standardtext | `#000000` |
| Text auf primären Buttons | `#FFFFFF` |

Testable erlaubt globale Display-Farben und teilweise trial-spezifische Gestaltung. Das Farbschema soll bevorzugt global gesetzt werden, damit nicht unnötig zusätzliche Trial-File-Spalten entstehen.

### 10.2 Stimulusdarstellung

Die produktive Cue-Darbietung soll das Referenzverhalten so eng wie möglich nachbilden:

- Nutzung im Hochformat,
- Cue-Bild füllt die sichtbare Fläche mit zentriertem Crop-Verhalten,
- kein Letterboxing um das Cue-Bild,
- Match-Bilder beziehungsweise Label-Schaltflächen als Overlay im unteren Bildschirmbereich,
- Match-Bilder vollständig sichtbar und ohne Verzerrung,
- keine zusätzlichen therapeutischen Hinweise,
- keine Wirksamkeitsversprechen,
- keine unnötigen Testable-Elemente, die Aufmerksamkeit oder Reizdarbietung verändern.

Testable weist darauf hin, dass experimentelle Stimulusdarstellung nicht generell adaptiv ist. Deshalb muss die Darstellung mindestens auf den vorgesehenen Smartphone- und Tablet-Größen praktisch getestet werden. Ein Desktop-Layout darf nicht einfach unverändert auf mobile Geräte übernommen werden.

### 10.3 Sprache

Sichtbare Texte müssen den deutschen und englischen App-Texten entsprechen. Eine technisch mögliche Sprachumschaltung darf die Position im Studienablauf, die Randomisierung und bereits erfasste Werte nicht zurücksetzen.

Falls Testable keine zuverlässige Laufzeitumschaltung erlaubt, sind zwei sprachspezifische, ansonsten identische Projekte/Trial Files der bevorzugte Fallback. Diese Abweichung betrifft die Oberfläche, nicht den Studienablauf.

---

## 11. Datenminimierung

### 11.1 Zu speichernde Studiendaten

Für die wissenschaftliche Auswertung werden aus dem Trial-Ablauf nur die Daten benötigt, die den 20 Craving-Angaben eine eindeutige Position innerhalb des Within-Subject-Ablaufs geben.

Minimaler fachlicher Datensatz:

- von Testable bereitgestellte pseudonyme Teilnahme-/Minds-Kennung, soweit für Within-Subject-Zuordnung erforderlich,
- `run_index` 1–20 oder eine gleichwertige bereits von Testable vorhandene Positionsinformation,
- `craving` 0–100.

Die Bedingung muss nicht zusätzlich gespeichert werden, wenn sie aus `run_index` eindeutig ableitbar ist:

- 1–10 = Cue-Matching,
- 11–20 = Cue-Labeling.

### 11.2 Nicht zusätzlich erheben

Die Trial Files sollen **keine zusätzlichen Teilnehmermerkmale** einführen, insbesondere nicht:

- E-Mail-Adresse,
- Prolific-ID,
- Name,
- freie Identifikationscodes,
- Plattformvariable,
- Betriebssystem als Studienvariable,
- Browser als Studienvariable,
- Gerätemodell,
- Geräte-ID,
- Standort,
- Audio,
- Kameradaten.

Technische oder organisatorische Einstellungen, die Testable selbst für Betrieb, Teilnahmeverwaltung oder Sicherheit benötigt, sind nicht in den Trial Files nachzubauen.

### 11.3 Keine unnötigen Custom Columns

Testable erlaubt frei erfundene zusätzliche Spalten und weist darauf hin, dass diese in Ergebnisdateien aufgenommen werden. Deshalb gilt:

- keine Debug-Spalten in produktiven Trial Files,
- keine redundanten Bedingungs- oder Stimulusmetadaten, sofern sie für Auswertung oder Validierung nicht benötigt werden,
- keine Speicherung der konkreten Links-/Rechtswahl,
- keine Speicherung der Matching- oder Labeling-Antwort,
- keine Reaktionszeit als Forschungsvariable, sofern sie nicht technisch unvermeidbar ist und vorab begründet wurde.

### 11.4 Testable-Optionen außerhalb der Trial Files

Im Bereich `Participants & Data > Record` sollen optionale Zusatzaufzeichnungen nur aktiviert werden, wenn sie für diese Studie tatsächlich erforderlich sind. Insbesondere besteht aus dem CueLens-Protokoll heraus kein Bedarf an Audioaufzeichnung, URL-Parametern, Betriebssystem-, Browser-, Screen-Size- oder Framerate-Daten als Forschungsvariablen.

Hosting-, Account-, Zugriffsschutz- und sonstige Testable-Plattformsicherheitsfragen werden separat in Testable konfiguriert und sind nicht Teil dieser Trial-File-Spezifikation.

---

## 12. Testable-spezifische Umsetzungsprinzipien

Bei der späteren Generierung der CSV-Dateien sollen nur aktuell dokumentierte Testable-Funktionen verwendet werden.

Geeignete Testable-Konzepte sind insbesondere:

- Trial File als CSV,
- `type` als erforderliche Spalte,
- Instructions über `title` und `content`,
- Stimuli über `stim`/`stimFormat` und passende Größen-/Positionsparameter,
- Timingparameter in Millisekunden,
- Randomisierung auf Trial- oder Blockebene,
- Lists/Wildcards für wiederkehrende Stimulusdaten,
- Forms mit `responseType=slider` für die Craving-Abfrage,
- `if`/`then` nur dann, wenn für eine nachweislich notwendige Ablaufsteuerung erforderlich.

**Keine undokumentierten Parameter erfinden.** Wenn eine benötigte Funktion in der aktuellen Testable-Dokumentation nicht eindeutig beschrieben ist, muss sie zunächst verifiziert werden.

---

## 13. Abbruch- und Wiederaufnahmeverhalten

Für eine 1:1-Nachbildung ist folgendes Referenzverhalten maßgeblich:

- Ein bereits bestätigter Durchgang bleibt bestätigt.
- Ein nicht bestätigter Durchgang zählt nicht.
- Wird ein Durchgang während seiner fünf Matching-/Labeling-Trials unterbrochen, darf er beim erneuten Start wieder beim ersten Trial dieses noch unbestätigten Durchgangs beginnen.
- Bei Cue-Matching bleibt die für die Person erzeugte globale 50er-Permutation dabei erhalten.
- Die konkrete Position der beiden Auswahloptionen darf beim erneuten Darbieten neu randomisiert werden.
- Ein neuer Durchgang darf erst nach erfolgreicher Bestätigung des vorherigen Craving-Werts und nach Ablauf der drei Stunden beginnen.

Die Testable-Lösung muss gezielt gegen Browser-Reload, Tab-Schließen, App-/Browser-Wechsel in den Hintergrund und erneutes Öffnen getestet werden.

---

## 14. Abnahmekriterien

Die Trial Files gelten erst dann als methodisch freigabefähig, wenn mindestens folgende Prüfungen bestanden sind:

### 14.1 Struktur

- [ ] Exakt 20 produktive Durchgänge.
- [ ] Durchgänge 1–10 sind ausschließlich Cue-Matching.
- [ ] Durchgänge 11–20 sind ausschließlich Cue-Labeling.
- [ ] Jeder Durchgang enthält exakt fünf Stimulus-Trials und danach genau eine Craving-Abfrage.

### 14.2 Matching

- [ ] Pro Person werden die 50 Matching-Items ohne Zurücklegen randomisiert.
- [ ] Jeder Matching-Cue erscheint über Durchgänge 1–10 genau einmal.
- [ ] Je Trial werden ausschließlich die beiden zum Cue gehörenden Match-Bilder angeboten.
- [ ] Position der beiden Match-Bilder wird pro Darbietung randomisiert.
- [ ] Auswahl bleibt exakt 4 Sekunden deaktiviert.
- [ ] Cue ist während der Sperrzeit sichtbar.

### 14.3 Labeling

- [ ] Cue-Reihenfolge entspricht `cue_000` bis `cue_049` in aufeinanderfolgenden Fünferblöcken.
- [ ] Je Cue werden exakt die zwei vorgesehenen Labels der gewählten Sprache angeboten.
- [ ] Labelposition wird pro Darbietung randomisiert.
- [ ] Auswahl ist sofort möglich.

### 14.4 Craving

- [ ] Skala 0–100.
- [ ] Ganzzahlige Schritte.
- [ ] Startwert 50.
- [ ] Aktueller Zahlenwert sichtbar.
- [ ] Aktives Absenden erforderlich.
- [ ] Genau 20 Craving-Werte bei vollständiger Teilnahme.

### 14.5 Zeitlicher Ablauf

- [ ] Nach bestätigtem Durchgang startet ein 3-Stunden-Mindestabstand.
- [ ] Reload oder Browser-Schließen verkürzt oder verlängert diesen Abstand nicht.
- [ ] Vor Ablauf ist der nächste Durchgang technisch nicht startbar.
- [ ] Es gibt keine zusätzliche technisch erzwungene Tageshöchstzahl.

### 14.6 Datenminimierung

- [ ] Matching-Antworten werden nicht gespeichert.
- [ ] Labeling-Antworten werden nicht gespeichert.
- [ ] Keine unnötigen Reaktionszeitdaten werden als Forschungsdaten erhoben.
- [ ] Keine E-Mail-Adresse, Prolific-ID oder sonstige direkte Identifikationsangabe wird im Trial File abgefragt.
- [ ] Keine unnötigen Custom Columns.
- [ ] Craving-Werte bleiben bei späterem Abbruch bereits bestätigter Durchgänge erhalten.

### 14.7 Darstellung

- [ ] Hintergrund möglichst `#D7ECE9`.
- [ ] Primärfarbe möglichst `#006269`.
- [ ] Cue-Darstellung auf Smartphone im Hochformat geprüft.
- [ ] Cue-Darstellung auf Tablet im Hochformat geprüft.
- [ ] Match-Bilder ohne Verzerrung vollständig sichtbar.
- [ ] Keine zusätzlichen therapeutischen oder wertenden Texte.

---

## 15. Empfohlene Reihenfolge der nächsten Arbeitsschritte

1. **Testable-Machbarkeit klären:** persistenter mehrtägiger Ablauf, 3-Stunden-Cooldown, Zwischenspeicherung und Nicht-Speicherung der Auswahlreaktionen.
2. **Stimulus-Mapping extrahieren:** 50 Matching-Tripel und 50 zweisprachige Labelzuordnungen aus der Referenz-App in Listenform überführen.
3. **Minimalen Proof of Concept bauen:** ein Matching-Durchgang mit fünf Trials + Craving sowie ein Labeling-Durchgang mit fünf Trials + Craving.
4. **Datenoutput prüfen:** Ergebnisdatei darauf kontrollieren, dass keine unerwünschten Antwort- oder Metadaten gespeichert werden.
5. **Resume-/Cooldown-Test durchführen:** Browser schließen, später erneut öffnen und Zeit-/Fortschrittsverhalten prüfen.
6. **Erst danach vollständige 20-Durchgänge-Datei erzeugen.**
7. **Automatisierte Plausibilitätsprüfung der CSV-Dateien:** Anzahl Trials, Cue-Vollständigkeit, Labelvollständigkeit, keine Cue-Duplikate im Matching-Pool, korrekte Blockgrenzen.
8. **Manuelle mobile Abnahme** auf mindestens einem Smartphone und einem Tablet.

Diese Reihenfolge folgt dem Pareto-Prinzip: Zuerst werden die wenigen Testable-Eigenschaften geprüft, die die grundsätzliche methodische Eignung der Plattform bestimmen. Erst danach lohnt sich die vollständige Generierung der 100 Stimulus-Trials und 20 Craving-Abfragen.

---

## 16. Quellen und Referenzen

### CueLens-Referenzimplementierung

- `stefan-bmio/master-thesis`, Branch `main`
- `cuelens/app/src/main/java/de/eachandevery/cuelens/MainActivity.kt`
- `cuelens/app/src/main/res/values/strings.xml`
- `cuelens/app/src/main/res/values-en/strings.xml`
- `cuelens/app/build.gradle.kts`
- `cuelens-ios/PLATFORM_INDEPENDENT_SPECIFICATION.md`

### Testable-Dokumentation, geprüft am 18.08.2026

- Trial file fundamentals: <https://help.testable.org/kb/guide/en/trial-file-fundamentals-hRC7xXh0Vv/Steps/364823>
- Timing parameters: <https://help.testable.org/kb/guide/en/timing-parameters-B3WUPamrgN/Steps/440021>
- Forms and surveys: <https://help.testable.org/kb/guide/en/forms-and-surveys-pG9tsdFnv3/Steps/456301>
- Randomisation: <https://help.testable.org/kb/guide/en/randomisation-PzzFfjXhdU/Steps/440280>
- Lists, wildcards and dynamically generated trials: <https://help.testable.org/kb/guide/en/working-with-lists-wildcards-and-dynamically-generated-trials-jGMHOJGrgz/Steps/1565293>
- Participants & Data: <https://help.testable.org/kb/guide/en/participants-data-1uHmxYxfNH/Steps/728727>
- General / Display options: <https://help.testable.org/kb/guide/en/general-6tXndMyG9s/Steps/728753>
- Testable Minds studies and sessions: <https://help.testable.org/kb/guide/en/launch-and-manage-your-testable-minds-study-QZuEJmjBna/Steps/470405>
- Results files: <https://help.testable.org/kb/guide/en/how-to-read-the-results-files-rWYtILpElu/Steps/1226408>

