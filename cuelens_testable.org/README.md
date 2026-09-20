# CueLens × Testable: minimaler Proof of Concept

## Zweck

Dieses Paket prüft **nur die technische Abbildbarkeit** der zwei interventionsrelevanten CueLens-Durchgangstypen in Testable:

1. ein Cue-Matching-Durchgang mit fünf Trials und anschließender Rauchverlangensabfrage;
2. ein Cue-Labeling-Durchgang mit fünf Trials und anschließender Rauchverlangensabfrage.

Es ist **kein produktionsfertiges Studienprojekt**. Die enthaltenen Bilder sind deutlich markierte Platzhalter. Vor einer Verwendung mit Teilnehmenden müssen die exakten CueLens-Referenzbilder eingesetzt und die offenen Testable-Eigenschaften verifiziert werden.

## Dateien

- `cuelens_poc_de.csv`: deutscher technischer PoC.
- `cuelens_poc_en.csv`: englischer technischer PoC.
- `matching_items_poc.csv`: fünf Matching-Items und Sollverhalten.
- `labeling_items_poc.csv`: die ersten fünf Cue-Label-Paare der Android-Referenzimplementierung.
- `asset_manifest.csv`: Herkunft und Austauschpfade der Reize.
- `assets/`: ausschließlich PoC-Platzhalter.
- `build_matching_composites.py`: erzeugt aus einem lokalen Checkout fünf reale Matching-Kompositbilder.
- `TEST_CHECKLIST.md`: Prüfprotokoll für Import und Laufzeitverhalten.

## Warum das Matching im PoC aus zwei Zeilen pro Item besteht

Die Android-App zeigt Cue und Auswahlbilder und sperrt die Auswahl **vier Sekunden**. Für den minimalen Testable-PoC wird bewusst kein nicht verifizierter proprietärer Parameter für eine verzögerte Antwortfreigabe angenommen. Deshalb wird jedes Matching-Item technisch in zwei unmittelbar aufeinanderfolgende Zeilen zerlegt:

1. dieselbe komplette Szene für `presTime=4000` ms ohne Antwortmöglichkeit;
2. dieselbe Szene erneut mit zwei Antwortschaltflächen.

Das prüft die Kernanforderung „vier Sekunden keine Antwort“ ohne eine undokumentierte Testable-Spalte zu erfinden. Falls Testable einen dokumentierten Response-Delay bzw. positionierte Response-Boxes unterstützt, soll die finale Fassung wieder **ein** Trial pro Matching-Reiz verwenden.

## Bewusste Abweichungen des PoC von der 1:1-Zielfassung

- **Keine echte Randomisierung der Antwortpositionen:** Die fünf PoC-Items wechseln nur deterministisch zwischen A/B und B/A. Im finalen Projekt muss die Position bei jeder Präsentation zufällig sein.
- **Kein 3-Stunden-Cooldown:** Matching und Labeling folgen direkt aufeinander. Persistente Mehrtagesteilnahme wird separat geprüft.
- **Matching-/Labeling-Antworten werden im PoC voraussichtlich von Testable protokolliert.** Das ist gerade Gegenstand des Tests. In der finalen Fassung sollen diese Antworten nicht Teil des wissenschaftlichen Datensatzes sein.
- **Slider-Konfiguration:** `type=form` und `responseType=slider` sind gesetzt. Vor Freigabe muss in Testable verifiziert bzw. eingestellt werden: Wertebereich 0–100, ganzzahlige Schritte, Startwert 50.
- **Die Einleitungs- und Übergangsseiten sind PoC-Markierungen** und gehören nicht in die spätere 1:1-Studienfassung.

## Datenminimierung im PoC

Die Trial Files enthalten **keine** eigenen Felder für E-Mail, Name, Prolific-ID, Plattform, Browser, Betriebssystem, Gerätemodell, Standort oder sonstige Gerätekennungen. Es werden auch keine zusätzlichen Debug- oder Provenienzspalten in das Trial File aufgenommen, weil beliebige Trial-File-Spalten in Ergebnisexporten erscheinen können.

Beim Testable-Projekt sollten optionale technische Record-Felder nur aktiviert werden, wenn sie für die Machbarkeitsprüfung zwingend benötigt werden. Datenschutz- und Sicherheitseinstellungen, die eindeutig bei Testable als Plattform liegen, werden nicht durch eigene CueLens-Mechanismen nachgebaut.

## Farbschema

Der PoC verwendet die CueLens-Farben:

- Hintergrund: `#D7ECE9`
- Primärfarbe: `#006269`

Für die tatsächliche Testable-Oberfläche sollten dieselben Werte in den General-/Appearance-Einstellungen gesetzt werden, sofern verfügbar.

## Austausch der Platzhalter

1. Repository `stefan-bmio/master-thesis` lokal auschecken.
2. Die fünf `cue_000.png` bis `cue_004.png` aus `cuelens/app/src/main/res/drawable/` nach `assets/` kopieren.
3. `build_matching_composites.py` ausführen, damit `matching_scene_000.png` bis `matching_scene_004.png` aus den originalen Cue-/Match-Bildern entstehen.
4. In Testable alle Dateien aus `assets/` hochladen.
5. Trial File importieren.
6. `TEST_CHECKLIST.md` vollständig durchführen.

## Entscheidung nach dem PoC

Der Ausbau auf 20 Durchgänge sollte erst erfolgen, wenn mindestens diese drei Punkte geklärt sind:

1. Kann der Drei-Stunden-Abstand über Browser-Schließen und erneutes Öffnen hinweg zuverlässig erzwungen werden?
2. Können die 100 Matching-/Labeling-Auswahlen aus dem wissenschaftlichen Export ausgeschlossen bzw. nachweisbar ignoriert werden, ohne zusätzliche Identifikationsdaten zu benötigen?
3. Bleiben bereits abgeschlossene Craving-Durchgänge bei einer mehrtägigen Teilnahme erhalten, auch wenn eine Person später nicht bis zum finalen Debrief gelangt?
