-- CueLens administrative App Review account migration (MySQL 8.0.46).
-- The account is marked separately after this schema migration. No identifier
-- belongs in source control.

SET time_zone = '+00:00';

ALTER TABLE register
    ADD COLUMN app_review_account BOOLEAN NOT NULL DEFAULT FALSE
        AFTER registration_channel;
