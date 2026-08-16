# Arbeitsregeln für die native CueLens-iOS-Portierung

Dieses Verzeichnis enthält die eigenständige native iOS-Portierung. Die fachlichen und studienmethodischen Vorgaben in `PLATFORM_INDEPENDENT_SPECIFICATION.md` haben Vorrang vor technischen Einzelentscheidungen.

## Verbindliche Grenzen

- `../cuelens/`, `../AI_PoC/` und `../cuelens.each-and-every.de/` nicht ändern.
- Keine Drittanbieterpakete zur App oder zum Produktionscode ergänzen. Gepinnte, dokumentierte Entwicklungswerkzeuge unter `Tools/` sind zulässig.
- Keine Kamera-, Foto-, Mikrofon-, Standort-, Tracking-, Werbe- oder Cloud-Synchronisationsberechtigung ergänzen.
- Kein Plattformfeld und keinen Plattform-Suffix in Studienrequests oder App-Versionswerten ergänzen.
- Keine echten Teilnehmendendaten, App-Tokens, E-Mail-Adressen oder Gesundheitsdaten in Tests, Fixtures, Logs oder Dokumentation verwenden.
- Produktiv-URLs ausschließlich in der späteren Release-`.xcconfig` ablegen.
- Markdown-Protokolle, insbesondere `CODEX_IMPLEMENTATION_LOG.md`, nur ergänzen und nicht stillschweigend überschreiben.
- Jede Änderung mit angemessenen Tests und einem Eintrag im Implementierungslog abschließen.
- Keine Force-Unwraps, `try!` oder erzwungenen Casts im Produktionscode verwenden.
- Keine Netzwerk-, Keychain- oder Dateizugriffe direkt aus SwiftUI-Views ausführen.

## Studienressourcen

- `../cuelens/app/src/main/res/drawable/` ist die unveränderte Android-Referenz für die 150 produktiven PNG-Dateien.
- Ressourcen nur über `Tools/generate_study_resources.py` nach `Resources/Study/Assets/` kopieren.
- Bilder niemals umkodieren, skalieren, komprimieren oder inhaltlich bearbeiten.
- Labeltexte müssen gleichzeitig mit Anhang A der plattformunabhängigen Spezifikation und den Android-`CueLabelMapping`-Einträgen übereinstimmen.
- `../cuelens/grouped/`, KI-PoC-Dateien und Modelle sind keine zulässigen Studienressourcen.

