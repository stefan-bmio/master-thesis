# CueLens iOS – Implementierungslog

Dieses Protokoll wird ausschließlich ergänzt. Planung und tatsächlich nachgewiesener Implementierungsstand sind getrennt zu dokumentieren.

## 15.08.2026 – Auftrag 0

**Datum und Commit**  
15.08.2026; Branch `codex/ios-auftrag-0`; uncommitteter Arbeitsstand auf Basis des Android-Referenz-Commits `9ef5f38ee341a0f59a1b2844773c8cadc8a807c2`.

**Auftragsnummer**  
Auftrag 0 – Repository-Grundlagen und kanonische Studienressourcen.

**Ziel**  
Eigenständige, prüfbare Ressourcenbasis für die native iOS-Portierung im Geschwisterverzeichnis `cuelens-ios/`, ohne Änderungen an Android-App oder Backend.

**Geänderte Dateien**

- Spezifikationen nach `cuelens-ios/` verschoben und ausschließlich hinsichtlich Repositorypfaden, Struktur und Dokumentversion 1.0.1 angepasst.
- Projektregeln, README, Schemata, leere Fixture-Verzeichnisse und gepinnte Entwicklungsabhängigkeiten ergänzt.
- Deterministischen Ressourcen-Generator und semantischen Prüfer ergänzt.
- 150 PNG-Dateien bytegleich aus der produktiven Android-Referenz kopiert.
- Content- und Assetmanifest Version 1 erzeugt.

**Ausgeführte Tests**

- `python3 -m py_compile Tools/generate_study_resources.py Tools/verify_study_resources.py`
- `python3 Tools/generate_study_resources.py`
- `.venv/bin/python Tools/generate_study_resources.py --check`
- `.venv/bin/python Tools/verify_study_resources.py`
- zusätzliche `jq`-Prüfung der Arraylängen 50/50/150
- Git-Pfadprüfung auf Änderungen außerhalb von `cuelens-ios/`
- visuelle Stichprobe der Indizes `010`, `026`, `036`, `044` und `049`

**Testergebnis**

- 50 Cue-, 50 Match-A- und 50 Match-B-Dateien vorhanden; alle 512 × 512 Pixel.
- Sämtliche iOS-Kopien sind SHA-256-byteidentisch zur Android-Referenz.
- 50 Matching- und 50 Labeling-Zuordnungen mit lückenlosen Indizes `0...49`.
- Anhang A und die Android-`CueLabelMapping`-Einträge stimmen exakt überein.
- Beide JSON-Dateien entsprechen den versionierten Draft-2020-12-Schemata.
- Erneute Generierung ist reproduzierbar und erzeugt keinen abweichenden Sollzustand.
- Stichprobe: alle 15 PNGs ließen sich visuell fehlerfrei darstellen; die jeweiligen deutschen und englischen Labels waren:
  - `010`: Packungsrascheln/Rauchschleier; pack rustling/smoke haze
  - `026`: gemeinsam draußen/Papiergeschmack; outside together/taste of paper
  - `036`: Halskratzen/Balkonmoment; scratchy throat/balcony moment
  - `044`: ziehen/Dazugehören; taking a drag/belonging
  - `049`: Rauchkringel/Aufglimmen; smoke ring/lighting up

**Sicherheits-/Datenschutzprüfung**

- Keine Teilnehmendenkennungen, App-Tokens oder Gesundheitsdaten ergänzt.
- Keine KI-, Modell-, Kamera-, Tracking- oder Cloud-Ressourcen übernommen.
- `cuelens/grouped/` und `AI_PoC/` sind von Generierung und Verifikation ausgeschlossen.
- Android-App und Backend wurden nicht geändert.

**Abweichungen von der Planung**  
Wegen des auf dem Entwicklungs-Mac vorhandenen Python 3.9 wurde `check-jsonschema` auf die letzte kompatible Version 0.36.2 statt 0.37.4 festgelegt. Sämtliche transitiven Entwicklungsabhängigkeiten wurden ebenfalls exakt gepinnt. Die Draft-2020-12-Validierung bleibt vollständig erhalten.

**Offene Punkte**

- Menschliche Freigabe der dokumentierten Fünferstichprobe.
- Die separat identifizierte Anpassung der iPad-Vollbildvorgabe an iPadOS 26 ist vor Auftrag 1 zu entscheiden und umzusetzen.

**Menschliche Freigabe**  
16.8.26
