# CueLens: Implementierungsanweisungen fuer Codex

Diese Datei beschreibt den geplanten technischen Stand der ersten Play-Store-Version der Android-App im Verzeichnis `cuelens` und des zugehoerigen PHP-Backends. Sie dient zugleich als Vorlage fuer die spaetere technische Dokumentation.

Die erste Play-Store-Version ist eine Pre-Study-App. Sie soll die spaetere Aktivierung der Studie vorbereiten, aber noch keine produktive Studiensituation fuer die wissenschaftliche Auswertung freigeben. Sichtbar sind nur Funktionen, die keine serverseitige Feature-Aktivierung benoetigen oder diese Aktivierung erst ermoeglichen.

## 0. Zielbild fuer Branch `pre_study_app`

In diesem Branch soll die erste App-Version entstehen, die ueber den Play Store bereitgestellt werden kann. Ziel ist eine robuste, datensparsame und testbare Basisversion mit folgenden initial sichtbaren Funktionen:

1. Infofeed mit serverseitig gepflegten Nachrichten.
2. Nach eventuellen Info-Nachrichten Startseite oder vorherige Seite.
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
- Behandle Netzwerkfehler als zentrale Robustheitsanforderung. Die App muss ausstehende Selbstberichte erneut senden koennen und einen erhaltenen Abrechnungscode bis zur Bestaetigung lokal zwischenspeichern.
- Uebertrage keine Felder, die serverseitig deterministisch ableitbar sind. Der Server leitet den Studienfortschritt aus der Anzahl bereits gespeicherter Selbstberichte fuer die pseudonyme Kennung ab.
- Speichere in `self_reports` nicht das App-Token selbst, sondern nur den daraus abgeleiteten SHA-256-Hash als `participant_id`.
- Nutze Android- und Play-Store-Mechanismen, wenn sie den Zweck bereits sicher und wartbar abdecken, zum Beispiel Android-Stringressourcen fuer Internationalisierung und Play-Store-Updatefunktionen fuer Updates.
- Kein eigener Mechanismus zum Nachladen oder Ausfuehren von App-Code. Fehlerbehebungen am nativen App-Code werden ueber den regulaeren Android-/Play-Store-Updatekanal ausgeliefert.

## 2. Initial sichtbare App-Funktionen

### 2.1 App-Start und Navigationsfluss

Beim Start gilt folgende Reihenfolge:

1. App initialisiert Sprache, lokale Einstellungen und Netzwerk-Clients.
2. App ruft den Infofeed ab, sofern Netzwerk verfuegbar ist.
3. App zeigt noch nicht ausgeblendete Info-Nachrichten als Vollbild-Nachrichtenseiten an.
4. Danach zeigt die App die Startseite.

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
- Nachrichten in Deutsch und Englisch
- Keine personenbezogenen Daten in der Nachrichtentabelle speichern.
- Bei Datenbankfehlern HTTP 500 mit generischer Fehlermeldung liefern, ohne interne Details auszugeben.

#### App-Funktion

Die App zeigt jede nicht ausgeblendete Nachricht als Vollbildseite an. Die Seite enthaelt:

- Nachrichtentext.
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

Benachrichtigungen sind in der ersten Version nur fuer Info-Nachrichten vorgesehen und nur dann aktiv, wenn die Nutzerin oder der Nutzer sie zulaesst.

Anforderungen:

- Unter Android 13 und hoeher die Runtime Permission `POST_NOTIFICATIONS` erst kontextbezogen anfragen.
- Keine Benachrichtigungspflicht: Bei Ablehnung funktionieren Infofeed, Startseite, Aktivierung, Beispiel und Feedback weiterhin.
- Inhalt neutral halten, zum Beispiel `Neue Information zu CueLens verfuegbar`.
- Beim Tippen auf die Benachrichtigung die App oeffnen und den Infofeed neu abrufen.
- Per Android WorkManager wird periodisch auf neue Nachrichten geprueft.

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
2. Mehrzeiliges Freitextfeld: `Was gefällt Ihnen an der Studie, wobei gab es eventuell Probleme?`
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

## 4. Serverseitige Tabellen und Endpunkte

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
    id BIGINT NOT NULL PRIMARY KEY,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    text TEXT NOT NULL
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
```

Endpoint:

- `POST /feedback.php`
- Speichert `source`, `comment`, optional `app_version` und optional `language`.
- Keine Speicherung in `self_reports`.
- Keine Verknuepfung mit Registrierung oder App-Token.

### 4.4 Selbstberichte fuer spaetere Studienversion

Die Tabelle `self_reports` und die produktive Selbstbericht-Uebertragung bleiben fuer diese erste Play-Store-Version deaktiviert. Wenn der Code bereits vorhanden ist, darf er in Production nicht durch die UI erreichbar sein.

Fuer spaetere Studienversionen bleibt das Ziel bestehen:

- `participant_id` ist der SHA-256-Hash des lokal gespeicherten App-Tokens und nicht der rohe Token.
- `self_reports` enthaelt keine E-Mail-Adresse, keinen Namen und keine Zahlungsdaten.
- Die produktive Craving-Uebertragung wird erst durch eine spaetere Feature-Aktivierung und eine geeignete App-Version freigegeben.

## 5. Android-Architektur

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

## 6. Tests

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

## 7. Definition of Done

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
- Neue Datenfelder sind im Code, Backend-Vertrag und in der Dokumentation beschrieben.
- Neue lokale Speicherungen sind nach Zweck, Lebensdauer und Schutzbedarf dokumentiert.
- Fehlerfaelle fuehren zu einem eindeutigen UI-Zustand.
- Tests decken die Kernpfade und Entscheidungszweige der neuen Funktionen moeglichst vollstaendig ab.
- Die Datenbank enthaelt keine dauerhafte Relation zwischen Registrierung, App-Token, Feedback und spaeterer Berichtstabelle.
