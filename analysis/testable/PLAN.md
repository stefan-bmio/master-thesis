# Testable-Auswertung: Arbeits- und Entscheidungsprotokoll

## 2026-09-21: Festlegung nach Strukturprüfung, vor inferenzstatistischer Auswertung

- Quelle: `main`, Commit `b0ac28be3ab0c29d6643f073cb555f087769a8f2`.
- 68 CSV-Dateien; 67 mit Teilnehmerkennung und Trial-Version 2026-09-15_17:52:16; eine ältere Datei ohne Teilnehmerkennung.
- Eine identifizierte Teilnahme enthält `16_2` zusätzlich zu `16`, aber keinen Bericht der Zeile `232`. Die Zuordnung erfolgt über Trial-Zeilen, niemals durch alternierende Nummerierung exportierter Antworten.
- Hauptanalyse: eindeutige Kennungen, aktuelle Exportversion, 20 eindeutige vorgesehene Selbstberichte, Werte 0 bis 100, Alter mindestens 30, mindestens 10 Zigaretten/Tag. Keine ergebnisabhängige Ausreißerentfernung und keine Imputation.
- Primärer beschreibender Kontrast: je Person Mittelwert Labeling minus Matching, anschließend Mittelwert der Personendifferenzen. Zweiseitiger gepaarter t-Test, 95%-Konfidenzintervall, standardisierte Differenz d_z. Diese nachträgliche Auswertung ist explorativ, nicht präregistriert.
- Robustheit: Wilcoxon-Vorzeichenrangtest, Personen-Bootstrap, zusätzlich die ältere nicht identifizierte Sitzung, verfügbare vollständige Blockpaare der unvollständigen Teilnahme, App-Altersgrenze 65 und zeitliche Plausibilität. Alle Varianten berichten, keine Auswahl nach p-Wert.
- Zeittrend: personenspezifische lineare Regression auf Bedingung und Blocknummer bzw. tatsächlich verstrichene Minuten; Mittelwert und t-Intervall der Bedingungskoeffizienten. Kein Ersatz für randomisierte oder gegenbalancierte Reihenfolge.
- Trial-Prüfung: feste Matching-Labeling-Abfolge, fünf Bilder je Block, zusätzliche Matching-Präsentationen, 19 Fünf-Minuten-Pausen, 100 nicht exportierte practice-Aufgaben, eine ebenfalls als practice angelegte Pausenfrage.
- Hauptanalyse und Sensitivitäten werden separat von App-Daten beschrieben. Dateizahl ist keine Rekrutierungs- oder Abschlussquote.
- Änderungen: neue R-Datei, erzeugte aggregierte Ergebnistabellen/Abbildungen, neuer LaTeX-Abschnitt in Kapitel 7 und vollständiges R-Listing. Rohdaten bleiben unverändert.

## 2026-09-21: Ergebnis- und Integrationsstand

- R 4.3.3 tatsächlich ausgeführt; 66 Personen, 1320 gültige Hauptanalysewerte.
- Hauptkontrast -0,6121212; 95%-KI [-1,9011565; 0,6769141]; t(65)=-0,9483763; p=0,3464507.
- Unabhängige Kontrollrechnung bestätigt n, Mittelwert, t-Test und Konfidenzintervall; Wilcoxon nach identischer Behandlung numerischer Rangbindungen ebenfalls bestätigt (V=977,5; p=0,6783814).
- 49 Berichtsabstände unter 300 Sekunden bei fünf vollständigen Teilnahmen; Zeitstempel am Dateiende entsprechen in allen 68 Dateien exakt duration_s.
- Neue Integration in Kapitel 7 ersetzt dessen sieben leere Platzhalterseiten durch den Abschnitt; main.tex bleibt unverändert.
- Alle ursprünglichen Rohdaten bleiben unverändert. Eigenständige LaTeX-Vorschau mit acht Seiten kompiliert. Die vollständige Masterarbeit wurde in diesem Schritt nicht neu gebaut.
- Bereits vorhandenes, nicht verändertes Build-Risiko: latex/revision/kapitel1_update.tex endet mit einem alleinstehenden end{neu} ohne zugehöriges begin{neu}. Vor einem vollständigen Neubau der Arbeit gesondert prüfen.

## 2026-09-21: Veröffentlichung blockiert

- Lokaler Commit 338dba8 auf analysis/testable-r-results erstellt.
- Push durch automatische Freigabeprüfung abgewiesen: öffentliche Veröffentlichung abgeleiteter gesundheitsbezogener Studienergebnisse ohne ausdrückliche Offenlegungsfreigabe. Kein alternativer Veröffentlichungsweg versucht.
- Geprüfte PDF-Vorschau und Änderungspaket werden stattdessen als private Downloads bereitgestellt. Freigabe zur öffentlichen Veröffentlichung ist noch offen.

## 2026-09-21: Veröffentlichung freigegeben

- Der Nutzer hat die Veröffentlichung des vorbereiteten Änderungspakets ausdrücklich freigegeben und `pdf-update` als separaten Veröffentlichungsbranch festgelegt.
- Der Remote-Branch `pdf-update` steht vor der Veröffentlichung auf dem Ausgangscommit b0ac28be3ab0c29d6643f073cb555f087769a8f2. Die vorbereiteten Änderungen bauen unmittelbar darauf auf.
- Veröffentlichung erfolgt auf `pdf-update`; keine Zusammenführung mit `main`.
