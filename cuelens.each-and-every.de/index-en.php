<?php
declare(strict_types=1);

$registrationPage = [
    'language' => 'en',
    'page_title' => 'Registration',
    'heading' => 'CueLens Study Registration',
    'introduction' => 'Thank you for your interest in participating. Please read the',
    'study_information_url' => '/studyinformation.pdf',
    'study_information_label' => 'study information',
    'details_intro' => 'Please provide the following information. Prolific participants provide only their Prolific ID, eligibility information, and consent.',
    'identifier_label' => 'Email address or Prolific ID',
    'identifier_help' => 'Prolific participants enter their 24-character Prolific ID instead of a personal email address.',
    'identifier_required' => 'Please enter your email address or Prolific ID.',
    'identifier_invalid' => 'Enter a valid email address or a 24-character Prolific ID.',
    'name_label' => 'Name',
    'name_required' => 'Please enter your name.',
    'iban_required' => 'Please enter your IBAN.',
    'bic_required' => 'Please enter your BIC.',
    'age_label' => 'Age',
    'age_required' => 'Please enter your age.',
    'age_range' => 'Participation is only possible between the ages of 30 and 65.',
    'integer_required' => 'Please enter a whole number.',
    'cigarettes_label' => 'Cigarettes/day',
    'cigarettes_required' => 'Please enter the number of cigarettes you smoke per day.',
    'cigarettes_range' => 'Participation is only possible if you smoke at least 10 cigarettes per day.',
    'studyinfo_required' => 'Please confirm that you have read the study information.',
    'studyinfo_prefix' => 'I have read the',
    'studyinfo_suffix' => '',
    'dataprot_required' => 'Please confirm that you accept the privacy policy.',
    'dataprot_prefix' => 'I accept the',
    'privacy_url' => '/privacypolicy.pdf',
    'privacy_label' => 'privacy policy',
    'submit_label' => 'Submit',
    'csrf_error' => 'The request could not be processed. Please reload the form.',
    'validation_error' => 'Please use the web form.',
    'duplicate_direct' => 'This email address is already registered.',
    'duplicate_prolific' => 'This Prolific ID is already registered.',
    'prolific_not_registered' => 'This Prolific ID is not registered for the CueLens study.',
    'prolific_check_error' => 'The Prolific ID could not be checked temporarily. Please try again later.',
    'save_error' => 'An error occurred while saving.',
    'mail_error' => 'The confirmation email could not be sent.',
    'confirm_path' => 'confirm-en.php',
    'double_opt_in_path' => 'double-en.php',
    'prolific_success_path' => 'registered-en.php',
    'mail_subject' => 'Please confirm your registration for the CueLens study',
    'mail_body' => static fn (string $url): string =>
        "Hello,\n\n"
        . "Thank you for your interest in the CueLens study.\n\n"
        . "Please confirm your email address by clicking the following link:\n\n"
        . $url . "\n\n"
        . "If you did not register for the CueLens study, you can ignore this email.\n\n"
        . 'Kind regards',
];

require __DIR__ . '/lib/registration-page.php';
