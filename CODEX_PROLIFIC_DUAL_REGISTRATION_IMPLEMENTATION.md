# CueLens: Dual Registration and Manual Prolific Completion

## Implementation instructions for Codex

**Target repository:** `stefan-bmio/master-thesis`  
**Affected applications:**

- Web registration and PHP backend: `cuelens.each-and-every.de/`
- Android app: `cuelens/`

**Primary goal:** Add a privacy-preserving Prolific registration path without removing, weakening, or changing the externally observable behavior of the existing direct registration path.

---

## 1. Mandatory implementation principles

### 1.1 Preserve the current direct-participant workflow

The existing workflow for participants recruited outside Prolific is production functionality and must remain available:

1. The participant registers with a personal email address, name, IBAN, and BIC.
2. The existing inclusion data and consent fields are completed.
3. The existing email double-opt-in process is performed.
4. The participant activates the Android app with the same email address.
5. The current three-step activation handshake issues and confirms the app token.
6. After the twentieth valid study situation, the server returns the current compensation code.
7. The Android app confirms the compensation code and displays it to the participant.
8. Payment outside Prolific remains possible using the existing administrative data.

Do not remove this path. Do not make personal email, name, IBAN, or BIC optional for direct participants. Do not change the existing compensation-code response or confirmation protocol for direct participants.

### 1.2 Add Prolific as a second path, not as a replacement

A Prolific participant shall:

1. Enter a Prolific participant ID in the existing identifier field on the registration website.
2. Not enter or submit a personal email address or bank-account details.
3. Enter the same Prolific participant ID in the Android activation screen instead of an email address.
4. Complete the same study tasks and submit the same study measurements as every other participant.
5. Receive no CueLens compensation code.
6. See this exact German completion text in the app:

   > Studie abgeschlossen. Der Abschluss bei Prolific erfolgt üblicherweise innerhalb 2 Tagen.

7. Be paid manually in Prolific by the study operator. Do not implement a Prolific payment API, automatic bonus payment, submission approval, or API token handling.

### 1.3 Test-first requirement

Before changing production code for each affected component:

1. Add or extend automated tests in the existing test framework.
2. Run the focused tests and confirm that the new tests fail for the expected missing behavior.
3. Only then change production code.
4. Run the focused tests again until they pass.
5. Run the complete relevant test suites and preserve all existing tests.

Do not weaken, delete, skip, or rewrite an existing regression test merely to make the implementation pass. Changes to an existing assertion are allowed only when the requirement intentionally changes that exact behavior, and the unchanged direct-participant behavior must still have an explicit regression test.

### 1.4 Data-separation invariant

Treat a Prolific ID as pseudonymous personal data. Its separation from research data must be at least as strong as the existing separation of email addresses from research data.

The following data may exist only in the administrative registration database:

- personal email address;
- participant name;
- IBAN and BIC;
- Prolific participant ID;
- registration channel;
- manual-payment status;
- administrative completion timestamp.

The following must not be written to the craving/research database, self-report rows, operational error logs, HTTP client-error logs, or operational email notifications:

- personal email address;
- participant name;
- IBAN or BIC;
- Prolific participant ID;
- a plain or deterministically hashed Prolific participant ID.

The research database may contain only the existing app-token-derived values and a non-identifying completion mode such as `COMPENSATION_CODE` or `PROLIFIC_MANUAL`.

---

## 2. Existing code that must be treated as regression-sensitive

Inspect the current branch before editing, but expect at least the following relevant files.

### 2.1 Website and registration

- `cuelens.each-and-every.de/index-de.php`
- `cuelens.each-and-every.de/index-en.php`
- `cuelens.each-and-every.de/index.js`
- `cuelens.each-and-every.de/confirm-de.php`
- `cuelens.each-and-every.de/confirm-en.php`
- `cuelens.each-and-every.de/tests/FormValidationBrowserTest.php`

At the time of this specification, the two registration pages:

- validate the field named `email` only as an email address;
- require `name`, `iban`, and `bic`;
- insert these values into `register`;
- send a double-opt-in email;
- use the email address as the administrative registration key.

### 2.2 Activation backend

- `cuelens.each-and-every.de/activate.php`
- `cuelens.each-and-every.de/lib/activation.php`
- `cuelens.each-and-every.de/lib/token-identity.php`
- `cuelens.each-and-every.de/tests/ActivationTest.php`
- `cuelens.each-and-every.de/tests/ActivationEndpointTest.php`
- `cuelens.each-and-every.de/tests/ActivationMariaDbIntegrationTest.php`

The current endpoint accepts an `email` JSON property. Existing released Android versions may continue to send that property. Backward compatibility is mandatory.

### 2.3 Study completion backend

- `cuelens.each-and-every.de/submit.php`
- `cuelens.each-and-every.de/lib/operational-notification.php`
- `cuelens.each-and-every.de/lib/error-log.php`
- `cuelens.each-and-every.de/tests/OperationalNotificationTest.php`

At the time of this specification, the twentieth self-report causes `submit.php` to create and return a UUID compensation code. Keep that exact behavior for direct registrations.

### 2.4 Android activation and completion UI

- `cuelens/app/src/main/java/de/eachandevery/cuelens/prestudy/ActivationService.kt`
- `cuelens/app/src/main/java/de/eachandevery/cuelens/prestudy/PreStudyController.kt`
- `cuelens/app/src/main/java/de/eachandevery/cuelens/prestudy/PreStudyApp.kt`
- `cuelens/app/src/main/java/de/eachandevery/cuelens/prestudy/StudyProgressStore.kt`
- `cuelens/app/src/main/java/de/eachandevery/cuelens/MainActivity.kt`
- `cuelens/app/src/main/java/de/eachandevery/cuelens/infofeed/InfoMessageScreen.kt`
- `cuelens/app/src/main/res/values/strings.xml`
- `cuelens/app/src/main/res/values-en/strings.xml`
- `cuelens/app/src/test/java/de/eachandevery/cuelens/prestudy/HttpActivationServiceTest.kt`
- `cuelens/app/src/test/java/de/eachandevery/cuelens/prestudy/PreStudyControllerTest.kt`
- `cuelens/app/src/androidTest/java/de/eachandevery/cuelens/prestudy/PreStudyScreenTest.kt`

The current Android state model assumes that a completed study has a compensation code that must be confirmed. Extend the model; do not break that direct-participant branch.

---

## 3. Prolific participant ID definition

Use one shared definition in PHP and one shared definition in Kotlin/JavaScript.

A syntactically valid Prolific participant ID is:

- exactly 24 characters after trimming surrounding whitespace;
- ASCII alphanumeric only: `A-Z`, `a-z`, and `0-9`;
- treated as an opaque identifier;
- not converted to lowercase or uppercase.

Recommended regular expression:

```text
^[A-Za-z0-9]{24}$
```

Reject:

- 23 or 25 characters;
- punctuation, spaces inside the value, Unicode look-alikes, line breaks, or control characters;
- an empty value;
- a value that is neither a valid email address nor a valid Prolific ID.

Classification order must be deterministic:

1. Trim the input.
2. If it matches the Prolific pattern, classify it as `PROLIFIC`.
3. Otherwise, if it is a valid email address, classify it as `DIRECT`.
4. Otherwise, reject it.

Do not attempt to call the Prolific API in this implementation. Syntax validation is sufficient for this step.

---

## 4. Test plan: write these tests before production changes

## 4.1 Establish the baseline

Before adding tests, run the existing suites and record their result in the implementation notes or pull-request description.

PHP:

```bash
cd cuelens.each-and-every.de
./vendor/bin/phpunit tests
```

Focused browser validation test, with the existing local web-server and Firefox/geckodriver prerequisites:

```bash
./vendor/bin/phpunit tests/FormValidationBrowserTest.php
```

Android JVM tests:

```bash
cd ../cuelens
./gradlew testStagingDebugUnitTest
```

Android instrumentation tests when an emulator or device is available:

```bash
./gradlew connectedStagingDebugAndroidTest
```

Do not treat a pre-existing environmental skip as a successful behavioral test. Document skipped MariaDB, browser, or instrumentation tests and run them in an environment that provides their dependencies before release.

## 4.2 PHP identifier and registration unit tests

Create a small shared PHP module, preferably `cuelens.each-and-every.de/lib/participant-identifier.php`, but write its tests first.

Create `cuelens.each-and-every.de/tests/ParticipantIdentifierTest.php` with at least these cases:

- accepts an unchanged valid email address;
- normalizes the existing email path exactly as before, including trimming and the current lowercase behavior where relied upon by activation;
- accepts a 24-character ASCII alphanumeric Prolific ID;
- preserves the Prolific ID's case;
- trims only surrounding whitespace;
- rejects 23 and 25 characters;
- rejects internal whitespace;
- rejects punctuation and non-ASCII look-alike characters;
- rejects malformed email input;
- classifies direct email and Prolific ID into separate explicit enum/value-object variants;
- never returns a Prolific ID as an email value.

Create `cuelens.each-and-every.de/tests/RegistrationValidationTest.php` before extracting registration validation from the two page controllers. Cover:

- direct mode still requires email, name, IBAN, BIC, valid age, minimum cigarette count, study-information confirmation, and data-protection consent;
- Prolific mode requires Prolific ID, valid age, minimum cigarette count, study-information confirmation, and data-protection consent;
- Prolific mode does not require personal email, IBAN, or BIC;
- server-side Prolific mode clears and does not persist personal fields even if a manipulated request includes them;
- invalid identifier input cannot be used to bypass the direct-mode required fields;
- all existing direct-mode validation messages and rules continue to work.

### Important privacy extension for the existing name field

The current registration form also asks for `name`. Prolific generally prohibits collecting participants' first or last names without prior approval. Therefore, in Prolific mode, disable, clear, and do not submit or store the `name` field in addition to IBAN and BIC. This does not change the direct workflow. Add tests for this behavior.

If written approval from Prolific to collect names already exists, document it explicitly before choosing a different implementation. Do not silently retain the name field for Prolific users.

## 4.3 Website browser tests

Extend `cuelens.each-and-every.de/tests/FormValidationBrowserTest.php` before changing `index.js` or the page markup.

Add German and English coverage where text differs. At minimum test:

1. The identifier field uses `type="text"`, not `type="email"`.
2. The German label is `E-Mail-Adresse oder Prolific-ID`.
3. The English label is `Email address or Prolific ID`.
4. A syntactically valid email leaves name, IBAN, and BIC enabled and required.
5. A syntactically valid Prolific ID:
   - disables the name, IBAN, and BIC controls;
   - removes their `required` state;
   - clears pre-existing values before disabling the controls;
   - makes the disabled controls absent from normal form submission;
   - exposes an accessible explanatory message.
6. Replacing the Prolific ID with an email re-enables the three controls and restores their `required` state.
7. Replacing a valid identifier with malformed input displays the localized identifier validation message.
8. The existing direct email-required and bank-field validation tests still pass after updating only the label/message expectations required by the dual-purpose field.
9. Submitting a valid Prolific registration does not fail browser constraint validation because of disabled personal fields.
10. Toggling between modes repeatedly does not retain or accidentally resubmit previously entered personal data.

Prefer a stable data attribute such as `data-registration-mode="direct|prolific|invalid"` on the form for browser assertions and accessibility behavior. Do not use CSS visibility alone: disabled fields must be cleared and excluded from submission.

## 4.4 Registration database integration tests

Create `cuelens.each-and-every.de/tests/RegistrationMariaDbIntegrationTest.php` using the existing environment-variable and temporary-table conventions from `ActivationMariaDbIntegrationTest.php`.

Test:

- an existing/direct registration is stored with the same email, name, IBAN, and BIC values as before;
- a Prolific registration stores the Prolific ID in its dedicated administrative column;
- the Prolific row has `NULL` for email, name, IBAN, BIC, and email double-opt-in token;
- a Prolific registration is eligible for app activation without sending an email double-opt-in message;
- duplicate Prolific IDs are rejected by a database unique constraint;
- duplicate direct email behavior remains unchanged;
- the same literal string cannot be ambiguously stored in both identifier channels;
- no Prolific ID is written to a research-database temporary table.

## 4.5 Activation tests

Extend the existing activation tests before editing activation production code.

### `ActivationTest.php`

Add tests that:

- preserve the current email normalization and current email activation-token hash output;
- produce a separate domain-separated activation hash for a Prolific ID;
- do not lowercase a Prolific ID;
- reject malformed identifiers;
- return a non-identifying completion mode from the administrative registration record.

The current email activation HMAC input must remain compatible with already pending email activations. Do not change the existing email-domain string or normalization without a migration and a compatibility test.

### `ActivationEndpointTest.php`

Add tests that:

- accept a new generic JSON property named `identifier` for both email and Prolific input;
- continue accepting the legacy `email` property from already deployed app versions;
- reject requests containing conflicting `identifier` and `email` values;
- reject malformed Prolific IDs;
- never include the identifier in error responses;
- preserve the current request-token and confirmation response status codes.

### `ActivationMariaDbIntegrationTest.php`

Add separate direct and Prolific registrations. Verify:

- both can complete the existing request/confirm handshake;
- direct activation adds an allowlist row with completion mode `COMPENSATION_CODE`;
- Prolific activation adds an allowlist row with completion mode `PROLIFIC_MANUAL`;
- the research allowlist contains the app-token hash and completion mode only;
- the research database contains no email address and no Prolific ID;
- the administrative `registration_token_hash` remains derived from the app token using the existing `registration-token:v1` domain separation;
- an email registration cannot be activated with a Prolific ID and vice versa.

## 4.6 Operational-notification tests

Extend `cuelens.each-and-every.de/tests/OperationalNotificationTest.php` before adding the new event constant.

Add a test for `OPERATIONAL_EVENT_PROLIFIC_STUDY_COMPLETED` that verifies:

- the subject clearly identifies a completed Prolific participation;
- the body contains the event type, UTC timestamp, safe component, and request ID;
- the body does not contain the Prolific ID;
- the body does not contain an email address, app token, participant pseudonym, craving value, compensation code, IBAN, BIC, or name;
- the event uses the existing alert transport configured by `alertTo`, which is expected to resolve to `cuelens-alert@each-and-every.de` in production;
- transport failure remains non-fatal, consistent with the existing activation notification.

## 4.7 Study-completion backend tests

The current `submit.php` combines endpoint parsing, database logic, and response generation. Extract testable completion logic only after writing tests for the intended behavior.

Create focused tests such as:

- `cuelens.each-and-every.de/tests/StudyCompletionTest.php`
- `cuelens.each-and-every.de/tests/StudyCompletionMariaDbIntegrationTest.php`
- extend an existing submission endpoint test if one exists on the active branch; otherwise create `SubmissionEndpointTest.php`.

Required test cases:

### Direct completion regression tests

- Reports 1 through 19 behave exactly as before.
- Report 20 generates a UUID compensation code.
- The code is inserted into the existing `compensation_code` table.
- The response still contains `status: complete` and `compensation_code`.
- The existing compensation confirmation request still sets `confirmed_at`.
- No Prolific completion notification is queued.

### Prolific completion tests

- Reports 1 through 19 behave like direct study reports and do not expose the registration channel.
- Report 20 does not generate or insert a compensation code.
- The response contains a non-identifying discriminator such as:

  ```json
  {
    "success": true,
    "status": "complete",
    "situation_index": 20,
    "condition_code": "CUE_LABELING",
    "completion_mode": "PROLIFIC_MANUAL"
  }
  ```

- The response contains no `compensation_code` property and no Prolific ID.
- The administrative registration row is marked complete through `registration_token_hash`, not through a Prolific ID sent to the research database.
- Exactly one Prolific-completion event is queued for the administrative registration, even when the final request is retried.
- A retry after the twentieth report can recover an administrative update that failed after the research report was committed.
- A retry returns the same logical Prolific-complete response and does not insert a twenty-first report.
- Failure to mark administrative completion returns a retryable server error and never silently reports successful Prolific completion to the app.
- No Prolific ID appears in the research database, notification body, HTTP response, or error log.

## 4.8 Android identifier and activation tests

Create `cuelens/app/src/test/java/de/eachandevery/cuelens/prestudy/ParticipantIdentifierTest.kt` or place equivalent tests next to `PreStudyControllerTest.kt`.

Test the same accepted and rejected values as the PHP tests. The PHP and Kotlin test vectors must be identical. Consider storing the vectors in clearly mirrored data tables so differences are visible in review.

Extend `HttpActivationServiceTest.kt` before changing `ActivationService.kt`:

- new app requests use the JSON property `identifier`;
- both a direct email and a Prolific ID are transmitted unchanged except for surrounding trim;
- confirmation transmits the same identifier and app token;
- no property named `prolific_id`, `iban`, `bic`, or `name` is sent;
- existing timeout and protocol-error behavior remains unchanged.

Extend `PreStudyControllerTest.kt` before changing `PreStudyController.kt`:

- direct email activation remains accepted;
- valid Prolific ID activation is accepted;
- invalid dual-purpose input is rejected without a network call;
- the same normalized identifier is used in request and confirmation;
- all existing token-storage and failure-state tests remain green.

## 4.9 Android completion-state and UI tests

Introduce an explicit completion mode in the Android domain model, for example:

```kotlin
enum class CompletionMode {
    CompensationCode,
    ProlificManual
}
```

Do not infer Prolific status from whether a compensation code happens to be absent. Absence can also represent a transfer failure or corrupted state.

Before production changes, add tests for:

- parsing the existing direct response with `compensation_code`;
- parsing the new Prolific response with `completion_mode = PROLIFIC_MANUAL`;
- rejecting an internally inconsistent direct response without a code;
- rejecting an internally inconsistent Prolific response that contains a compensation code;
- persisting completion mode across app restart;
- preserving existing direct pending-confirmation behavior;
- marking Prolific completion locally without sending the compensation-code confirmation request;
- recovering a pending final Prolific submission after network failure.

Extend `PreStudyScreenTest.kt` and relevant unit tests:

- direct completion still displays the compensation-code instructions, code, and copy action;
- Prolific completion displays exactly:

  `Studie abgeschlossen. Der Abschluss bei Prolific erfolgt üblicherweise innerhalb 2 Tagen.`

- Prolific completion displays no compensation code and no copy button;
- add the English translation:

  `Study completed. Completion on Prolific usually takes place within 2 days.`

- the activation screen title and label support both identifiers;
- the activation button is enabled for a valid email and a valid Prolific ID and disabled for invalid input.

---

## 5. Database changes

Create versioned SQL migration files in the repository's existing database-migration location. If no migration directory exists, create a clearly named directory such as:

```text
cuelens.each-and-every.de/sql/migrations/
```

Use one migration for the administrative registration database and one for the craving/research database. Include a documented rollback script where safely possible.

Before writing `ALTER TABLE` statements, inspect the actual production-equivalent definitions with `SHOW CREATE TABLE`. Preserve existing column types, collations, indexes, defaults, and constraints unless a change is explicitly required below. Do not guess the current lengths of `name`, `iban`, `bic`, or `doi_token`.

## 5.1 Administrative registration database

Extend `register` with these concepts:

| Column | Suggested type | Purpose |
|---|---|---|
| `registration_channel` | `VARCHAR(16) NOT NULL DEFAULT 'DIRECT'` | `DIRECT` or `PROLIFIC` |
| `prolific_id` | `CHAR(24) CHARACTER SET ascii COLLATE ascii_bin NULL` | Administrative Prolific identifier only |
| `registration_confirmed_at` | nullable timestamp/datetime | Unified activation-eligibility timestamp |
| `study_completed_at` | nullable timestamp/datetime | Source of truth for manual Prolific payment eligibility |
| `completion_notification_queued_at` | nullable timestamp/datetime | Idempotency marker for the operational event |
| `bonus_paid_at` | nullable timestamp/datetime | Manually maintained payment-reconciliation field; no automatic writer |

Required constraints and indexes:

- unique index on `prolific_id`;
- index on `(registration_channel, study_completed_at, bonus_paid_at)` for the manual-payment work list;
- allowed values for `registration_channel` enforced in application code and, when supported reliably by the deployed MariaDB version, by a database check constraint;
- `email` must become nullable for Prolific rows;
- `name`, `iban`, and `bic` must become nullable for Prolific rows;
- `doi_token` must become nullable for Prolific rows.

Backfill all existing rows as `DIRECT`. Do not rewrite existing email, bank, app-token, or consent data.

Use `registration_confirmed_at` as the generic activation predicate:

- existing direct rows with completed double opt-in must be backfilled as confirmed;
- new direct rows become confirmed only in `confirm-de.php` or `confirm-en.php`;
- new Prolific rows become confirmed immediately after successful server-side registration validation, because no email address exists to confirm.

Keep the existing `doi` column and direct double-opt-in behavior for compatibility. Do not describe Prolific registration as an email double opt-in and do not send a fake confirmation email.

Data invariant to enforce in server code and integration tests:

```text
DIRECT:
  email, name, iban, bic are populated
  prolific_id is NULL

PROLIFIC:
  prolific_id is populated
  email, name, iban, bic, doi_token are NULL
```

Do not place both an email address and a Prolific ID in one row.

## 5.2 Research/craving database

Extend the existing `valid_app_token_hashes` allowlist with a non-identifying completion mode:

| Column | Suggested type | Default |
|---|---|---|
| `completion_mode` | `VARCHAR(32) NOT NULL` | `COMPENSATION_CODE` |

Backfill every existing allowlist row with `COMPENSATION_CODE`. The only values for this implementation are:

- `COMPENSATION_CODE`
- `PROLIFIC_MANUAL`

Do not add `prolific_id`, `email`, `registration_channel`, or bank fields to the research database.

Do not alter `self_reports` to contain a Prolific ID. Continue deriving `participant_id` exclusively from the app token and the existing pseudonym secret.

The existing `registration_token_hash(secret, appToken)` is an acceptable bridge to the administrative database because it is derived from the random app token with a domain-separated HMAC. Use it transiently to update the administrative registration row. Do not replace it with a hash of the Prolific ID.

---

## 6. Website implementation

## 6.1 Refactor duplicated registration logic safely

The German and English pages currently duplicate sensitive POST handling. After the new tests are red, extract shared logic into small testable functions/classes, for example:

- `lib/participant-identifier.php`
- `lib/registration.php`

Keep localized presentation and messages in `index-de.php` and `index-en.php`, but centralize:

- identifier classification;
- server-side validation;
- database insert construction;
- direct vs. Prolific workflow selection;
- generic registration result handling.

Remove redundant repeated CSRF checks only if regression tests prove unchanged behavior. CSRF validation must remain server-side for both channels.

## 6.2 Identifier field markup

Keep a single visible field in the same form position, but change it from an email-only control to a dual-purpose text control.

Recommended markup semantics:

```html
<label for="email">E-Mail-Adresse oder Prolific-ID</label>
<input
    type="text"
    id="email"
    name="participant_identifier"
    required
    autocomplete="off"
    spellcheck="false"
    autocapitalize="none"
    aria-describedby="identifier-help registration-mode-help"
>
```

The DOM `id="email"` may remain temporarily to minimize breakage in existing CSS and browser tests. Prefer the semantically correct POST name `participant_identifier` and support legacy `email` input server-side during the transition. Do not accept two conflicting values.

Localized help text should state that Prolific participants enter the 24-character Prolific ID instead of a personal email address.

## 6.3 Dynamic direct/Prolific mode in `index.js`

Add pure helpers before DOM behavior where practical:

```text
isSyntacticallyValidProlificId(value)
classifyParticipantIdentifier(value)
applyRegistrationMode(mode)
```

For a valid Prolific ID:

- set mode to `prolific`;
- clear `name`, `iban`, and `bic` before disabling them;
- remove their `required` attributes/properties;
- disable all three controls so browsers omit them from normal submission;
- clear any existing custom validity messages;
- add an accessible localized explanation that payment is handled through Prolific and personal/bank details are therefore not collected.

For a valid email:

- set mode to `direct`;
- enable `name`, `iban`, and `bic`;
- restore their required state and existing validation messages.

For empty or invalid input:

- set mode to `invalid` or a neutral initial state;
- do not treat it as Prolific merely because it lacks `@`;
- maintain safe required-field behavior;
- show the localized dual-purpose identifier message on validation.

The server must repeat every classification and validation decision. JavaScript is usability logic only, not a security boundary.

## 6.4 Server-side registration behavior

### Direct mode

Preserve current behavior:

- validate email as before;
- require and store name, IBAN, and BIC;
- create DOI token/hash;
- insert a `DIRECT` registration;
- send the same localized confirmation email;
- redirect to the existing double-opt-in notice;
- confirm through `confirm-de.php` or `confirm-en.php`;
- send the existing data-minimized registration event after confirmation.

### Prolific mode

Implement a separate branch:

- validate the 24-character Prolific ID server-side;
- require the unchanged eligibility and consent fields;
- force email, name, IBAN, BIC, and DOI token to `NULL`, regardless of manipulated POST values;
- insert `registration_channel = 'PROLIFIC'`;
- set `registration_confirmed_at` immediately;
- do not instantiate or send a participant confirmation email;
- send the existing generic registration-created event or a separate data-minimized registration event after the database transaction commits;
- redirect to a localized success page that states registration succeeded and links to the existing app-installation instructions.

Do not route Prolific users through `double-de.php`, `double-en.php`, `confirm-de.php`, or `confirm-en.php`, because those pages describe an email confirmation that did not occur.

Create localized success pages only if no existing neutral page can be reused without misleading text.

## 6.5 Duplicate handling

Return localized, channel-appropriate messages:

- direct duplicate: retain the current “email already registered” behavior;
- Prolific duplicate: state that the Prolific ID is already registered;
- never echo the submitted identifier in the response;
- do not reveal whether an arbitrary identifier exists through a public lookup endpoint beyond the existing registration submission behavior.

---

## 7. Activation backend implementation

## 7.1 Generic identifier model

Refactor email-specific activation code into an explicit identifier model rather than overloading variables named `email` with Prolific IDs.

Suggested concepts:

```text
ParticipantIdentifier
  type: DIRECT_EMAIL | PROLIFIC_ID
  normalizedValue: string
```

Use parameter names such as `$identifier`, `$identifierType`, and `$normalizedIdentifier` in new code.

## 7.2 Endpoint compatibility

`activate.php` shall:

1. Accept the new `identifier` JSON property.
2. Continue accepting the legacy `email` property for old Android versions.
3. Reject a request if both properties are present and their normalized values differ.
4. Classify and validate the value server-side.
5. Use the same identifier in both handshake calls.
6. Keep current response statuses and error-body shape.

Do not return registration channel, email, or Prolific ID in the activation response.

## 7.3 Preserve email activation hashes

The current email activation hash uses an HMAC context beginning with `activation:v1`. Preserve the existing email calculation exactly so an activation requested before deployment can still be confirmed after deployment.

Add an explicitly domain-separated Prolific calculation, for example:

```text
activation:prolific:v1\0<case-preserved-prolific-id>\0<lowercase-app-token>
```

Do not hash an email and Prolific ID through an ambiguous shared namespace.

## 7.4 Database lookup

Activation shall find one confirmed administrative registration by its explicit channel and corresponding column:

```text
DIRECT     -> register.email
PROLIFIC   -> register.prolific_id
```

Do not use SQL such as `WHERE email = :identifier OR prolific_id = :identifier` without also binding and checking the classified channel.

On confirmation:

- keep clearing the pending activation hash and validity timestamp;
- keep setting `app_token_issued_at`;
- keep storing `registration_token_hash` in the administrative registration database;
- read the registration channel;
- insert the app-token allowlist hash into the research database with the matching non-identifying completion mode.

Mapping:

```text
DIRECT     -> COMPENSATION_CODE
PROLIFIC   -> PROLIFIC_MANUAL
```

Continue sending the existing generic app-activation event. It must contain no identifier.

---

## 8. Android activation implementation

## 8.1 Rename concepts without breaking the route

The internal route may remain named `EmailActivation` if renaming it creates unnecessary migration risk, but user-facing text and new variables must be identifier-neutral.

Preferred user-facing strings:

German:

- title: `App-Aktivierung`
- label: `E-Mail-Adresse oder Prolific-ID`

English:

- title: `App activation`
- label: `Email address or Prolific ID`

Add localized help text explaining that Prolific participants use their Prolific ID.

## 8.2 Input behavior

In `EmailActivationScreen` or its renamed successor:

- Keep `KeyboardType.Email` for the combined identifier input, because it improves usability for email addresses while still allowing all alphanumeric characters required for a Prolific ID;
- disable autocorrection and unwanted capitalization where supported;
- validate through the shared Kotlin identifier parser;
- enable activation for either a valid email or valid Prolific ID;
- trim surrounding whitespace before passing the value to the controller;
- never transform Prolific ID case.

## 8.3 Activation protocol

Change the Android service interface from email-specific parameter names to identifier-neutral names.

New app versions should send:

```json
{"identifier":"..."}
```

and on confirmation:

```json
{"identifier":"...","app_token":"..."}
```

Preserve compatibility for old versions that still send `email`.

Do not store the email or Prolific ID after successful activation. Continue storing only the app token through the existing Android Keystore-backed store.

---

## 9. Study completion backend implementation

## 9.1 Separate completion policy from research measurements

When handling a self-report, read `completion_mode` together with the app-token allowlist entry. This is non-identifying policy metadata. Do not look up or load the Prolific ID during reports 1 through 19.

Keep the existing participant pseudonym and condition assignment unchanged.

## 9.2 Direct branch

For `COMPENSATION_CODE`, preserve the current final-report branch exactly:

- generate UUID-v4 compensation code;
- insert it into the existing table;
- commit;
- return the existing completion response with code;
- accept the existing later confirmation request.

## 9.3 Prolific branch

For `PROLIFIC_MANUAL` on report 20:

1. Commit the twentieth research report without creating a compensation-code row.
2. Compute the existing `registration_token_hash` from the raw app token and pseudonym secret.
3. Open the administrative registration database using its existing protected config.
4. Find exactly one activated `PROLIFIC` registration by `registration_token_hash`.
5. Set `study_completed_at` with `COALESCE(existing_value, CURRENT_TIMESTAMP)`.
6. Atomically claim the notification by setting `completion_notification_queued_at` only when it is `NULL`.
7. Queue `OPERATIONAL_EVENT_PROLIFIC_STUDY_COMPLETED` only when that conditional update changed one row.
8. Return the Prolific-complete JSON response without compensation code.

The notification is a prompt for the operator. The administrative row, not successful email delivery, is the source of truth for manual payment.

## 9.4 Retry and partial-failure behavior

There is no distributed transaction across the registration and craving databases. Implement explicit idempotency.

Required behavior:

- If the twentieth research report commits but the administrative completion update fails, return HTTP 500.
- When the app retries the same final submission, detect that twenty reports already exist for this app-token-derived participant.
- For `PROLIFIC_MANUAL`, do not return “study already complete” immediately. Re-run the idempotent administrative completion step, queue the event if still needed, and return the same successful completion payload.
- Never insert a twenty-first report.
- Never queue more than one completion event for the same administrative registration.

Do not change the direct retry protocol unless a separate regression-safe improvement is necessary. Scope any direct change explicitly and test it.

## 9.5 Operational event

Add:

```php
const OPERATIONAL_EVENT_PROLIFIC_STUDY_COMPLETED = 'prolific_study_completed';
```

Use a subject such as:

```text
[CueLens] Prolific-Teilnahme abgeschlossen
```

The body notice should state that payment eligibility is available in the protected registration database. It must not contain the Prolific ID or research data.

Reuse the existing `alertTo` SMTP configuration and shutdown-flush mechanism. Do not add a second hard-coded recipient in endpoint code. Verify that production configuration points `alertTo` to `cuelens-alert@each-and-every.de` without committing credentials.

---

## 10. Android completion protocol and UI

## 10.1 Explicit persisted state

Extend `StudyProgress` and shared-preference persistence with an explicit completion mode. Suggested keys:

```text
KEY_COMPLETION_MODE
```

Allowed persisted values:

```text
COMPENSATION_CODE
PROLIFIC_MANUAL
```

Migration/default behavior:

- existing installations with a stored compensation code are `COMPENSATION_CODE`;
- existing completed installations with a code remain unchanged;
- missing completion mode must not be interpreted as Prolific merely because a code is absent;
- inconsistent/corrupt state should fail closed and retain retry/support behavior.

## 10.2 Response processing

For direct completion:

- persist the compensation code;
- keep the existing compensation confirmation request;
- mark study completed only according to the current successful confirmation flow;
- display the existing code UI.

For Prolific completion:

- require `status = complete` and `completion_mode = PROLIFIC_MANUAL`;
- require the absence of `compensation_code`;
- do not send a compensation confirmation request;
- persist completion mode and completed state;
- clear pending submission state only after a valid successful response;
- display the Prolific completion text.

## 10.3 Completion UI

Both the productive study start-gate screen and the main/home screen must render from the same explicit completion policy.

For Prolific completion, display exactly in German:

```text
Studie abgeschlossen. Der Abschluss bei Prolific erfolgt üblicherweise innerhalb 2 Tagen.
```

English translation:

```text
Study completed. Completion on Prolific usually takes place within 2 days.
```

For Prolific users:

- do not display a compensation code;
- do not display the “send this code” instruction;
- do not display the copy-code action;
- do not display bank-payment language.

For direct users, preserve all existing compensation-code UI.

Avoid duplicating the mode decision across several composables. Introduce a small presentation model or helper that maps persisted completion mode to the correct localized content.

---

## 11. Privacy, security, and logging requirements

1. Use prepared statements for every new database operation.
2. Keep the current CSRF protection for both registration channels.
3. Never place the Prolific ID in a URL, redirect query string, analytics call, app log, PHP `error_log`, exception message, or operational notification.
4. Never include the submitted identifier in a public validation error.
5. Never log request payloads for registration, activation, or study completion.
6. Keep app tokens and activation hashes out of notification messages.
7. Store only the app token in the Android Keystore-backed store; do not persist the entered identifier.
8. Use the existing domain-separated HMAC functions for app-token-derived identities.
9. Do not derive the research `participant_id` from the Prolific ID.
10. Do not add a Prolific API key or secret to the app, PHP repository, JavaScript, database, or configuration committed to Git.
11. Do not automate bonus payment in this change.
12. Ensure duplicate and race behavior is enforced both by transactions/conditional updates and database constraints.
13. Keep operational notifications data-minimized. A generic event plus a request ID is sufficient; the operator retrieves the Prolific ID from the protected administrative work list.
14. Update the privacy notice and study information in a separate reviewed content change if they do not yet disclose use of the Prolific ID and manual Prolific payment processing. Do not silently change legal documents as part of a code-only refactor.

---

## 12. Compatibility and deployment order

Use a backend-first rollout so current and new Android versions can coexist.

1. Write the necessary `ALTER TABLE` and any other SQL statements in newly created `.sql` files.
2. Run all baseline tests.
3. Add new tests and demonstrate the expected red state.
4. Apply and test the administrative-database migration in staging.
5. Apply and test the research-database migration in staging.
6. Deploy backend code that:
   - accepts legacy `email` and new `identifier` activation payloads;
   - defaults existing allowlist rows to `COMPENSATION_CODE`;
   - preserves all direct workflows.
7. Deploy the dual-mode registration website.
8. Publish the Android version that sends `identifier` and understands `PROLIFIC_MANUAL`.
9. Run end-to-end staging tests for both participant channels.
10. Deploy production migrations before production code that depends on the new columns.
11. Verify `alertTo` and send one controlled staging notification.
12. Verify the manual-payment work-list query with synthetic staging data.

Do not require all participants to update immediately. Old Android versions sending the `email` JSON property must continue to activate direct registrations.

---

## 13. End-to-end acceptance matrix

| Scenario | Expected result |
|---|---|
| Existing direct participant registers | Existing email/name/IBAN/BIC validation and DOI email remain functional |
| Existing direct participant activates with email | Same handshake and app-token storage as before |
| Existing direct participant completes 20 tasks | Existing compensation code is created, confirmed, and displayed |
| Valid Prolific ID entered on website | Prolific mode activates; name/IBAN/BIC are cleared, disabled, not required, and not submitted |
| Prolific registration submitted | Dedicated Prolific column populated; personal email/name/bank fields remain `NULL`; no DOI email sent |
| Prolific participant activates app | Same three-step app-token handshake succeeds using the Prolific ID |
| Prolific participant submits reports 1–19 | Research rows contain only existing pseudonymous participant ID and study values |
| Prolific participant submits report 20 | No compensation code is generated; admin completion is recorded; one generic alert event is queued |
| Prolific final request is retried | No 21st report and no duplicate alert; same complete result returned |
| Prolific participant reopens app | Exact Prolific completion text remains visible; no code/copy action appears |
| Invalid 24-character-like input | Client and server reject it; bank fields cannot be bypassed |
| Old Android app sends `email` property | Direct activation still works |
| Database inspection of research DB | No email, name, bank data, Prolific ID, or hash of Prolific ID exists |
| Notification inspection | No participant identifier or research value exists in subject/body |
| Manual payment list | Protected registration DB lists completed, unpaid Prolific IDs only |

---

## 14. Required test execution before completion

Run and report at least:

```bash
cd cuelens.each-and-every.de
./vendor/bin/phpunit tests
```

Run MariaDB tests with both test database configurations supplied; do not leave them skipped for release verification.

Run the browser tests in the existing Firefox/geckodriver environment:

```bash
./vendor/bin/phpunit tests/FormValidationBrowserTest.php
```

Run Android tests:

```bash
cd ../cuelens
./gradlew testStagingDebugUnitTest
./gradlew testProductionDebugUnitTest
```

When an emulator/device is available:

```bash
./gradlew connectedStagingDebugAndroidTest
```

Also build both relevant variants:

```bash
./gradlew assembleStagingDebug
./gradlew assembleProductionDebug
```

Report:

- commands executed;
- passed, failed, and skipped test counts;
- environmental reasons for any remaining skip;
- migration test result;
- direct-flow end-to-end result;
- Prolific-flow end-to-end result;
- confirmation that no Prolific API or automatic payment code was added.

---

## 15. Definition of done

This change is complete only when all of the following are true:

- Automated tests were committed/written before the corresponding production changes.
- The unchanged direct registration, email activation, and compensation-code path have explicit passing regression tests.
- A valid Prolific ID can be entered on the website and in the app.
- Prolific users do not provide personal email, name, IBAN, or BIC.
- Prolific IDs exist only in the administrative registration database.
- Research data remains associated only with existing app-token-derived pseudonyms.
- The research database stores only the non-identifying completion mode needed to choose the completion policy.
- The server creates no compensation code for Prolific users.
- The server records Prolific completion in the administrative database and queues one data-minimized event to the existing alert recipient path.
- Manual payment remains fully manual.
- The app displays the exact requested German completion text for Prolific users.
- The app continues to display and confirm compensation codes for direct users.
- Old Android activation requests using the `email` property remain supported.
- Full PHP and Android test suites pass, including MariaDB and browser/instrumentation tests in their supported environments.

---

## 16. Explicit non-goals

Do not implement any of the following in this change:

- Prolific API integration;
- automatic resolution of `SESSION_ID`;
- URL-parameter changes to the already published Prolific study;
- automatic Prolific completion, approval, rejection, or bonus payment;
- storage of Prolific credentials or API tokens;
- replacement of the existing direct registration path;
- migration of existing direct participants to Prolific;
- changes to the scientific self-report values, condition allocation, total task count, or timing rules;
- broad unrelated refactoring.

Keep the implementation narrow, reversible, well-tested, privacy-preserving, and compatible with participants who are already registered or already using the current app.
