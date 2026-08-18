# Testprotokoll – minimaler CueLens-Testable-PoC

> Dieses Protokoll ist eine technische Machbarkeitsprüfung. Platzhalterbilder dürfen nicht mit echten Teilnehmenden eingesetzt werden.

## A. Import und Darstellung

- [ ] `cuelens_poc_de.csv` lässt sich ohne Schemafehler importieren.
- [ ] `cuelens_poc_en.csv` lässt sich ohne Schemafehler importieren.
- [ ] Alle fünf `matching_scene_*.png` werden gefunden und dargestellt.
- [ ] Alle fünf `cue_*.png` werden gefunden und dargestellt.
- [ ] Hintergrundfarbe ist `#D7ECE9`.
- [ ] Primärfarbe/Buttons sind soweit Testable dies erlaubt `#006269`.
- [ ] Smartphone-Hochformat wurde getestet.
- [ ] Tablet-Hochformat wurde getestet.
- [ ] Keine zusätzliche Progress-Bar oder nicht benötigte Navigation ist sichtbar.

## B. Cue-Matching

- [ ] Vor jeder Auswahl vergehen mindestens 4.000 ms.
- [ ] Während dieser vier Sekunden ist keine Antwort möglich.
- [ ] Beim Wechsel von der Warte- zur Antwortzeile entsteht kein auffälliger visueller Sprung.
- [ ] Beide Auswahlbilder bleiben vollständig sichtbar.
- [ ] Nach einer Auswahl beginnt unmittelbar das nächste Matching-Item.
- [ ] Alle fünf Matching-Items werden genau einmal gezeigt.
- [ ] Prüfen: Welche Antwort- und Reaktionszeitfelder erzeugt Testable im Ergebnisexport?
- [ ] Prüfen: Lassen sich diese Felder in der finalen Fassung vermeiden oder aus dem wissenschaftlichen Export sicher ausschließen?

## C. Rauchverlangen nach Matching

- [ ] Exakter deutscher/englischer Fragetext wird angezeigt.
- [ ] Slider reicht von 0 bis 100.
- [ ] Slider startet bei 50.
- [ ] Slider arbeitet in ganzzahligen Schritten.
- [ ] Wert wird erst nach aktiver Bestätigung übernommen, falls Testable dies unterstützt.
- [ ] Der exportierte Wert ist eindeutig als erster Craving-Selbstbericht erkennbar.

## D. Cue-Labeling

- [ ] Fünf Cue-Bilder werden gezeigt.
- [ ] Pro Cue werden genau zwei Labels angeboten.
- [ ] Auswahl ist ohne künstliche Wartezeit möglich.
- [ ] Labels entsprechen `labeling_items_poc.csv`.
- [ ] Test mit beiden Sprachen durchgeführt.
- [ ] Prüfen: Welche Antwort- und Reaktionszeitfelder erzeugt Testable im Ergebnisexport?
- [ ] Prüfen: Lassen sich diese Felder in der finalen Fassung vermeiden oder aus dem wissenschaftlichen Export sicher ausschließen?

## E. Rauchverlangen nach Labeling und Abschluss

- [ ] Zweite Craving-Abfrage entspricht der ersten Skala.
- [ ] Testable-Debrief wird erreicht.
- [ ] Vollständiger Ergebnisexport wird erzeugt.
- [ ] Export enthält keine unnötigen eigenen Identifikationsfelder.

## F. Datenminimierung

- [ ] Keine E-Mail-Adresse erhoben.
- [ ] Kein Name erhoben.
- [ ] Keine Prolific-ID zusätzlich erhoben.
- [ ] Keine eigene Plattform-/OS-/Browser-/Gerätemodellvariable erhoben.
- [ ] Optionale Testable-Record-Felder wurden auf das für den PoC erforderliche Minimum beschränkt.
- [ ] Provenienz- und Debugdaten stehen nur in den lokalen Begleitdateien, nicht als Trial-File-Spalten.

## G. Go/No-Go für den Vollausbau

- [ ] Mehrtägige Wiederaufnahme mit persistentem 3-Stunden-Cooldown ist technisch geklärt.
- [ ] Verhalten bei Browser-Schließen während eines Durchgangs ist geklärt.
- [ ] Verhalten bei Abbruch nach bereits abgeschlossenen Durchgängen ist geklärt.
- [ ] Wissenschaftlich benötigte Daten können ohne unnötige Trialantworten exportiert werden.
- [ ] Erst danach werden alle 20 Durchgänge und 100 Reiz-Trials erzeugt.
