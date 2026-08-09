<?php
declare(strict_types=1);

$registrationPage = [
    'language' => 'de',
    'page_title' => 'Anmeldung',
    'heading' => 'Anmeldung zur CueLens-Studie',
    'introduction' => 'Vielen Dank für Ihr Interesse an der Teilnahme. Bitte lesen Sie die',
    'study_information_url' => '/info',
    'study_information_label' => 'Studieninformation',
    'details_intro' => 'Wir benötigen die folgenden Angaben. Prolific-Teilnehmende geben nur ihre Prolific-ID sowie die Angaben zur Teilnahmeberechtigung und Einwilligung ein.',
    'identifier_label' => 'E-Mail-Adresse oder Prolific-ID',
    'identifier_help' => 'Prolific-Teilnehmende geben hier ihre 24-stellige Prolific-ID anstelle einer persönlichen E-Mail-Adresse ein.',
    'prolific_mode_help' => 'Prolific-Modus: Name und Bankdaten werden nicht erhoben; die Vergütung erfolgt über Prolific.',
    'identifier_required' => 'Bitte geben Sie Ihre E-Mail-Adresse oder Prolific-ID ein.',
    'identifier_invalid' => 'Bitte geben Sie eine gültige E-Mail-Adresse oder eine 24-stellige Prolific-ID ein.',
    'name_label' => 'Name',
    'name_required' => 'Bitte geben Sie Ihren Namen ein.',
    'iban_required' => 'Bitte geben Sie Ihre IBAN ein.',
    'bic_required' => 'Bitte geben Sie Ihre BIC ein.',
    'age_label' => 'Alter',
    'age_required' => 'Bitte geben Sie Ihr Alter ein.',
    'age_range' => 'Eine Teilnahme ist nur im Alter von 30 bis 65 Jahren möglich.',
    'integer_required' => 'Bitte geben Sie eine ganze Zahl ein.',
    'cigarettes_label' => 'Zigaretten/Tag',
    'cigarettes_required' => 'Bitte geben Sie die Anzahl der Zigaretten pro Tag ein.',
    'cigarettes_range' => 'Eine Teilnahme ist nur bei mindestens 10 Zigaretten pro Tag möglich.',
    'studyinfo_required' => 'Bitte bestätigen Sie, dass Sie die Studieninformation gelesen haben.',
    'studyinfo_prefix' => 'Ich habe die',
    'studyinfo_suffix' => 'gelesen',
    'dataprot_required' => 'Bitte bestätigen Sie, dass Sie die Datenschutzerklärung akzeptieren.',
    'dataprot_prefix' => 'Ich akzeptiere die',
    'privacy_url' => '/ds',
    'privacy_label' => 'Datenschutzerklärung',
    'submit_label' => 'Absenden',
    'csrf_error' => 'Die Anfrage konnte nicht verarbeitet werden. Bitte laden Sie das Formular neu.',
    'validation_error' => 'Bitte nutzen Sie das Webformular.',
    'duplicate_direct' => 'Diese E-Mail-Adresse ist bereits registriert.',
    'duplicate_prolific' => 'Diese Prolific-ID ist bereits registriert.',
    'save_error' => 'Beim Speichern ist ein Fehler aufgetreten.',
    'mail_error' => 'Die Bestätigungs-E-Mail konnte nicht versendet werden.',
    'confirm_path' => 'confirm-de.php',
    'double_opt_in_path' => 'double-de.php',
    'prolific_success_path' => 'registered-de.php',
    'mail_subject' => 'Bitte bestätigen Sie Ihre Anmeldung zur CueLens-Studie',
    'mail_body' => static fn (string $url): string =>
        "Guten Tag,\n\n"
        . "vielen Dank für Ihr Interesse an der CueLens-Studie.\n\n"
        . "Bitte bestätigen Sie Ihre E-Mail-Adresse über den folgenden Link:\n\n"
        . $url . "\n\n"
        . "Falls Sie sich nicht zur CueLens-Studie angemeldet haben, können Sie diese E-Mail ignorieren.\n\n"
        . 'Mit freundlichen Grüßen',
];

require __DIR__ . '/lib/registration-page.php';
