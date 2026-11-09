# Testable-Ergebnisse mit R

## Datenstand und Start

Quelldaten: `main` bei `b0ac28be3ab0c29d6643f073cb555f087769a8f2`, Trial-File und sämtliche 68 CSV-Dateien in `cuelens_testable.org/996939_20260916_153409_all/`.

Aus dem Repository-Hauptverzeichnis:

```bash
Rscript analysis/testable/analyse_testable.R
```

Alternativ kann der Repository-Pfad als einziges Argument übergeben werden. Ausgeführt mit R 4.3.3 unter Ubuntu 24.04. Es werden nur mit R gelieferte Pakete benötigt. Für Vektorabbildungen ist Cairo-Unterstützung erforderlich; die verwendete Schrift ist DejaVu Sans. Die Konsolenausgabe und `output/sessionInfo.txt` dokumentieren das Ergebnis bzw. die R-Umgebung. Die Rohdateien werden ausschließlich gelesen. `output/input_checksums.csv` dokumentiert ihre MD5-Prüfsummen zur Reproduzierbarkeit.

## Auswertungsregeln

Die Hauptanalyse verwendet 66 eindeutige, vollständige Teilnahmen mit passender Exportversion, gültigen Skalenwerten und erfülltem Trial-Screening. Eine ältere Sitzung ohne Teilnehmerkennung und eine identifizierte Sitzung mit zusätzlicher Zeile `16_2` und fehlender Zeile `232` werden gesondert berücksichtigt. Die verfügbare-Paare-Analyse verwendet bei letzterer die neun vollständigen Blockpaare. Keine Imputation, kein Entfernen von Fällen wegen ihrer Effektgröße oder Effektrichtung. Siehe `PLAN.md` für die vor der Inferenz dokumentierten Entscheidungen.

Primärer Kontrast ist der mittlere personenbezogene Unterschied Labeling minus Matching. Der einseitige Ein-Stichproben-t-Test (`alternative="less"`) der Differenzen entspricht dem gepaarten t-Test der Bedingungsmittelwerte. Wilcoxon, Personen-Bootstrap und sämtliche geplanten Sensitivitäten werden ebenfalls ausgegeben. Für den Wilcoxon-Test werden die aus ganzzahligen Rohwerten gebildeten Personendifferenzen auf zehn Dezimalstellen gerundet, um künstlich aufgespaltene Rangbindungen durch Gleitkommaarithmetik zu vermeiden.

## Ergebnisse und LaTeX

- `output/contrasts.csv`: Hauptanalyse und ergänzende t-Kontraste.
- `output/robustness.csv`: Wilcoxon und Bootstrap.
- `output/descriptives.csv`, `block_summary.csv`, `data_flow.csv`, `operating_systems.csv`: aggregierte Beschreibungen und Qualitätsprüfung.
- `output/trial_mapping.csv`: überprüfbare Zuordnung der 20 Selbstberichte zu Block und Bedingung.
- `output/numbers.tex` und `sensitivity_table.tex`: direkt vom R-Skript erzeugte Zahlen und Tabelle.
- `output/testable_results.pdf` und `testable_timecourse.pdf`: vom R-Skript erzeugte Vektorabbildungen.
- `latex/kapitel7/ch7.tex`: gemeinsames Auswertungskapitel mit App- und Testable-Ergebnissen sowie vollständigem R-Listing.

Eigenständige Abschnittsvorschau aus `latex/` kompilieren:

```bash
pdflatex -interaction=nonstopmode -halt-on-error testable_auswertung_preview.tex
pdflatex -interaction=nonstopmode -halt-on-error testable_auswertung_preview.tex
```

Die Kapitelvorschau enthält einen eigenen Literaturverweis auf Tabibnia et al. und benötigt keinen Biber-Lauf. Die vollständige Arbeit verwendet weiterhin ihre bestehende Präambel und ihren bisherigen Build-Prozess.

## Interpretation

Labeling minus Matching: -0,6121 Punkte; 95%-KI [-1,9012; 0,6769]; t(65)=-0,9484; p=0,17323 (einseitig); d_z=-0,1167. Kein belastbarer Nachweis geringeren Rauchverlangens nach Labeling. Das feste Matching-Labeling-Schema, unterschiedliche Präsentationsabläufe, fehlende Bildantworten, teilweise verkürzte Berichtsabstände und fehlende individuelle Prä-Interventionsmessungen begrenzen die kausale Interpretation. Ein nicht signifikanter Test belegt keine Gleichwertigkeit. App- und Testable-Daten werden nicht zusammengelegt.


## Änderung der Testseite (2026-11-09)

Die gerichteten t-Tests ersetzen die bisher zweiseitigen Tests. Grundlage sind die Reduktionshypothese und die einseitige Powerplanung des Exposés vom 10. Mai 2026. Der Wechsel erfolgt nach Kenntnis der Testable-Ergebnisse und wird nicht als präregistrierte Testable-Analyse bezeichnet. Zweiseitige 95%-Konfidenzintervalle bleiben als Schätzintervalle erhalten; die letzte-minus-erste Messung wird ohne p-Wert rein deskriptiv berichtet. Wilcoxon und Bootstrap sind unveränderte ergänzende Robustheitsanalysen.

Für diese Änderung wurde R nicht erneut ausgeführt (R ist in der Bearbeitungsumgebung nicht installiert). Die neuen t-p-Werte wurden aus den gespeicherten ungerundeten t-Werten und Freiheitsgraden mittels SciPy berechnet und unabhängig anhand der Rohdaten kontrolliert. `output/sessionInfo.txt` dokumentiert den ursprünglichen R-Lauf, nicht diese Aktualisierung. Das angepasste R-Skript erzeugt dieselben gerichteten t-p-Werte; die Konfidenzintervalle werden dort explizit über t-Quantile berechnet. Bereits vorhandene kompilierte PDFs entsprechen dem früheren Stand und müssen vor Verwendung neu gebaut werden.
