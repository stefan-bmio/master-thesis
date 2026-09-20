# CueLens × Testable: Resume-/Cooldown-PoC

## Zweck

Dieser kleine Proof of Concept prüft ausschließlich, ob sich ein begonnener Testable-Ablauf nach Unterbrechungen auf einem Android-Smartphone fortsetzen lässt und wie sich eine zeitgesteuerte Pause dabei verhält.

Geprüft werden insbesondere:

1. Erhalt eines vor der Pause eingegebenen Selbstberichts;
2. Verhalten eines dreiminütigen Countdowns bei geöffnetem Browser;
3. Verhalten beim Schließen und erneuten Öffnen des Browsers;
4. Verhalten bei Reload, Zurück-Navigation, Bildschirm-Sperre und parallelem Tab;
5. gemeinsamer Ergebnisexport beider Selbstberichte nach Erreichen des Debriefs;
6. Fortsetzung nach einer Unterbrechung über Nacht.

Der PoC ist **keine produktionsfertige Studienumsetzung**. Die Pause wurde von drei Stunden auf drei Minuten verkürzt. Die Ergebnisse dürfen deshalb nur zur technischen Machbarkeitsbewertung verwendet werden.

## Dateien und benötigte Assets

Trial File:

- `cuelens_resume_cooldown_poc_de.csv`

Bereits im Repository vorhandene PoC-Assets, die in Testable hochgeladen werden müssen:

- `../assets/cue_000.png`
- `../assets/cue_001.png`
- `../assets/matching_scene_000.png`

Alle drei Dateien sind technische Platzhalter. Es werden keine produktiven Rauchreize benötigt.

## Aufbau des Ablaufs

Der Ablauf besteht aus:

1. technischer Einleitung;
2. einem einfachen `test`-Trial als Marker für Durchgang 1;
3. einem Slider-Selbstbericht; für den Test soll der Wert **23** eingestellt werden;
4. einer Ankündigung der Pause;
5. einem `learn`-Trial mit `presTime=180000` und sichtbarem Drei-Minuten-Timer;
6. einer Seite, die das Erreichen von Durchgang 2 eindeutig kennzeichnet;
7. einem einfachen `test`-Trial als Marker für Durchgang 2;
8. einem zweiten Slider-Selbstbericht; für den Test soll der Wert **77** eingestellt werden;
9. dem regulären Testable-Debrief.

Die Werte 23 und 77 sind keine Forschungsdaten. Sie dienen ausschließlich dazu, im Export eindeutig festzustellen, ob beide Eingaben erhalten geblieben sind.

## Testable-Projekteinstellungen

Für diese technische Prüfung gelten folgende Einstellungen:

| Einstellung | Testwert | Begründung |
|---|---:|---|
| Sprache | Deutsch | entspricht dem Trial File |
| Unique participation | aus | Testable empfiehlt dies für Tests und Laborbetrieb |
| Participation time limit | 2880 Minuten | ermöglicht eine Unterbrechung bis zu 48 Stunden |
| Erlaubte Geräte | Android-Smartphone und verwendeter Browser | Zielumgebung des Tests |
| Bildschirmhintergrund | `#D7ECE9` | CueLens-Farbschema |
| Primär-/Akzentfarbe | `#006269` | CueLens-Farbschema |
| Zusätzliche Record-Felder | aus | Betriebssystem, Browser, Bildschirmgröße und ähnliche Felder werden für den PoC manuell im Testprotokoll notiert und nicht als Teilnahmevariablen erhoben |

Für die Resume-Prüfung soll der reguläre Experiment-Link verwendet werden, nicht ausschließlich die Trial-Vorschau. Dies ist eine methodische Testentscheidung: Geprüft wird der Zustand einer begonnenen Participation.

Relevante Testable-Dokumentation:

- Timer: https://help.testable.org/kb/guide/en/timers-and-stopwatches-f5hFGCE0Dp/Steps/1181705
- Participation time limit und Unique participation: https://help.testable.org/kb/guide/en/participants-data-1uHmxYxfNH/Steps/728727 und https://help.testable.org/kb/guide/en/general-6tXndMyG9s/Steps/728753
- Ergebnisexport erst nach Debrief; keine gespeicherten Partial Results: https://help.testable.org/kb/guide/en/how-to-read-the-results-files-rWYtILpElu/Steps/1226408
- Stimulusgröße: https://help.testable.org/kb/guide/en/define-and-position-stimuli-ygL6ymz3Cn/Steps/1059962

## Vorprüfung nach dem Import

Vor den Unterbrechungstests einmal in der Vorschau kontrollieren:

- das Trial File wird ohne unbekannten `type` akzeptiert;
- beide Marker-Trials zeigen Bild und Schaltflächen ohne Scrollen;
- `stimSize=60%` wird auf dem Zielgerät angewendet;
- der erste Slider erlaubt die Eingabe 23;
- der Pause-Trial zeigt einen Countdown von drei Minuten;
- der Pause-Trial wechselt nach ungefähr 180 Sekunden automatisch zu „Durchgang 2 ist erreichbar“;
- der zweite Slider erlaubt die Eingabe 77;
- nach dem zweiten Slider wird der reguläre Debrief erreicht.

Falls 23 beziehungsweise 77 im Slider nicht exakt einstellbar sind, müssen die Slider-Einstellungen in Testable zunächst auf 0–100 mit ganzzahligen Schritten gesetzt werden. Die Resume-Prüfung soll erst danach beginnen.

## Testschritte 1 bis 6

### 1. Ununterbrochener Referenzlauf

1. Experiment über den regulären Link starten.
2. Durchgang 1 durchführen.
3. Beim ersten Slider den Wert 23 einstellen und absenden.
4. Die Pause vollständig bei geöffnetem Browser ablaufen lassen.
5. Durchgang 2 durchführen.
6. Beim zweiten Slider den Wert 77 einstellen und absenden.
7. Debrief erreichen.
8. Ergebnisdatei herunterladen und prüfen, ob beide Werte enthalten sind.

Dieser Lauf dient als technische Referenz. Scheitert er, sind Unterbrechungstests noch nicht aussagekräftig.

### 2. Drei-Minuten-Cooldown prüfen

1. Neue Participation starten.
2. Ersten Selbstbericht mit 23 abschließen.
3. Startzeit des sichtbaren Countdowns sekundengenau notieren.
4. Browser geöffnet lassen.
5. Zeitpunkt notieren, zu dem „Durchgang 2 ist erreichbar“ erscheint.

Akzeptanzkriterium: Der zweite Durchgang darf nicht wesentlich vor 180 Sekunden erreichbar sein und soll nach ungefähr 180 Sekunden automatisch erscheinen.

### 3. Browser während der Pause schließen und erneut öffnen

1. Neue Participation starten und den ersten Wert 23 absenden.
2. Warten, bis der Countdown sichtbar läuft.
3. Nach ungefähr 30 Sekunden den Browser vollständig schließen.
4. Nach weiteren ungefähr 60 Sekunden denselben Experiment-Link wieder öffnen.
5. Position im Ablauf und angezeigte Restzeit notieren.
6. Ablauf bis zum Debrief abschließen und im zweiten Slider 77 eingeben.
7. Ergebnisdatei auf beide Werte prüfen.

Zusätzlicher Lauf: Browser während der Pause schließen und erst **nach mehr als drei Minuten seit Pausenbeginn** wieder öffnen.

Besonders wichtig ist die Unterscheidung:

- Der Countdown läuft anhand der verstrichenen Realzeit weiter.
- Der Countdown startet nach Wiederöffnung vollständig neu.
- Der zweite Durchgang wird vorzeitig zugänglich.
- Die Participation beginnt wieder am Anfang.

### 4. Weitere Unterbrechungen getrennt prüfen

Die folgenden Varianten jeweils in einer eigenen frischen Participation durchführen:

- Seite während des Countdowns neu laden;
- Android-Bildschirm während des Countdowns für mindestens vier Minuten sperren;
- Browser nur in den Hintergrund legen und nach mindestens vier Minuten zurückkehren;
- Browser-Zurück verwenden und anschließend denselben Experiment-Link erneut öffnen;
- denselben Experiment-Link während der laufenden Pause in einem zweiten Tab öffnen.

Für jede Variante dokumentieren:

- erreichte Seite nach Rückkehr;
- angezeigte beziehungsweise neu gestartete Restzeit;
- Möglichkeit, den zweiten Durchgang vor 180 Sekunden zu erreichen;
- Erhalt des ersten Selbstberichts im abschließenden Export.

### 5. Gemeinsamen Export beider Durchgänge prüfen

Vor Erreichen des Debriefs ist nach der aktuellen Testable-Dokumentation keine exportierte Ergebnisdatei zu erwarten. Nach Abschluss bis zum Debrief muss eine Ergebnisdatei verfügbar sein.

In der Ergebnisdatei prüfen:

- erster Sliderwert = 23;
- zweiter Sliderwert = 77;
- beide Werte gehören zur selben Participation;
- es entstand durch Wiederöffnung kein zweiter unabhängiger Datensatz;
- die beiden Marker-Trials und Pause-Zeile sind in einer nachvollziehbaren Reihenfolge enthalten.

### 6. Übernacht-Test

1. Neue Participation am Abend starten.
2. Durchgang 1 durchführen und 23 absenden.
3. Während des laufenden Countdowns den Browser vollständig schließen.
4. Erst am folgenden Tag denselben Link auf demselben Gerät und im selben Browser öffnen.
5. Position im Ablauf und gegebenenfalls angezeigte Restzeit dokumentieren.
6. Durchgang 2 mit Wert 77 abschließen und Debrief erreichen.
7. Export auf beide Werte und dieselbe Participation prüfen.

Voraussetzung: Die `Participation time limit` muss den gesamten Zeitraum abdecken. Für diesen PoC sind 2880 Minuten vorgesehen.

## Bewertung

| Ergebnis | Einstufung | Bedeutung für CueLens |
|---|---|---|
| Realzeit-Cooldown läuft über Browser-Schließen weiter, Durchgang 1 bleibt erhalten, gemeinsamer Export enthält 23 und 77 | Grün | zentrale Voraussetzung für einen mehrtägigen 1:1-Ablauf grundsätzlich erfüllt |
| Daten bleiben erhalten, aber der Drei-Minuten-Timer startet nach Rückkehr neu | Gelb | Resume funktioniert, wall-clock-basierter Cooldown entspricht jedoch nicht der App und belastet Teilnehmende zusätzlich |
| Zweiter Durchgang ist vor Ablauf der Realzeit erreichbar | Rot | notwendiger Mindestabstand kann umgangen werden |
| Ablauf beginnt neu oder Wert 23 fehlt im abschließenden Export | Rot | mehrtägiger Studienzustand ist nicht zuverlässig |
| Wiederöffnung erzeugt eine zweite Participation statt Fortsetzung | Rot | 20 Durchgänge derselben Person können nicht verlässlich zusammengeführt werden |
| Übernacht-Fortsetzung scheitert trotz ausreichend langer Participation time limit | Rot | geplanter mehrtägiger CueLens-Ablauf ist mit diesem Ansatz nicht geeignet |

## Datenminimierung

Der PoC erhebt keine Namen, E-Mail-Adressen, Prolific-IDs, Gerätekennungen oder Gesundheitsangaben. Die Zahlen 23 und 77 sind ausschließlich technische Marker. Gerät, Android-Version, Browser und Testzeitpunkte werden manuell in `TEST_RESULTS.md` notiert und nicht als zusätzliche Testable-Felder in die Ergebnisdatei aufgenommen.
