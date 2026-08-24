# CueLens iOS – Protokoll für den 14-Tage-Langzeittest

Dieses Protokoll darf nur mit synthetischen, zurücksetzbaren Staging-Registrierungen durchgeführt werden. Es werden keine echten Teilnehmerkennungen, App-Tokens, Craving-Werte oder Kompensationscodes in das Protokoll übernommen.

## Voraussetzungen

- freigegebener TestFlight-Build, eindeutig dem Release-Manifest zugeordnet;
- unabhängiger Ethiknachweis vor Tests mit realen Teilnehmenden; der technische Vorabtest bleibt synthetisch;
- mindestens ein reales iPhone und ein reales iPad beziehungsweise zweites iPhone mit unterstütztem iOS;
- je eine zurücksetzbare direkte und Prolific-Testregistrierung;
- kontrollierbare Netzwerkunterbrechung und Zugriff auf datensparsame Serverdiagnostik;
- veröffentlichte App-Store-/TestFlight-Datenschutzangaben entsprechend der Datenflussmatrix.

## Testfälle

### Lauf A – 14 Kalendertage

Ein Gerät führt alle 20 Situationen mit dem produktiven dreistündigen Cooldown aus. Mindestens enthalten sein müssen:

- 10 Cue-Matching- und 10 Cue-Labeling-Situationen mit je fünf Trials;
- App-Neustarts vor einem Trial, nach einem Trial und während eines Cooldowns;
- ein kompletter Geräteneustart;
- ein Sprachwechsel zwischen zwei Situationen;
- Notification-Erlaubnis, Zustellung und nachträglicher Entzug;
- Hintergrundphase während des Matching-Countdowns;
- eine Netzwerkunterbrechung nach lokal gespeichertem Pending-Wert;
- ein manueller Retry nach App-Neustart;
- Abschluss entsprechend der zugeordneten direkten oder Prolific-Registrierung.

Der Zeitraum beginnt mit der ersten bestätigten Situation und endet frühestens nach 14 vollständigen Kalendertagen. Eine beschleunigte Debug-/Staging-Cooldown-Konfiguration ersetzt diesen Nachweis nicht.

### Lauf B – alternativer Abschluss und zweites Gerät

Auf dem zweiten Gerät wird der jeweils andere Abschlussweg vollständig geprüft. Zusätzlich werden Installation über TestFlight, App-Switcher-Sichtschutz, Gerätesperre, Benachrichtigungsentzug und ein Pending-Retry geprüft. Falls Lauf B nicht ebenfalls 14 Tage umfasst, ist dies als ergänzender E2E-Test und nicht als zweiter Langzeittest zu bezeichnen.

## Datensparsames Beobachtungsprotokoll

| Datum/Zeit | Gerätklasse/iOS | Situation nur 1–20 | Ereignis | erwarteter Zustand | Ergebnis | Befund-ID |
|---|---|---:|---|---|---|---|
|  |  |  |  |  |  |  |

Nicht eintragen: Kennung, Token, Craving-Wert, Code, Notification-Text, Serverpayload oder Screenshot sensibler Zustände. Ein technischer Befund erhält eine neutrale ID und wird getrennt ohne Teilnehmerdaten beschrieben.

## Abnahmekriterien

- genau 20 serverbestätigte Situationen und kein zusätzlicher Fortschritt;
- keine verlorenen oder veränderten Pending-Werte;
- kein doppelter serverseitiger Fortschritt nach Retry;
- direkter Code erst nach erfolgreicher Bestätigung sichtbar beziehungsweise Prolific ohne Code;
- keine neue Situation während Pending oder Cooldown;
- Reminder nach Fortschritt und Abschluss konsistent;
- keine Offenlegung in Logs, Notifications oder App-Switcher;
- alle Abweichungen klassifiziert und kritische/hohe Befunde vor Freigabe geschlossen.

## Abschluss

- Beginn: `[ausstehend]`
- Ende nach mindestens 14 Kalendertagen: `[ausstehend]`
- Release-Manifest/Build: `[ausstehend]`
- direkter Abschluss: `[ausstehend]`
- Prolific-Abschluss: `[ausstehend]`
- Ergebnis: `NICHT DURCHGEFÜHRT`
