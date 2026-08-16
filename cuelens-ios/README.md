# CueLens iOS

Dieses Verzeichnis enthält die eigenständige native iOS-Portierung der CueLens-Studien-App. Das bestehende Android-Studio-Projekt liegt unverändert im Geschwisterverzeichnis `../cuelens/`.

## Verbindliche Grundlagen

- `PLATFORM_INDEPENDENT_SPECIFICATION.md`: fachliche, studienmethodische, datenschutzbezogene und sicherheitstechnische Sollfunktion.
- `IOS_ARCHITECTURE_AND_IMPLEMENTATION_PLAN.md`: native iOS-Architektur, Auftragsreihenfolge und Abnahmekriterien.
- Android-Referenz für Auftrag 0: `main`, Commit `9ef5f38ee341a0f59a1b2844773c8cadc8a807c2`.

## Studienressourcen

`Resources/Study/Assets/` enthält bytegleiche Kopien der 50 Cue-, 50 Match-A- und 50 Match-B-PNGs aus `../cuelens/app/src/main/res/drawable/`. Die Android-App verwendet weiterhin ihre eigenen Dateien. Hashes und Abmessungen stehen im Assetmanifest; Label- und Matching-Zuordnungen stehen im Contentmanifest.

Die Verzeichnisse `../cuelens/grouped/` und `../AI_PoC/` sind ausdrücklich keine Quellen für die iOS-Studienressourcen.

## Entwicklungsumgebung für Auftrag 0

```sh
cd cuelens-ios
python3 -m venv .venv
.venv/bin/python -m pip install -r Tools/requirements-dev.txt
.venv/bin/python Tools/generate_study_resources.py --check
.venv/bin/python Tools/verify_study_resources.py
```

Ohne `--check` erzeugt beziehungsweise aktualisiert der Generator die bytegleichen Kopien und die beiden JSON-Manifeste deterministisch. Nach der Erzeugung muss ein erneuter Lauf mit `--check` erfolgreich sein.

## Datenschutz und Abgrenzung

Dieses Verzeichnis darf keine echten Teilnehmendenkennungen, App-Tokens oder Gesundheitsdaten enthalten. Auftrag 0 enthält weder Xcode-Projekt noch App-, Netzwerk-, Aktivierungs- oder Persistenzlogik. Fixtures bleiben bis zu den zugehörigen späteren Aufträgen leer.

