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

Primärer Kontrast ist der mittlere personenbezogene Unterschied Labeling minus Matching. Der zweiseitige Ein-Stichproben-t-Test der Differenzen entspricht dem gepaarten t-Test der Bedingungsmittelwerte. Wilcoxon, Personen-Bootstrap und sämtliche geplanten Sensitivitäten werden ebenfalls ausgegeben. Für den Wilcoxon-Test werden die aus ganzzahligen Rohwerten gebildeten Personendifferenzen auf zehn Dezimalstellen gerundet, um künstlich aufgespaltene Rangbindungen durch Gleitkommaarithmetik zu vermeiden.

## Ergebnisse und LaTeX

- `output/contrasts.csv`: Hauptanalyse und ergänzende t-Kontraste.
- `output/robustness.csv`: Wilcoxon und Bootstrap.
- `output/descriptives.csv`, `block_summary.csv`, `data_flow.csv`, `operating_systems.csv`: aggregierte Beschreibungen und Qualitätsprüfung.
- `output/trial_mapping.csv`: überprüfbare Zuordnung der 20 Selbstberichte zu Block und Bedingung.
- `output/numbers.tex` und `sensitivity_table.tex`: direkt vom R-Skript erzeugte Zahlen und Tabelle.
- `output/testable_results.pdf` und `testable_timecourse.pdf`: vom R-Skript erzeugte Vektorabbildungen.
- `latex/revision/kapitel7_testable_auswertung.tex`: wissenschaftlicher Abschnitt mit vollständigem R-Listing; über `latex/kapitel7/ch7.tex` in die Arbeit eingebunden.

Eigenständige Abschnittsvorschau aus `latex/` kompilieren:

```bash
pdflatex -interaction=nonstopmode -halt-on-error testable_auswertung_preview.tex
pdflatex -interaction=nonstopmode -halt-on-error testable_auswertung_preview.tex
```

Der Abschnitt übernimmt das bestehende Literaturverzeichnis nicht und benötigt für seine Vorschau keinen Biber-Lauf. Quellen werden dort in Fußnoten genannt. Die vollständige Arbeit verwendet weiterhin ihre bestehende Präambel und ihren bisherigen Build-Prozess.

## Interpretation

Labeling minus Matching: -0,6121 Punkte; 95%-KI [-1,9012; 0,6769]; t(65)=-0,9484; p=0,34645; d_z=-0,1167. Kein belastbarer Nachweis eines Bedingungsunterschieds. Das feste Matching-Labeling-Schema, unterschiedliche Präsentationsabläufe, fehlende Bildantworten, teilweise verkürzte Berichtsabstände und fehlende individuelle Prä-Interventionsmessungen begrenzen die kausale Interpretation. Ein nicht signifikanter Test belegt keine Gleichwertigkeit. App- und Testable-Daten werden nicht zusammengelegt.
