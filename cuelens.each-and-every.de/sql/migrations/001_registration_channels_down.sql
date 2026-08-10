-- Manual rollback for 001_registration_channels_up.sql.
-- This rollback discards Prolific-only administrative data and is therefore not
-- safe after Prolific registration has opened. Before running it, archive and
-- remove all PROLIFIC rows under the approved data-handling procedure. The
-- NOT NULL changes below deliberately fail while such rows still exist.

SET time_zone = '+00:00';

ALTER TABLE register
    DROP CHECK chk_register_identifier_separation,
    DROP CHECK chk_register_registration_channel,
    DROP INDEX ix_register_prolific_payment_worklist,
    DROP INDEX uq_register_prolific_id,
    DROP INDEX uq_register_email,
    MODIFY COLUMN email VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
    MODIFY COLUMN name VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
    MODIFY COLUMN iban VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
    MODIFY COLUMN bic VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
    MODIFY COLUMN doi_token VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
    DROP PRIMARY KEY,
    DROP COLUMN registration_id,
    ADD PRIMARY KEY (email),
    DROP COLUMN registration_channel,
    DROP COLUMN prolific_id,
    DROP COLUMN registration_confirmed_at,
    DROP COLUMN study_completed_at,
    DROP COLUMN completion_notification_queued_at,
    DROP COLUMN bonus_paid_at;
