-- CueLens research test-data markers (MySQL 8.0.46).
-- Existing production rows remain scientific data through the FALSE defaults.

SET time_zone = '+00:00';

ALTER TABLE valid_app_token_hashes
    ADD COLUMN is_test BOOLEAN NOT NULL DEFAULT FALSE AFTER completion_mode,
    ADD CONSTRAINT chk_valid_app_token_is_test CHECK (is_test IN (FALSE, TRUE));

ALTER TABLE self_reports
    ADD COLUMN is_test BOOLEAN NOT NULL DEFAULT FALSE AFTER craving,
    ADD KEY ix_self_reports_analysis (is_test, participant_id),
    ADD CONSTRAINT chk_self_reports_is_test CHECK (is_test IN (FALSE, TRUE));

ALTER TABLE compensation_code
    ADD COLUMN is_test BOOLEAN NOT NULL DEFAULT FALSE AFTER compensation_code,
    ADD KEY ix_compensation_code_payment (is_test, confirmed_at),
    ADD CONSTRAINT chk_compensation_code_is_test CHECK (is_test IN (FALSE, TRUE));
