# Datenbankmigrationen

Die Migrationen werden in numerischer Reihenfolge und vor dem zugehörigen
PHP-Deployment ausgeführt. `001` und `003` betreffen die administrative
Registrierungsdatenbank, `002` und `004` die Forschungsdatenbank. Vor jeder
Produktionsmigration ist ein Backup erforderlich.

Nach `003_app_review_account_up.sql` wird genau eine bestätigte direkte
Testregistrierung markiert. Die Kennung wird nur zur Laufzeit übergeben und
nicht in Repository, Logs oder Shell-Skripten abgelegt:

```sh
CUELENS_APP_REVIEW_EMAIL='<geschützt bereitgestellte Reviewkennung>' \
  php scripts/mark-app-review-account.php
```

Die Operation ist idempotent und verweigert die Änderung, wenn die Kennung
nicht genau eine geeignete Registrierung bezeichnet oder bereits ein anderes
Reviewkonto markiert ist. Das Datenbankschema erzwingt zusätzlich höchstens ein
markiertes Konto und beschränkt es auf den direkten Registrierungskanal.

`004_test_data_markers_up.sql` kennzeichnet die Allowlist, Selbstberichte und
Kompensationscodes aus Reviewaktivierungen mit `is_test = TRUE`. Alle
wissenschaftlichen Exporte und statistischen Auswertungen müssen deshalb
`self_reports.is_test = FALSE` filtern. Auszahlungs- und
Kompensationscode-Arbeitslisten müssen entsprechend
`compensation_code.is_test = FALSE` filtern. Die Vorgabe gilt auch für ad-hoc
SQL-Abfragen; eine bloße nachträgliche Bereinigung ist nicht ausreichend.
