-- CueLens administrative App Review account migration (MySQL 8.0.46).
-- The account is marked separately after this schema migration. No identifier
-- belongs in source control.

SET time_zone = '+00:00';

ALTER TABLE register
    ADD COLUMN is_app_review_account BOOLEAN NOT NULL DEFAULT FALSE
        AFTER registration_channel,
    ADD COLUMN app_review_account_singleton TINYINT
        GENERATED ALWAYS AS (
            CASE WHEN is_app_review_account = TRUE THEN 1 ELSE NULL END
        ) STORED AFTER is_app_review_account,
    ADD UNIQUE KEY uq_register_app_review_account (app_review_account_singleton),
    ADD CONSTRAINT chk_register_app_review_account
        CHECK (
            is_app_review_account IN (FALSE, TRUE)
            AND (is_app_review_account = FALSE OR registration_channel = 'DIRECT')
        );
