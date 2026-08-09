<?php
declare(strict_types=1);

use PHPUnit\Framework\TestCase;

require_once dirname(__DIR__) . '/lib/registration.php';

final class RegistrationValidationTest extends TestCase
{
    public function testDirectRegistrationKeepsExistingRequiredFieldsAndValues(): void
    {
        $result = validate_registration_submission($this->validDirectPost());

        self::assertTrue($result->isValid());
        self::assertSame([], $result->errors());
        $submission = $result->submission();
        self::assertSame(ParticipantIdentifier::DIRECT, $submission->identifier()->channel());
        self::assertSame('Participant@Example.ORG', $submission->identifier()->value());
        self::assertSame('Test Person', $submission->name());
        self::assertSame('DE89370400440532013000', $submission->iban());
        self::assertSame('COBADEFFXXX', $submission->bic());
    }

    public function testProlificRegistrationDoesNotRequirePersonalFields(): void
    {
        $post = $this->validDirectPost();
        $post['participant_identifier'] = 'AbCdEf1234567890GhIjKlMn';
        unset($post['name'], $post['iban'], $post['bic']);

        $result = validate_registration_submission($post);

        self::assertTrue($result->isValid());
        $submission = $result->submission();
        self::assertSame(ParticipantIdentifier::PROLIFIC, $submission->identifier()->channel());
        self::assertNull($submission->name());
        self::assertNull($submission->iban());
        self::assertNull($submission->bic());
    }

    public function testProlificRegistrationClearsManipulatedPersonalFields(): void
    {
        $post = $this->validDirectPost();
        $post['participant_identifier'] = 'AbCdEf1234567890GhIjKlMn';
        $post['email'] = '';

        $result = validate_registration_submission($post);

        self::assertTrue($result->isValid());
        $submission = $result->submission();
        self::assertNull($submission->identifier()->email());
        self::assertNull($submission->name());
        self::assertNull($submission->iban());
        self::assertNull($submission->bic());
    }

    public function testInvalidIdentifierCannotBypassDirectRequiredFields(): void
    {
        $post = $this->validDirectPost();
        $post['participant_identifier'] = 'not-an-email';
        unset($post['name'], $post['iban'], $post['bic']);

        $result = validate_registration_submission($post);

        self::assertFalse($result->isValid());
        self::assertContains('identifier', $result->errors());
        self::assertContains('name', $result->errors());
        self::assertContains('iban', $result->errors());
        self::assertContains('bic', $result->errors());
    }

    public function testDirectModeRequiresEveryExistingEligibilityAndConsentField(): void
    {
        foreach (['name', 'iban', 'bic', 'age', 'cigarettes', 'studyinfo', 'dataprot'] as $field) {
            $post = $this->validDirectPost();
            unset($post[$field]);

            $result = validate_registration_submission($post);

            self::assertFalse($result->isValid(), 'Missing field must fail: ' . $field);
            self::assertContains($field, $result->errors());
        }
    }

    public function testEligibilityRangesRemainUnchanged(): void
    {
        foreach ([['age', '29'], ['age', '66'], ['age', '30.5'], ['cigarettes', '9'], ['cigarettes', '10.5']] as [$field, $value]) {
            $post = $this->validDirectPost();
            $post[$field] = $value;

            $result = validate_registration_submission($post);

            self::assertFalse($result->isValid(), $field . '=' . $value . ' must fail.');
            self::assertContains($field, $result->errors());
        }
    }

    public function testLegacyEmailPostFieldRemainsSupported(): void
    {
        $post = $this->validDirectPost();
        unset($post['participant_identifier']);
        $post['email'] = 'participant@example.org';

        $result = validate_registration_submission($post);

        self::assertTrue($result->isValid());
        self::assertSame('participant@example.org', $result->submission()->identifier()->email());
    }

    public function testConflictingIdentifierFieldsAreRejected(): void
    {
        $post = $this->validDirectPost();
        $post['email'] = 'other@example.org';

        $result = validate_registration_submission($post);

        self::assertFalse($result->isValid());
        self::assertContains('identifier', $result->errors());
    }

    /** @return array<string, string> */
    private function validDirectPost(): array
    {
        return [
            'participant_identifier' => ' Participant@Example.ORG ',
            'name' => ' Test Person ',
            'iban' => ' DE89370400440532013000 ',
            'bic' => ' COBADEFFXXX ',
            'age' => '30',
            'cigarettes' => '10',
            'studyinfo' => 'on',
            'dataprot' => 'on',
        ];
    }
}
