# Testprotokoll: CueLens × Testable Resume-/Cooldown-PoC

## Dokumentationsregel

Dieses Dokument wird ausschließlich durch **Anhängen neuer Testeinträge** fortgeschrieben. Bereits dokumentierte Ergebnisse werden nicht überschrieben. Korrekturen werden als neuer Eintrag mit Verweis auf den fehlerhaften Eintrag ergänzt.

Es werden keine personenbezogenen Daten eingetragen. Geräte- und Browserangaben dienen allein der technischen Reproduzierbarkeit.

## Testkonfiguration

| Feld | Wert |
|---|---|
| Testable-Projekt | |
| Trial File | `cuelens_resume_cooldown_poc_de.csv` |
| Git-Commit/Stand | |
| Participation time limit | `2880` Minuten |
| Unique participation | aus |
| Zielgerät | |
| Android-Version | |
| Browser und Version | |
| Bildschirmauflösung laut Gerätespezifikation | |
| Testable-Hintergrundfarbe | `#D7ECE9` |
| Testable-Akzentfarbe | `#006269` |
| Zusätzliche Record-Felder | aus |

## Ergebnisstatus

- **BESTANDEN:** Akzeptanzkriterium erfüllt.
- **TEILWEISE:** Daten bleiben erhalten, aber Zeit- oder Resume-Verhalten weicht von CueLens ab.
- **NICHT BESTANDEN:** Mindestabstand ist umgehbar, Participation wird neu begonnen oder Daten gehen verloren.
- **NICHT BEURTEILBAR:** technischer Fehler verhindert eine aussagekräftige Prüfung.

## Testeinträge

### Vorlage

#### Test-ID

`RC-YYYYMMDD-01`

| Feld | Beobachtung |
|---|---|
| Datum und lokale Zeitzone | |
| Testszenario | |
| Experiment-Link oder Projektkennung | |
| Gerät | |
| Android-Version | |
| Browser und Version | |
| Startzeit Participation | |
| Zeitpunkt Absenden Wert 23 | |
| Zeitpunkt Start Cooldown | |
| Art der Unterbrechung | |
| Zeitpunkt Unterbrechung | |
| Zeitpunkt Rückkehr | |
| Seite nach Rückkehr | |
| Angezeigte Restzeit nach Rückkehr | |
| Zeitpunkt Erreichbarkeit Durchgang 2 | |
| Tatsächlich verstrichene Realzeit | |
| Zeitpunkt Absenden Wert 77 | |
| Debrief erreicht | ja / nein |
| Ergebnisdatei verfügbar | ja / nein |
| Wert 23 im Export | ja / nein / nicht geprüft |
| Wert 77 im Export | ja / nein / nicht geprüft |
| Eine gemeinsame Participation | ja / nein / unklar |
| Vorzeitiger Zugriff auf Durchgang 2 möglich | ja / nein / unklar |
| Ergebnisstatus | BESTANDEN / TEILWEISE / NICHT BESTANDEN / NICHT BEURTEILBAR |

**Beobachtungen:**


**Interpretation:**


**Nächster Prüfschritt:**


---

## Testübersicht

| Test-ID | Szenario | Datum | Gerät/Browser | Resume | Cooldown | Werte 23 und 77 gemeinsam exportiert | Status |
|---|---|---|---|---|---|---|---|
| | ununterbrochener Referenzlauf | | | | | | |
| | Pause bei geöffnetem Browser | | | | | | |
| | Browser vor Ablauf schließen, vor Ablauf zurückkehren | | | | | | |
| | Browser vor Ablauf schließen, nach Ablauf zurückkehren | | | | | | |
| | Reload während der Pause | | | | | | |
| | Bildschirm vier Minuten sperren | | | | | | |
| | Browser vier Minuten im Hintergrund | | | | | | |
| | Browser-Zurück und Link erneut öffnen | | | | | | |
| | gleicher Link in zweitem Tab | | | | | | |
| | Unterbrechung über Nacht | | | | | | |

## Vorläufige Gesamtentscheidung

| Kriterium | Ergebnis | Begründung |
|---|---|---|
| Bereits eingegebener Selbstbericht bleibt über Unterbrechungen erhalten | offen | |
| Cooldown basiert auf verstrichener Realzeit | offen | |
| Cooldown kann nicht umgangen werden | offen | |
| Mehrtägige Fortsetzung derselben Participation ist möglich | offen | |
| Beide Durchgänge erscheinen nach Debrief in einem gemeinsamen Export | offen | |
| Ausbau auf vollständige 20 Durchgänge empfohlen | offen | |
