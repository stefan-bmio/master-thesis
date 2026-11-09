# Auswertung der mehrtägigen App-Studie

## Ausführung

Python 3 und SciPy werden benötigt:

```sh
python analysis/app/analyse_app.py /pfad/zu/self_reports.csv
```

Der private Export ist nicht Bestandteil des Repositorys. Die Datei hat keine Kopfzeile; die Spalten sind Teilnehmerkennung, Bedingung (`CUE_MATCHING` oder `CUE_LABELING`), Craving (0–100) und Testflag (0/1).

## Festgelegte Regeln

1. Zunächst Zeilen mit Testflag 1 ausschließen.
2. Danach ausschließlich Kennungen mit genau zehn Berichten je Bedingung berücksichtigen.
3. Pro Person die Bedingungsmittelwerte bilden; alle Personen gleich gewichten.
4. Differenz Labeling minus Matching, einseitiger gepaarter t-Test auf negative mittlere Differenz bei alpha = 0,05.
5. Zweiseitiges 95%-Konfidenzintervall als Schätzintervall und d_z berichten. Zusätzlich wird die obere einseitige 95%-Grenze ausgegeben.

Die Testseite folgt der gerichteten Forschungsfrage und der einseitigen Powerplanung des Exposés vom 10. Mai 2026, Abschnitt 6.3. Die Auswahlregeln wurden vom Autor am 9. November 2026 vor der hier berichteten Effektberechnung festgelegt. Dies ist keine Behauptung einer Präregistrierung. Der Testable-Test wurde erst nach Kenntnis seines Ergebnisses umgestellt; siehe dessen Analyseprotokoll.

## Aktueller Datenfluss und Ergebnis

494 Exportzeilen; 2 Testzeilen ausgeschlossen; 492 Berichte von 33 Kennungen; 24 vollständige Teilnahmen mit 480 Berichten. Die übrigen 9 Kennungen umfassen 12 Matching-Berichte ohne Labeling.

Matching 50,725; Labeling 50,425; Differenz -0,300; t(23)=-0,143144; p=0,443712 (einseitig); zweiseitiges 95%-KI [-4,635481; 4,035481]; d_z=-0,029219.

Alle Ausgaben sind aggregiert. `provenance.json` enthält die SHA-256-Prüfsumme des unveränderten Exports sowie die tatsächlich verwendeten Softwareversionen. Keine IDs und keine Rohzeilen werden ausgegeben. Identische Wertzeilen werden nicht automatisch dedupliziert, da wiederholt gleiche Bewertungen zulässig sind und der Export keine eindeutige Situationsnummer enthält. Alter, Zeitstempel und Situationsnummern fehlen; Altersgruppen, Zeitabstände und mögliche Mehrfachübertragungen sind daher nicht unabhängig prüfbar. Es erfolgt keine Imputation und keine ergebnisabhängige Fallauswahl.
