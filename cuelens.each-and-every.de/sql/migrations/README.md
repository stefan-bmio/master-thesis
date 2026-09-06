# Datenbankmigrationen

Die Migrationen werden in numerischer Reihenfolge und vor dem zugehörigen
PHP-Deployment ausgeführt. `001` und `003` betreffen die administrative
Registrierungsdatenbank, `002` und `004` die Forschungsdatenbank. Vor jeder
Produktionsmigration ist ein Backup erforderlich.

Nach `003_app_review_account_up.sql` wird die zuvor regulär registrierte und
bestätigte Reviewregistrierung manuell in der administrativen Datenbank
markiert:

```sql
UPDATE register
   SET app_review_account = TRUE
 WHERE email = '<geschützt bereitgestellte Reviewkennung>';
```

Die konkrete Kennung darf nicht im Repository, in Konfigurationsdateien oder
in Protokollen abgelegt werden. Auswahl und Kontrolle des betroffenen
Datensatzes erfolgen im manuellen administrativen Ablauf.

`004_test_data_markers_up.sql` kennzeichnet die Allowlist, Selbstberichte und
Kompensationscodes aus Reviewaktivierungen mit `is_test = TRUE`. Alle
wissenschaftlichen Exporte und statistischen Auswertungen müssen deshalb
`self_reports.is_test = FALSE` filtern. Auszahlungs- und
Kompensationscode-Arbeitslisten müssen entsprechend
`compensation_code.is_test = FALSE` filtern. Die Vorgabe gilt auch für ad-hoc
SQL-Abfragen; eine bloße nachträgliche Bereinigung ist nicht ausreichend.
