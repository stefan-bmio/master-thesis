# CueLens iOS – Datenschutz- und App-Store-Datenflussmatrix

Stand: 24.08.2026. Diese Matrix beschreibt ausschließlich Daten, die durch die iOS-App entstehen oder von ihr übertragen werden. Angaben aus dem vorgelagerten Webformular, die nie durch die App verarbeitet werden (insbesondere Name, Bankverbindung, Alter und Zigarettenanzahl), gehören nicht zum App-Manifest.

| Datenelement | App-Quelle und Lebenszyklus | Übertragung und serverseitiger Zweck | Apple-Kategorie | Verknüpft | Tracking |
|---|---|---|---|---|---|
| E-Mail-Adresse | Aktivierungseingabe; nur flüchtig bis Erfolg oder Fehler | Aktivierungsendpunkt; Abgleich mit administrativer Registrierung und Freigabe | Email Address | ja | nein |
| Prolific-ID | Aktivierungseingabe; nur flüchtig bis Erfolg oder Fehler | Aktivierungsendpunkt; Abgleich mit administrativer Registrierung und manueller Vergütung | User ID | ja | nein |
| App-Token | UUID-v4 im Keychain, `WhenUnlockedThisDeviceOnly`, nicht synchronisierbar | Aktivierungsbestätigung und Selbstbericht; serverseitig nur domänenseparierte Hashableitungen | User ID | ja | nein |
| Rauchverlangen | Pending geschützt bis bestätigte Übertragung | Selbstbericht; pseudonymisierte wissenschaftliche Auswertung | Health | ja, über pseudonyme Kennung | nein |
| Feedbackquelle und -kommentar | flüchtig bis erfolgreicher Versand; keine Warteschlange | getrennte Feedbacktabelle, ohne Token oder Teilnehmerkennung | Other User Content | nein, sofern keine entgegen dem Hinweis eingegebenen Identifikatoren enthalten sind | nein |
| App-Version | Buildmetadatum | Feedback und Selbstbericht; Kompatibilität und technische Einordnung | keine eigenständige personenbezogene Kategorie | nein | nein |

## Nicht erhobene beziehungsweise nicht übertragene Daten

- Matching- und Labeling-Auswahlen, Reaktionszeiten und konkrete Randomisierungsfolge;
- Demoauswahl und Demo-Craving;
- Sprache, Zeitzone, Systemzeit, Gerätetyp, OS-Version, Geräte-ID und Push-Token;
- Standort, Kamera, Fotos, Mikrofon, Kontakte, Kalender und Bluetooth;
- Werbe-, Tracking-, Analytics-, Crash- oder Performance-Daten;
- Nachrichtentexte und lokale Notification-Inhalte;
- Kompensationscode außerhalb des bestehenden Bestätigungsrequests.

Technisch unvermeidbare Transportmetadaten wie IP-Adresse oder Standard-HTTP-Header dürfen weder Forschungsvariable noch App-Trackingmerkmal werden. Ihre tatsächliche serverseitige Aufbewahrung ist vor App-Store-Einreichung gegen Hosting- und Webserverkonfiguration zu prüfen.

## Apple-Deklaration

`PrivacyInfo.xcprivacy` deklariert konservativ Email Address, User ID, Health und Other User Content. Sämtliche Typen sind `Tracking = false`. Auf eine optionale Health-Research-Ausnahme wird ohne im Repository nachgewiesenes Ethikvotum bewusst nicht zurückgegriffen. App Store Connect muss dieselben Kategorien und Zwecke abbilden und darf nicht „keine Daten erhoben“ angeben.

Offizielle Referenzen, geprüft am 24.08.2026:

- <https://developer.apple.com/documentation/bundleresources/describing-data-use-in-privacy-manifests>
- <https://developer.apple.com/app-store/app-privacy-details/>
- <https://developer.apple.com/app-store/review/guidelines/>

## Freigabe

Die technische Matrix ist Teil von Auftrag 11. Die rechtliche und studienethische Vier-Augen-Prüfung sowie die Übertragung der Angaben nach App Store Connect bleiben dessen menschliches Review-Gate.
