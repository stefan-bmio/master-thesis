# CueLens: Implementierungsanweisungen fuer Codex

Diese Datei beschreibt den geplanten technischen Stand der ersten Play-Store-Version der Android-App im Verzeichnis `cuelens` und des zugehoerigen PHP-Backends. Sie dient zugleich als Vorlage fuer die spaetere technische Dokumentation.

Die erste Play-Store-Version ist eine Pre-Study-App. Sie soll die spaetere Aktivierung der Studie vorbereiten, aber noch keine produktive Studiensituation fuer die wissenschaftliche Auswertung freigeben. Sichtbar sind nur Funktionen, die keine serverseitige Feature-Aktivierung benoetigen oder diese Aktivierung erst ermoeglichen.

Die Abschnitte zur produktiven Studienfassung bleiben in dieser Datei erhalten, obwohl sie fuer die erste Play-Store-Version initial deaktiviert sind. Sie dokumentieren die bereits geplante Studienlogik, Pseudonymisierung, Serverlogik und Retry-Strategie, damit die Pre-Study-App nicht als Ersatz der eigentlichen Studienspezifikation missverstanden wird.

## 0. Zielbild fuer Branch `pre_study_app`

In diesem Branch soll die erste App-Version entstehen, die ueber den Play Store bereitgestellt werden kann. Ziel ist eine robuste, datensparsame und testbare Basisversion mit folgenden initial sichtbaren Funktionen:

1. Infofeed mit serverseitig gepflegten Nachrichten.
2. Nach eventuellen Info-Nachrichten Startseite.
3. E-Mail-Aktivierung fuer spaetere Studienteilnahme.
4. Beispiel-Studiensituation ohne Uebertragung eines Craving-Werts.
5. Feedback-Formular mit serverseitiger Speicherung.
6. Sprachauswahl Deutsch/Englisch ueber Android-Internationalisierung.
7. Optionale Benachrichtigungen fuer neue Info-Nachrichten, wenn die Nutzerin oder der Nutzer diese zulaesst.
8. Update-Hinweise moeglichst ueber Android- beziehungsweise Play-Store-Funktionen, nicht ueber einen eigenen APK-Download.

Alle anderen bereits implementierten App-Funktionen, insbesondere produktive Studiensituationen, echte Craving-Uebertragung, Fortschrittszaehlung, Sperrzeiten, Abrechnungscode-Logik und nicht benoetigte Diagnosefunktionen, sind initial deaktiviert und fuer Teilnehmende nicht sichtbar. Ausnahme ist die E-Mail-Aktivierung, weil sie fuer die spaetere serverseitige Freischaltung benoetigt wird.

## 1. Grundprinzipien

- Implementiere inkrementell, einfach, wartbar und testbar.
- Behandle CueLens als Studienprototyp, nicht als Therapie-App. UI-Texte duerfen keine Wirksamkeitsversprechen enthalten.
- Priorisiere Datensparsamkeit, robuste Studienlogik, reproduzierbare Reizpraesentation, nachvollziehbare Zustandsuebergaenge und geringe Anforderungen an reale Android-Endgeraete.
- Fuege Berechtigungen nur hinzu, wenn sie fuer eine konkrete Funktion zwingend erforderlich sind.
- Personenbezogene Registrierungs- und Abrechnungsdaten gehoeren nicht in die Android-App und nicht in wissenschaftliche Selbstberichte.
- Trenne Registrierung, Aktivierung, Feedback, Infofeed und spaetere wissenschaftliche Selbstberichte technisch und tabellarisch.
- Behandle Netzwerkfehler als zentrale Robustheitsanforderung. Die App muss in der spaeteren produktiven Studienfassung ausstehende Selbstberichte erneut senden koennen und einen erhaltenen Abrechnungscode bis zur Bestaetigung lokal zwischenspeichern.
- Uebertrage keine Felder, die serverseitig deterministisch ableitbar sind. Der Server leitet den Studienfortschritt aus der Anzahl bereits gespeicherter Selbstberichte fuer die pseudonyme Kennung ab.
- Speichere in `self_reports` nicht das App-Token selbst, sondern nur den daraus abgeleiteten SHA-256-Hash als `participant_id`.
- Nutze Android- und Play-Store-Mechanismen, wenn sie den Zweck bereits sicher und wartbar abdecken, zum Beispiel Android-Stringressourcen fuer Internationalisierung, WorkManager fuer nicht zeitkritische Hintergrundsynchronisation und Play-Store-Updatefunktionen fuer Updates.
- Kein eigener Mechanismus zum Nachladen oder Ausfuehren von App-Code. Fehlerbehebungen am nativen App-Code werden ueber den regulaeren Android-/Play-Store-Updatekanal ausgeliefert.

## 2. Initial sichtbare App-Funktionen

### 2.1 App-Start und Navigationsfluss

Beim Start gilt folgende Reihenfolge:

1. App initialisiert Sprache, lokale Einstellungen und Netzwerk-Clients.
2. App ruft den Infofeed ab, sofern Netzwerk verfuegbar ist.
3. App zeigt noch nicht ausgeblendete Info-Nachrichten als Vollbild-Nachrichtenseiten an.
4. Danach zeigt die App die Startseite oder kehrt zur vorherigen Seite zurueck, wenn der Infofeed aus einem bestehenden App-Zustand heraus geoeffnet wurde.

Wenn der Infofeed nicht erreichbar ist, darf der App-Start nicht blockieren. Die App zeigt eine kurze neutrale Fehlermeldung. Fuer diese erste Version gibt es keine serverseitige Pflichtnachricht mit App-Sperre.

Die sichtbare Hauptnavigation der Startseite besteht aus genau diesen Optionen:

- E-Mail-Aktivierung
- Beispiel-Studiensituation
- Feedback

Weitere implementierte App-Bereiche duerfen weder als Schaltflaeche, Menuepunkt, Deep Link noch ueber zufaellige Zustandsuebergaenge erreichbar sein.

### 2.2 Infofeed

#### Serverfunktion

Ein PHP-Endpunkt liefert alle Info-Nachrichten aus der Tabelle `messages` aus:

```sql
CREATE TABLE messages (
    id BIGINT NOT NULL PRIMARY KEY,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    text_de TEXT NOT NULL,
    text_en TEXT NOT NULL
);
```

Der Endpunkt soll vorzugsweise `GET /messages.php` oder eine konsistente vorhandene Routingvariante verwenden. Die Antwort ist JSON:

```json
{
  "messages": [
    {
      "id": 1,
      "created_at": "2026-07-07T20:00:00Z",
      "text_de": "Willkommen zur CueLens-Studie.",
      "text_en": "Welcome to the CueLens study."
    }
  ]
}
```

Anforderungen:

- Nur `GET` akzeptieren; andere Methoden mit HTTP 405 ablehnen.
- Daten per Prepared Statement aus der Datenbank lesen.
- Ausgabe nach `created_at ASC, id ASC` sortieren.
- `id` als numerische, stabile Nachrichtenkennung verwenden.
- Nachrichten in Deutsch und Englisch bereitstellen.
- Keine personenbezogenen Daten in der Nachrichtentabelle speichern.
- Bei Datenbankfehlern HTTP 500 mit generischer Fehlermeldung liefern, ohne interne Details auszugeben.

#### App-Funktion

Die App zeigt jede nicht ausgeblendete Nachricht als Vollbildseite an. Die Seite enthaelt:

- Nachrichtentext in der aktuell gewaehlten Sprache, sofern vorhanden.
- Checkbox `Diese Nachricht nicht mehr anzeigen`.
- Button `OK`.

Verhalten:

- Die App speichert lokal die IDs der Nachrichten, bei denen die Checkbox beim Druecken von `OK` aktiv war.
- Die Speicherung erfolgt in einer kleinen lokalen Key-Value-Struktur, vorzugsweise Jetpack DataStore.
- Lokal gespeichert wird nur eine Menge von `Long`-IDs, keine Nachrichtentexte.
- Nachrichten, deren ID lokal gespeichert ist, werden beim naechsten App-Start nicht mehr angezeigt.
- Nachrichten, die nur mit `OK` bestaetigt werden, ohne dass die Checkbox gesetzt ist, duerfen fuer die aktuelle Sitzung geschlossen werden, koennen aber bei einem spaeteren App-Start erneut erscheinen.
- Die Nachrichtenseite darf nicht als therapeutische Intervention formuliert werden und keine Aussagen zum individuellen Rauchverlangen enthalten.

### 2.3 Benachrichtigungen fuer Info-Nachrichten

Benachrichtigungen sind in der ersten Version nur fuer Info-Nachrichten vorgesehen und nur dann aktiv, wenn die Nutzerin oder der Nutzer sie zulaesst. Fuer die erste Version ist kein Firebase Cloud Messaging erforderlich. Die App darf den `messages`-Endpunkt periodisch im Hintergrund mit WorkManager abrufen und bei neuen, noch nicht ausgeblendeten Nachrichten eine lokale Android-Benachrichtigung erzeugen.

Anforderungen:

- Unter Android 13 und hoeher die Runtime Permission `POST_NOTIFICATIONS` erst kontextbezogen anfragen.
- Keine Benachrichtigungspflicht: Bei Ablehnung funktionieren Infofeed, Startseite, Aktivierung, Beispiel und Feedback weiterhin.
- Inhalt neutral halten, zum Beispiel `Neue Information zu CueLens verfuegbar`.
- Keine gesundheitsbezogenen Inhalte, kein Rauchstatus, kein Craving-Wert und keine personenbezogenen Informationen in Benachrichtigungstitel oder -text aufnehmen.
- Beim Tippen auf die Benachrichtigung die App oeffnen und den Infofeed neu abrufen.
- Per Android WorkManager wird periodisch auf neue Nachrichten geprueft.
- Die Hintergrundpruefung ist nicht zeitkritisch. Android darf sie wegen Doze, App Standby, Energiesparmodus oder Netzbedingungen verspaetet ausfuehren.
- Der autoritative Pfad bleibt der Abruf beim App-Start oder beim manuellen Oeffnen des Infofeeds.

### 2.4 Startseite

Nach eventuellen Info-Nachrichten zeigt die App eine einfache Startseite im CueLens-Webseitenstil. Die Startseite enthaelt:

- Kurze neutrale Begruessung.
- Drei grosse, gut erreichbare Aktionen: `E-Mail-Aktivierung`, `Beispiel-Studiensituation`, `Feedback`.
- Staendig sichtbaren Sprachumschalt-Button oben rechts.

Die Startseite darf keine produktiven Studiensituationen, keinen Studienfortschritt, keinen Abrechnungscode und keine realen Craving-Uebertragungen anzeigen.

### 2.5 E-Mail-Aktivierung

Die E-Mail-Aktivierung bleibt als einzige bereits implementierte Freischaltungsfunktion sichtbar. Sie dient dazu, die spaetere Teilnahme technisch vorzubereiten.

Anforderungen:

- Eingabe einer E-Mail-Adresse.
- Uebertragung an den bestehenden Aktivierungsendpunkt.
- Keine Anzeige oder Speicherung der E-Mail-Adresse als dauerhafter App-Zustand nach erfolgreicher Aktivierung.
- Falls ein App-Token ausgegeben wird, lokale Speicherung nur zweckgebunden fuer spaetere Studienfunktionen.
- Erfolgreiche Aktivierung schaltet in dieser ersten App-Version keine produktiven Studiensituationen frei.
- Fehlermeldungen muessen neutral sein und duerfen nicht offenlegen, ob eine konkrete E-Mail-Adresse in der Registrierung existiert, soweit dies vermeidbar ist.

### 2.6 Beispiel-Studiensituation

Die Beispiel-Studiensituation ist eine rein lokale Demonstration der Interaktionslogik. Sie dient der Usability, der Erwartungsklaerung und dem technischen Test der UI. Sie ist nicht Teil der wissenschaftlichen Auswertung.

Ablauf:

1. Einmal Cue-Matching.
2. Einmal Cue-Labeling.
3. Einmal Craving-Slider.
4. Abschlussseite mit Hinweis, dass keine Studiendaten uebertragen wurden.

Beispielressourcen:

- Fuer Cue-Matching und Cue-Labeling koennen `cue_000.png` und `cue_001.png` verwendet werden.
- Falls vorhandene Ressourcennamen Android-konform ohne Dateiendung referenziert werden, im Code `R.drawable.cue_000` und `R.drawable.cue_001` verwenden.

Wichtige Grenzen:

- Der Craving-Wert wird in der Beispiel-Studiensituation nicht an den Server uebertragen.
- Der Craving-Wert wird nicht dauerhaft gespeichert.
- Die Beispiel-Studiensituation erhoeht keinen Studienfortschritt.
- Sie setzt keine Sperrzeit.
- Sie erzeugt keinen Abrechnungscode.
- Sie verwendet keine serverseitige Feature-Aktivierung.
- Sie darf nicht mit der eigentlichen Studie verwechselt werden. UI-Texte muessen klarstellen, dass es sich um ein Beispiel handelt.

### 2.7 Feedback-Formular

Das anonyme Feedback-Formular ist ohne Aktivierung verfuegbar. Es dient der Optimierung der Studiendurchfuehrung, nicht der wissenschaftlichen Craving-Auswertung.

UI-Felder:

1. Einzeiliges Freitextfeld: `Wie haben Sie von der CueLens-Studie erfahren?`
2. Mehrzeiliges Freitextfeld: `Was gefaellt Ihnen an der Studie, wobei gab es eventuell Probleme?`
3. Button `Absenden`.

Technische Anforderungen:

- Beide Felder als Freitext behandeln und serverseitig laengenbegrenzen.
- Hinweis, keine personenbezogenen Daten, insbesondere Abrechnungstoken, einzugeben.
- Keine automatische Uebernahme von E-Mail-Adresse oder App-Token in das Feedback.
- Nach erfolgreichem Absenden eine neutrale Bestaetigung anzeigen.
- Bei Netzwerkfehlern eine verstaendliche Fehlermeldung anzeigen. Fuer die erste Version ist keine lokale Retry-Warteschlange fuer Feedback erforderlich.

#### Feedback-Endpunkt

Ein PHP-Endpunkt nimmt Feedback per `POST` entgegen und speichert es in einer separaten Tabelle, zum Beispiel:

```sql
CREATE TABLE feedback (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    source TEXT NULL,
    comment TEXT NULL,
    app_version VARCHAR(64) NULL
);
```

Request-Beispiel:

```json
{
  "source": "Flyer in Beratungsstelle",
  "comment": "Die Anmeldung war einfach. Beim Beispiel war mir der Unterschied zwischen den Aufgaben zuerst unklar.",
  "app_version": "1.0.0"
}
```

Serveranforderungen:

- Nur `POST` akzeptieren; andere Methoden mit HTTP 405 ablehnen.
- JSON akzeptieren; optional kann `application/x-www-form-urlencoded` ergaenzt werden, falls die bestehende Backend-Struktur dies nahelegt.
- Eingaben serverseitig validieren und begrenzen, zum Beispiel `source` maximal 500 Zeichen und `comment` maximal 5000 Zeichen.
- Prepared Statements verwenden.
- Keine SQL- oder PHP-Fehlerdetails ausgeben.
- Keine Feedbackdaten in `self_reports` speichern.
- Kein App-Token und keine E-Mail-Adresse verlangen.

### 2.8 Sprachauswahl Deutsch/Englisch

Die App muss Deutsch und Englisch unterstuetzen. Alle sichtbaren UI-Texte werden ueber den ueblichen Android-Internationalisierungsmechanismus umgesetzt.

Anforderungen:

- Alle sichtbaren UI-Texte aus Kotlin/Compose in Android-Stringressourcen verschieben.
- Mindestens `res/values/strings.xml` fuer Deutsch und `res/values-en/strings.xml` fuer Englisch pflegen.
- Keine hartkodierten UI-Texte im Kotlin-Code, ausser technisch begruendete Debug-Strings ausserhalb der Produktions-UI.
- Staendig sichtbarer Umschalt-Button oben rechts.
- Der Umschalt-Button wechselt die Sprache der aktuell sichtbaren Texte unmittelbar.
- Die ausgewaehlte Sprache lokal speichern, vorzugsweise DataStore.
- Die Sprachauswahl darf keine App-Neuinstallation und keinen Serverkontakt erfordern.
- Servernachrichten aus `messages.text_de` und `messages.text_en` werden passend zur aktuell gewaehlten Sprache angezeigt.

### 2.9 Update-Hinweise und Fehlerbehebungen

Fehlerbehebungen am nativen App-Code werden ueber den regulaeren Play-Store-Updatekanal ausgeliefert. Es darf kein eigener APK-Download, kein dynamisches Nachladen von Kotlin-/Java-Code und kein dynamisches Nachladen nativer Bibliotheken implementiert werden.

Anforderungen:

- Nach Moeglichkeit Google-Play-In-App-Updates oder eine vergleichbare Play-Store-konforme Update-Benachrichtigung verwenden.
- Fuer kritische Fehler kann der Server spaeter eine Mindestversion in einer Konfiguration ausliefern. In dieser ersten Version reicht eine einfache, zukunftsfaehige Struktur, wenn bereits ein Konfigurationsabruf existiert.
- Nicht aktivierte Features duerfen trotz vorhandenen Codes nicht sichtbar sein, bis eine spaetere App-Version und eine serverseitige Aktivierung dies ausdruecklich erlauben.
- Die App soll nicht versuchen, den Play Store durch eigene Update-Mechanismen zu umgehen.

### 2.10 Gestaltung und Bezug zur Webseite

Die App soll visuell an die Webseite unter `cuelens.each-and-every.de` angelehnt sein, soweit dies in einer nativen Android-App sinnvoll und barrierearm moeglich ist.

Orientierung an `cuelens.each-and-every.de/index.css`:

- Hintergrundfarbe: `#D7ECE9`.
- Primaerfarbe fuer Buttons und Akzente: `#006269`.
- Fehlerfarbe: `#7A2E3A`.
- Schlichte, gut lesbare Typografie. Auf Android die Systemschrift verwenden, statt Helvetica zu erzwingen.
- Buttons und Eingabefelder mit ausreichend grosser Touch-Zielflaeche, mindestens 44 dp beziehungsweise Android-konform eher 48 dp.
- Zentrierte, ruhige Darstellung ohne uebermaessige visuelle Reize.

Die App muss nicht pixelgenau wie die Webseite aussehen. Wichtiger sind Wiedererkennbarkeit, Lesbarkeit, robuste Darstellung auf kleinen Displays und Screenreader-Vertraeglichkeit.

## 3. Initial deaktivierte und unsichtbare Funktionen

Folgende Funktionen duerfen in der ersten Play-Store-Version zwar im Code vorhanden sein, sind aber fuer Teilnehmende initial nicht sichtbar und nicht erreichbar:

- Produktive Studiensituationen.
- Mehrfachdurchlaeufe mit Studienfortschritt.
- Serverseitige Uebertragung realer Craving-Werte aus Studiensituationen.
- Automatische Ableitung von Bedingung und Situation fuer die Auswertung.
- Sperrzeitlogik zwischen produktiven Studiensituationen.
- Abrechnungscode-Ausgabe und Abrechnungscode-Bestaetigung.
- KI-gestuetzte Bilderkennung, sofern bereits vorbereitet.
- Debug-, Diagnose- oder Testoberflaechen.
- Nicht benoetigte Upload- oder Exportfunktionen.

Die Deaktivierung darf nicht nur optisch erfolgen. Nicht sichtbare Funktionen muessen auch gegen direkte Navigation, versehentlich erreichbare Compose-Zustaende und Deep Links abgesichert sein. Fuer die erste Version gilt eine Allowlist der sichtbaren Routen:

- `info_messages`
- `home`
- `email_activation`
- `demo_study_situation`
- `feedback`

Alle anderen Routen sind fuer Production-Builds zu sperren oder nicht zu registrieren.

## 4. Serverseitige Tabellen und Endpunkte der ersten Play-Store-Version

### 4.1 Registrierung und Aktivierung

Die bestehende Tabelle `register` enthaelt Teilnahmeinformationen ohne Bezug zu Craving-Werten und ohne Bezug zu Feedback. Die E-Mail-Aktivierung kann weiterhin den bestehenden Aktivierungsendpunkt verwenden.

Grundregeln:

- Der Server prueft, ob die E-Mail-Adresse fuer eine App-Aktivierung berechtigt ist.
- Wenn ein App-Token ausgegeben wird, darf dieses nicht dauerhaft in Relation zur E-Mail-Adresse gespeichert werden.
- In `register` kann weiterhin ein Zeitstempel wie `app_token_issued_at` gesetzt werden, um Mehrfachaktivierungen zu vermeiden.
- Die erfolgreiche E-Mail-Aktivierung aktiviert in dieser ersten Version keine produktive Studiensituation.

### 4.2 Info-Nachrichten

Tabelle:

```sql
CREATE TABLE messages (
    id BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    text_de TEXT NOT NULL,
    text_en TEXT NOT NULL
);
```

Endpoint:

- `GET /messages.php`
- Antwort: JSON mit Array `messages`
- Keine Authentifizierung fuer diese allgemeine Infoseite erforderlich, solange keine vertraulichen Inhalte ausgeliefert werden.

### 4.3 Feedback

Tabelle:

```sql
CREATE TABLE feedback (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    source TEXT NULL,
    comment TEXT NULL,
    app_version VARCHAR(64) NULL
);
```

Endpoint:

- `POST /feedback.php`
- Speichert `source`, `comment` und optional `app_version`.
- Keine Speicherung in `self_reports`.
- Keine Verknuepfung mit Registrierung oder App-Token.

### 4.4 Selbstberichte fuer spaetere Studienversion

Die Tabelle `self_reports` und die produktive Selbstbericht-Uebertragung bleiben fuer diese erste Play-Store-Version deaktiviert. Wenn der Code bereits vorhanden ist, darf er in Production nicht durch die UI erreichbar sein.

Fuer spaetere Studienversionen bleibt das Ziel bestehen:

- `participant_id` ist der SHA-256-Hash des lokal gespeicherten App-Tokens und nicht der rohe Token.
- `self_reports` enthaelt keine E-Mail-Adresse, keinen Namen und keine Zahlungsdaten.
- Die produktive Craving-Uebertragung wird erst durch eine spaetere Feature-Aktivierung und eine geeignete App-Version freigegeben.

## 5. Android-Architektur der ersten Play-Store-Version

### 5.1 Empfohlene Zustandsstruktur

Die App soll eine klare, testbare Zustandsstruktur verwenden:

```kotlin
sealed interface AppRoute {
    data object InfoMessages : AppRoute
    data object Home : AppRoute
    data object EmailActivation : AppRoute
    data object DemoStudySituation : AppRoute
    data object Feedback : AppRoute
}
```

Fuer die Demo kann eine eigene lokale Phasenstruktur verwendet werden:

```kotlin
sealed interface DemoPhase {
    data object CueMatching : DemoPhase
    data object CueLabeling : DemoPhase
    data object CravingSlider : DemoPhase
    data object Finished : DemoPhase
}
```

Produktive Studienphasen duerfen in der ersten Version nicht ueber die Production-Navigation erreichbar sein.

### 5.2 Lokaler Zustand

Persistiere nur kleine, zweckgebundene Werte:

- Ausgewaehlte Sprache.
- IDs ausgeblendeter Info-Nachrichten.
- Optional App-Token aus erfolgreicher E-Mail-Aktivierung.
- Optional Berechtigungsstatus fuer Benachrichtigungen.
- Optional Menge bereits lokal benachrichtigter Nachrichten-IDs, damit periodische Hintergrundpruefungen nicht dieselbe lokale Benachrichtigung wiederholt ausloesen.

Nicht lokal persistieren:

- Demo-Craving-Wert.
- Feedback-Freitexte nach erfolgreichem Absenden.
- Nachrichtentexte aus dem Infofeed.
- E-Mail-Adresse nach abgeschlossener Aktivierung.
- Produktive Studienfortschritte, solange produktive Studiensituationen deaktiviert sind.

### 5.3 Netzwerk

- Netzwerkzugriffe laufen nicht auf dem UI-Thread.
- Timeouts setzen.
- HTTPS fuer Production.
- Klartextverkehr nur fuer Staging und lokale Entwicklung.
- Endpunkte ueber `BuildConfig` oder eine vergleichbare Build-Konfiguration bereitstellen.
- Fehlerzustand in der UI eindeutig anzeigen.

### 5.4 Barrierearmut

- Alle interaktiven Elemente mit sinnvollen `contentDescription`- beziehungsweise Semantik-Informationen versehen.
- Touch-Ziele ausreichend gross gestalten.
- Spracheinstellungen und Screenreader nicht behindern.
- Bei Bildaufgaben kurze neutrale Alternativtexte verwenden, ohne die Aufgabe zu loesen.

## 6. Tests fuer die erste Play-Store-Version

Fuer die erste Play-Store-Version sind umfangreiche Tests mit moeglichst vollstaendiger Branch-Abdeckung umzusetzen. Ziel ist nicht nur hohe Zeilenabdeckung, sondern insbesondere Abdeckung aller Entscheidungszweige.

### 6.1 Android-Unit-Tests

Mindestens testen:

- Filterung der Info-Nachrichten anhand lokal gespeicherter ausgeblendeter IDs.
- Sortierung oder erwartete Reihenfolge der Nachrichten, falls appseitig abgesichert.
- Verhalten von `OK` mit gesetzter Checkbox: ID wird persistiert.
- Verhalten von `OK` ohne gesetzte Checkbox: ID wird nicht dauerhaft persistiert.
- Fehlerfall bei nicht erreichbarem Infofeed: Startseite bleibt erreichbar.
- Sprachumschaltung Deutsch/Englisch aktualisiert sichtbare Texte.
- Persistenz der Sprachauswahl.
- Demo-Ablauf Cue-Matching -> Cue-Labeling -> Craving-Slider -> Abschluss.
- Demo-Craving-Wert wird nicht persistiert und nicht an einen Netzwerkclient uebergeben.
- Feedback-Validierung fuer leere, kurze, lange und mehrzeilige Eingaben.
- Produktionsnavigation erlaubt nur die freigegebenen Routen.
- Initial deaktivierte Studienfeatures sind nicht erreichbar.
- WorkManager-Logik markiert neue Nachrichten als lokal benachrichtigt, ohne ausgeblendete Nachrichten erneut anzukuendigen.

### 6.2 Android-Compose-UI-Tests

Mindestens testen:

- Startseite zeigt genau die drei Hauptaktionen.
- Sprachbutton ist auf Info-Nachrichtenseite, Startseite, Aktivierung, Demo und Feedback sichtbar.
- Umschaltung der Sprache aendert die aktuell sichtbaren Labels ohne App-Neustart.
- Info-Nachrichtenseite zeigt Checkbox und OK-Button.
- Feedback-Formular enthaelt beide Freitextfelder und den Absenden-Button.
- Beispiel-Studiensituation zeigt die erwarteten Phasen und am Ende den Hinweis, dass keine Daten uebertragen wurden.
- Produktive Studienbuttons oder versteckte Testmenues erscheinen im Production-Build nicht.

### 6.3 Android-Integrationstests mit Mock-Server

Mindestens testen:

- Erfolgreicher Abruf von `messages`.
- Leerer Infofeed.
- HTTP 500 beim Infofeed.
- Ungueltiges JSON beim Infofeed.
- Erfolgreiches Absenden von Feedback.
- HTTP 400/500 beim Feedback.
- Aktivierungsantwort Erfolg und Fehler, ohne dass produktive Studienfunktionen sichtbar werden.

### 6.4 PHP-Backend-Tests

Nach Moeglichkeit PHPUnit-Tests oder vergleichbare automatisierte Tests fuer:

- `GET /messages.php` liefert alle Nachrichten als JSON.
- `messages.php` akzeptiert keine anderen HTTP-Methoden.
- Datenbankfehler fuehren zu generischer Fehlerantwort.
- `POST /feedback.php` speichert gueltiges Feedback.
- `feedback.php` begrenzt zu lange Felder.
- `feedback.php` akzeptiert keine anderen HTTP-Methoden.
- SQL-Injection-Versuche werden als Daten behandelt und nicht ausgefuehrt.
- Weder Infofeed noch Feedback erfordern oder speichern App-Token.

### 6.5 Coverage-Ziel

- Branch Coverage fuer neue Kotlin-Logik moeglichst vollstaendig.
- Branch Coverage fuer neue PHP-Endpunkte moeglichst vollstaendig.
- Coverage-Berichte in der CI erzeugen, wenn die bestehende Projektstruktur dies ohne unverhaeltnismaessigen Aufwand erlaubt.
- Falls einzelne Branches nicht automatisiert testbar sind, Acceptance-Check dokumentieren.

## 7. Definition of Done fuer die erste Play-Store-Version

Eine Aenderung gilt nur dann als abgeschlossen, wenn alle zutreffenden Punkte erfuellt sind:

- Die App baut in Staging und Production.
- Die erste Play-Store-Version zeigt nur Infofeed, Startseite, E-Mail-Aktivierung, Beispiel-Studiensituation, Feedback und Sprachumschaltung.
- Alle anderen bereits implementierten Features mit Ausnahme der E-Mail-Aktivierung sind initial deaktiviert und fuer Teilnehmende nicht sichtbar.
- Die Beispiel-Studiensituation uebertraegt keinen Craving-Wert und persistiert keinen Demo-Craving-Wert.
- Feedback wird in einer separaten Tabelle gespeichert und nicht mit `self_reports`, E-Mail-Adresse oder App-Token verknuepft.
- Info-Nachrichten werden aus `messages` geladen und ausgeblendete Nachrichten-IDs werden lokal gespeichert.
- Benachrichtigungen fuer Info-Nachrichten sind optional, neutral formuliert und funktionieren nur nach Zustimmung.
- Alle UI-Texte liegen in Android-Stringressourcen fuer Deutsch und Englisch.
- Der Sprachumschalt-Button ist oben rechts staendig sichtbar und aktualisiert die aktuell sichtbaren Texte.
- Designentscheidungen orientieren sich an `cuelens.each-and-every.de/index.css`, ohne Android-Konventionen und Barrierearmut zu verletzen.
- Updates werden ueber Play-Store-konforme Mechanismen vorbereitet; es gibt keinen eigenen APK-Download.
- Die Studienlogik wurde nicht unbeabsichtigt veraendert.
- Neue Datenfelder sind im Code, Backend-Vertrag und in der Dokumentation beschrieben.
- Neue lokale Speicherungen sind nach Zweck, Lebensdauer und Schutzbedarf dokumentiert.
- Fehlerfaelle fuehren zu einem eindeutigen UI-Zustand.
- Tests decken die Kernpfade und Entscheidungszweige der neuen Funktionen moeglichst vollstaendig ab.
- Die Datenbank enthaelt keine dauerhafte Relation zwischen Registrierung, App-Token, Feedback und spaeterer Berichtstabelle.

## 8. Sicherheitskonzepte

### 8.1 Pseudonymisierungsziel

Die technische Datenschutzarchitektur beschreibt keine vollstaendige Anonymisierung, sondern eine Pseudonymisierung der wissenschaftlichen Selbstberichte. Das ist fuer das Within-Subject-Design erforderlich, weil mehrere Selbstberichte derselben App-Installation zusammengefuehrt werden muessen. Die Selbstberichte enthalten keine direkten Identifikatoren wie Name, E-Mail-Adresse, IBAN oder BIC. Sie enthalten jedoch mit `participant_id` eine pseudonyme Kennung. Datenschutzfachlich bleiben die Selbstberichte deshalb als personenbezogene beziehungsweise gesundheitsbezogene Daten mit reduziertem Identifizierungsrisiko zu behandeln.

Die Pseudonymisierung beruht auf folgenden technischen und organisatorischen Massnahmen:

- Direkte Registrierungs- und Abrechnungsdaten liegen ausschliesslich in `register` und werden nicht in die App oder die Berichtstabelle uebernommen.
- Das App-Token wird nach der initialen Freischaltung nur lokal in der App gespeichert und serverseitig nicht dauerhaft persistiert.
- Die auswertbare Kennung `participant_id` wird in `submit.php` als `hash('sha256', strtolower($appToken))` aus dem App-Token abgeleitet und in `self_reports` gespeichert.
- Die App uebertraegt das App-Token bei jedem Selbstbericht, damit der Server die stabile pseudonyme Kennung erneut berechnen kann.
- Die Registrierung enthaelt nur den Zeitpunkt der Token-Ausgabe in `app_token_issued_at`, nicht aber das App-Token selbst und nicht dessen Hash.
- Eine Wiederzuordnung zu einer natuerlichen Person soll ohne Zusatzinformationen aus Registrierung, lokaler App-Installation, Zahlungsabwicklung, Serverlogs oder aktivem Supportvorgang nicht moeglich sein. Diese Zusatzinformationen sind organisatorisch und technisch getrennt zu halten.

### 8.2 Grundsaetze

- Kein produktives Logging von E-Mail-Adressen, App-Tokens, Hashes, Selbstbericht-Werten, Serverantworten oder personenbezogenen Angaben.
- HTTPS in Production; Klartext nur als Staging-Ausnahme.
- Datenbankzugangsdaten liegen serverseitig in `config`, nicht im Repository und nicht in Web-auslieferbaren Verzeichnissen.
- Lokale App-Werte wie App-Token, ausstehender Selbstbericht und Abrechnungscode verschluesseln, wenn sie als sensibel eingestuft werden.
- Keine sensiblen Daten in Zwischenablage, Screenshots, externem Speicher oder Mediengalerie, solange dies nicht ausdruecklich vorgesehen ist.

### 8.3 Lokaler Zustand

Persistiere nur kleine, zweckgebundene Werte:

- `app_token`: UUID, die beim initialen Freischaltungsrequest vom Server ausgeliefert und nur in der App persistiert wird.
- `next_situation_available_at_millis`: fruehester Startzeitpunkt der naechsten Situation.
- `confirmed_situation_count`: lokal bestaetigte Anzahl erfolgreich uebermittelter Studiensituationen.
- `matching_order`: stabile zufaellige Reihenfolge der Cue-Matching-Aufgaben.
- `pending_submission_craving`: abgeschlossener Durchgang, dessen Serverantwort noch fehlt.
- `compensation_code`: nach dem letzten Selbstbericht erhaltener Abrechnungscode, solange dessen Bestaetigung noch aussteht.

Lokale Daten duerfen keine Namen, Zahlungsdaten oder Freitexte enthalten. Die E-Mail-Adresse wird nur fuer den initialen Freischaltungsrequest verwendet und danach nicht in der App als Studienzustand benoetigt.

### 8.4 App-Token und Teilnehmerkennung

Der Server erzeugt bei der Freischaltung ein zufaelliges UUID-v4-App-Token und gibt es an die App zurueck. Dieses Token wird danach nur lokal in der App gespeichert. Bei Selbstberichten sendet die App das Token erneut an `submit.php`. Der Server validiert das UUID-Format und berechnet daraus die pseudonyme Auswertungskennung:

```php
$participantId = hash('sha256', strtolower($appToken));
```

Der Hash normalisiert die UUID auf Kleinschreibung, damit dieselbe App-Installation unabhaengig von der Schreibweise dieselbe `participant_id` erhaelt. Der rohe App-Token wird nicht in `self_reports` gespeichert. Zur Rueckwaertskompatibilitaet aktualisiert `submit.php` beim naechsten Selbstbericht alte `self_reports`-Zeilen, deren `participant_id` noch dem rohen App-Token entspricht, auf den SHA-256-Hash.

### 8.5 Initiale Freischaltung per E-Mail-Adresse

Der allererste Request dient nur der Ausgabe des App-Tokens:

```json
{
  "email": "participant@example.org"
}
```

Serververhalten:

- Der Server prueft, ob die E-Mail-Adresse in `register` vorhanden und die Teilnahme freigegeben ist.
- Wenn die E-Mail-Adresse nicht vorhanden, nicht freigegeben oder bereits als tokenisiert markiert ist, wird kein App-Token ausgeliefert.
- Wenn die E-Mail-Adresse gueltig ist, erzeugt der Server ein neues `app_token` als UUID.
- Der Server gibt `app_token` an die App zurueck, persistiert aber weder das App-Token noch dessen Hash in Bezug zur E-Mail-Adresse.
- In `register` wird `app_token_issued_at` gesetzt, damit dieselbe Registrierung nicht erneut aktiviert werden kann.

### 8.6 Selbstbericht-Uebertragung

Die App sendet pro wissenschaftlicher Studiensituation einen `PUT`-Request an `submit.php`:

```json
{
  "app_token": "550e8400-e29b-41d4-a716-446655440000",
  "craving": 50,
  "app_version": "1.0"
}
```

Der Server berechnet aus dem App-Token die `participant_id`, zaehlt die bereits vorhandenen Selbstberichte fuer diese Kennung und bestimmt daraus `situation_index = submitted_count + 1`. Fuer die Situationen 1 bis 10 wird `condition_code = CUE_MATCHING` gesetzt, fuer die Situationen 11 bis 20 `condition_code = CUE_LABELING`. Die App uebertraegt weder Situation noch Bedingung.

`app_version` wird als optionales String-Feld akzeptiert und validiert, aber im derzeitigen Tabellenschema nicht gespeichert.

Bei Situation 20 erzeugt der Server einen UUID-v4-Abrechnungscode, speichert ihn in `compensation_code` und gibt ihn an die App zurueck. Die App bestaetigt diesen Code anschliessend mit einem separaten `PUT`; der Server setzt dabei `confirmed_at`.

## 9. Implementierungsdetails der Android-App

### 9.1 Projektgeruest und Endpunkt-Prototyp

- Eigenstaendiges Android-Projekt im Verzeichnis `cuelens`.
- Native Android-App in Kotlin mit einer `MainActivity` und Jetpack Compose.
- Nur die fuer den Studienbetrieb erforderlichen Berechtigungen, im Grundbetrieb insbesondere Internet.
- Hochformat, damit Bilddarstellung, Antwortoptionen und Slider kontrolliert bleiben.
- Android-Backup deaktiviert, damit lokale Fortschrittsdaten nicht in allgemeine Geraete- oder Cloud-Backups gelangen.
- Der Selbstbericht wird ganzzahlig im Bereich 0 bis 100 erfasst.
- Produktive Uebertragungen an `submit.php` erfolgen per `PUT`.
- Netzwerkanfragen laufen nicht auf dem UI-Thread.

### 9.2 Studien-MVP

Ein produktiver Durchgang besteht aus mehreren Reizaufgaben und einer anschliessenden Selbstbericht-Abfrage. In der Cue-Matching-Bedingung wird ein Zielbild mit zwei Bildoptionen kombiniert. In der Cue-Labeling-Bedingung wird ein Zielbild mit zwei Wortoptionen kombiniert. Nach jeder Auswahl wechselt die App zur naechsten Aufgabe. Nach Abschluss der Aufgaben erscheint die Abfrage mit Slider von 0 bis 100, Standardwert 50 und Button `Absenden`.

Cue-Bilder fuellen den sichtbaren Bildschirm durch eine Cover-Darstellung. Match-Bilder und Wortoptionen werden ueber dem Cue-Bild im unteren Bildschirmbereich dargestellt.

### 9.3 Ressourcen und Aufgabenlisten

- Cue-Matching-Items werden aus `cue_0nn`, `match_a_0nn` und `match_b_0nn` erzeugt.
- Ein Cue-Matching-Item ist nur gueltig, wenn alle drei Drawables vorhanden sind.
- Cue-Labeling-Items werden aus einem Cue-Bild und einem Labelpaar erzeugt.
- Labelpaare enthalten ein besser passendes und ein weniger passendes Label.
- Bild- und Wortoptionen werden innerhalb eines Items zufaellig links/rechts beziehungsweise in ihrer Reihenfolge vertauscht.

### 9.4 Studienfortschritt, Sperrzeit und Randomisierung

- Lokaler Fortschritt ist ein App-Cache. Autoritativ fuer die serverseitige Auswertung ist die Anzahl der in `self_reports` gespeicherten Selbstberichte pro `participant_id`.
- Die App speichert lokal den naechsten erlaubten Startzeitpunkt, die Anzahl bestaetigter Studiensituationen, die zufaellige Cue-Matching-Reihenfolge und das App-Token.
- Bei Netzwerkfehlern speichert die App den ausstehenden Craving-Wert, damit derselbe Selbstbericht erneut uebertragen werden kann.
- Zwischen zwei Studiensituationen liegt im Produktivbetrieb ein Mindestabstand von drei Stunden.
- Insgesamt sind 20 Studiensituationen vorgesehen: zehn Cue-Matching-Situationen und zehn Cue-Labeling-Situationen.
- Jede Studiensituation enthaelt fuenf Aufgaben.
- Production-Werte bleiben fachlich konsistent: vier Sekunden Betrachtungs-Countdown beim Cue-Matching und drei Stunden Sperrzeit.

### 9.5 Build-Varianten und Endpunkte

- `staging` verwendet lokale oder interne Test-Endpunkte.
- `production` verwendet `https://cuelens.each-and-every.de/submit`.
- Endpunkte werden ueber `BuildConfig` oder eine vergleichbare Build-Konfiguration bereitgestellt.
- Klartextverkehr ist nur als abgegrenzte Staging-Ausnahme zulaessig.

### 9.6 Architektur

- `MainActivity` initialisiert die Compose-App.
- Studienphasen werden explizit modelliert, zum Beispiel `StartGate`, `ImageMatching`, `WordMatching` und `SelfReport`.
- UI-Komponenten erhalten nur die fuer Darstellung und Rueckmeldung notwendigen Daten.
- Netzwerk-, Ressourcen- und Persistenzlogik sollen so gekapselt werden, dass sie spaeter in ViewModel-, Repository- oder Service-Klassen ausgelagert werden koennen.

### 9.7 Datenmodell

Mindestens erforderliche Datenklassen:

```kotlin
data class ImageMatchItem(
    @DrawableRes val cueResId: Int,
    @DrawableRes val matchAResId: Int,
    @DrawableRes val matchBResId: Int
)

data class WordMatchItem(
    @DrawableRes val cueResId: Int,
    val fittingLabel: String,
    val lessFittingLabel: String,
    val language: String = "de"
)

enum class StudyCondition { CUE_MATCHING, CUE_LABELING }
```

Fuer die auswertbare Studienfassung sollen stabile IDs fuer Cue, Optionen und Trials ergaenzt werden. Drawable-IDs sind keine dauerhaften wissenschaftlichen Kennungen. Diese IDs muessen nicht im regulaeren Submit-Payload enthalten sein, solange sie fuer den Server nicht zur Validierung oder Auswertung benoetigt werden.


## 10. Serverseitige Tabellen

### 10.1 Registrierung

Die bestehende Tabelle `register` enthaelt Teilnahmeinformationen ohne Bezug zu Craving-Werten und ohne Bezug zu App-Tokens.

```sql
CREATE TABLE `register` (
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `email` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `iban` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `bic` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `age` int NOT NULL,
  `cigarettes` int NOT NULL,
  `studyinfo` tinyint(1) DEFAULT '0',
  `dataprot` tinyint(1) DEFAULT '0',
  `doi_token` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `doi` tinyint(1) NOT NULL DEFAULT '0',
  `app_token_issued_at` TIMESTAMP DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
```

### 10.2 Selbstberichte

```sql
CREATE TABLE self_reports (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    participant_id CHAR(64) NOT NULL,
    condition_code ENUM('CUE_MATCHING', 'CUE_LABELING') NOT NULL,
    craving TINYINT NOT NULL,
    CHECK(craving BETWEEN 0 AND 100)
);
```

`self_reports` ist die pseudonymisierte Auswertungstabelle. `participant_id` ist der SHA-256-Hash des normalisierten App-Tokens und nicht der rohe Token. Die Tabelle enthaelt keine Kontakt- oder Zahlungsdaten, erlaubt aber die Zusammenfuehrung mehrerer Selbstberichte derselben App-Installation. Sie darf deshalb nicht als anonymisierte Datensammlung beschrieben werden.

### 10.3 Abrechnungscodes

```sql
CREATE TABLE compensation_code (
    compensation_code CHAR(36) NOT NULL PRIMARY KEY,
    confirmed_at TIMESTAMP NULL
);
```

### 10.4 Serverlogik fuer `activate.php` und `submit.php`

1. **Freischaltungsrequest mit E-Mail-Adresse**
   - Voraussetzung: E-Mail-Adresse existiert in `register`, Teilnahme ist freigegeben, `app_token_issued_at` ist noch leer.
   - Server erzeugt ein UUID-App-Token.
   - Server gibt das App-Token zurueck, speichert das App-Token aber nicht.
   - Server setzt `app_token_issued_at`, damit dieselbe Registrierung nicht mehrfach aktiviert werden kann.

2. **Selbstbericht mit App-Token**
   - Voraussetzung: Der Request enthaelt ein formal gueltiges UUID-App-Token und einen ganzzahligen Craving-Wert von 0 bis 100.
   - Server berechnet `participant_id = hash('sha256', strtolower($appToken))`.
   - Server aktualisiert alte `self_reports`-Zeilen, deren `participant_id` noch dem rohen App-Token entspricht, auf den neuen Hash.
   - Server zaehlt die vorhandenen Selbstberichte fuer `participant_id` unter Transaktionsschutz.
   - Wenn bereits 20 Selbstberichte vorhanden sind, wird der Request mit HTTP 400 abgelehnt.
   - Andernfalls wird `situation_index = submitted_count + 1` berechnet.
   - Fuer `situation_index <= 10` wird `condition_code = CUE_MATCHING` gespeichert, danach `condition_code = CUE_LABELING`.
   - Server speichert `participant_id`, `condition_code` und `craving` in `self_reports`.

3. **Abschlussfall**
   - Bei Situation 20 erzeugt der Server einen UUID-Abrechnungscode.
   - Der Code wird in `compensation_code` gespeichert und in der Antwort an die App zurueckgegeben.
   - Die App bestaetigt den Code in einem separaten `PUT`.
   - Der Server setzt `confirmed_at = CURRENT_TIMESTAMP`, falls der Code existiert, und antwortet mit HTTP 204.

4. **Ungueltige Requests**
   - Fehlende App-Tokens, falsch formatierte UUIDs, fehlende oder ungueltige Craving-Werte und nicht unterstuetzte Payloads resultieren in HTTP 400 `Bad Request`.
   - Unsupported HTTP-Methoden resultieren in HTTP 405.
   - Dabei wird kein neuer Selbstbericht gespeichert.

## 11. App-Retry-Logik

- Vor dem Selbstbericht-PUT legt die App lokal den ausstehenden Craving-Wert ab.
- Wenn vor der Serverantwort ein Fehler auftritt, wird derselbe Selbstbericht erneut uebertragen.
- Nach erfolgreicher Serverantwort entfernt die App den ausstehenden Craving-Wert, erhoeht lokal die Anzahl bestaetigter Situationen und setzt die naechste Sperrzeit.
- Wenn die Antwort den Abschlussstatus enthaelt, speichert die App den Abrechnungscode lokal und bestaetigt ihn mit einem separaten `PUT`.
- Wenn die Bestaetigung des Abrechnungscodes fehlschlaegt, wiederholt die App nur diese Bestaetigung.
- Nach erfolgreicher Bestaetigung des Abrechnungscodes markiert die App die Studie lokal als abgeschlossen.
- Die App startet beim naechsten App-Start und vor einer neuen Studiensituation ausstehende Wiederholungen.

Die Selbstbericht-Uebertragung ist im derzeitigen Backend nicht vollstaendig idempotent. Wenn der Server einen Selbstbericht erfolgreich speichert, die Antwort aber vor dem Erreichen der App verloren geht, kann ein erneuter PUT als naechste Studiensituation gespeichert werden. Diese Vereinfachung ist eine bewusste Folge des Verzichts auf Hash-Chain und Drei-Wege-Bestaetigung und muss bei Test, Monitoring und Interpretation beruecksichtigt werden.

## 12. Mehrsprachigkeit Deutsch/Englisch

- Sichtbare UI-Texte aus Kotlin in Android-Stringressourcen verschieben.
- Mindestens `values/strings.xml` und `values-en/strings.xml` pflegen.
- Labelpaare erhalten Sprachzuordnung oder getrennte Ressourcen.
- Studienbegriffe bleiben zwischen App, Studieninformation und Datenschutzerklaerung konsistent.

## 13. Tests

Vor produktiver Nutzung sind mindestens zu testen:

- Freischaltungsrequest nur fuer in `register` vorhandene und freigegebene E-Mail-Adressen.
- Keine dauerhafte Speicherung des App-Tokens auf dem Server.
- Freischaltung setzt `app_token_issued_at` und gibt ein UUID-v4-App-Token zurueck.
- Ableitung von `participant_id` als SHA-256-Hash des normalisierten App-Tokens.
- Migration alter `self_reports`-Zeilen vom rohen App-Token auf den App-Token-Hash.
- Studiensequenz ueber 20 Situationen.
- Vollstaendigkeit der Bild- und Labelressourcen.
- Slider-Grenzen 0 bis 100.
- Selbstbericht mit gueltigem App-Token und Craving-Wert.
- Retry-Verhalten bei Netzwerkfehlern, einschliesslich des Risikos doppelter Speicherung nach verlorener Serverantwort.
- Speicherung in `self_reports` ohne rohes App-Token.
- Ableitung von Situation und Bedingung aus der Anzahl gespeicherter Selbstberichte.
- Kein weiterer Selbstbericht nach 20 gespeicherten Selbstberichten.
- Ausgabe eines Abrechnungscodes bei Situation 20.
- Bestaetigung des Abrechnungscodes mit HTTP 204.
- HTTP 400 fuer ungueltige Selbstbericht-PUTs.

## 14. Definition of Done

Eine Aenderung gilt nur dann als abgeschlossen, wenn alle zutreffenden Punkte erfuellt sind:

- Die App baut in Staging und Production.
- Die Studienlogik wurde nicht unbeabsichtigt veraendert.
- Neue Datenfelder sind im Code, Backend-Vertrag und in der Dokumentation beschrieben.
- Neue lokale Speicherungen sind nach Zweck, Lebensdauer und Schutzbedarf dokumentiert.
- Fehlerfaelle fuehren zu einem eindeutigen UI-Zustand.
- Tests oder manuelle Acceptance Checks decken den Kernpfad ab.
- `self_reports.participant_id` enthaelt den App-Token-Hash, nicht den rohen App-Token.
- Die Datenbank enthaelt keine dauerhafte Relation zwischen Registrierung, App-Token und Berichtstabelle.
