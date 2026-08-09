-- CueLens administrative registration migration (MySQL 8.0.46).
-- Derived from SHOW CREATE TABLE register on 2026-08-09.
-- Apply before deploying dual-registration PHP code. Run with a database backup.

SET time_zone = '+00:00';

ALTER TABLE register
    ADD COLUMN registration_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT FIRST,
    DROP PRIMARY KEY,
    ADD PRIMARY KEY (registration_id),
    ADD UNIQUE KEY uq_register_email (email),
    MODIFY COLUMN email VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL,
    MODIFY COLUMN name VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL,
    MODIFY COLUMN iban VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL,
    MODIFY COLUMN bic VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL,
    MODIFY COLUMN doi_token VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NULL,
    ADD COLUMN registration_channel VARCHAR(16) NOT NULL DEFAULT 'DIRECT' AFTER created_at,
    ADD COLUMN prolific_id CHAR(24) CHARACTER SET ascii COLLATE ascii_bin NULL AFTER email,
    ADD COLUMN registration_confirmed_at DATETIME NULL AFTER doi,
    ADD COLUMN study_completed_at DATETIME NULL AFTER registration_confirmed_at,
    ADD COLUMN completion_notification_queued_at DATETIME NULL AFTER study_completed_at,
    ADD COLUMN bonus_paid_at DATETIME NULL AFTER completion_notification_queued_at;

UPDATE register
   SET registration_channel = 'DIRECT',
       registration_confirmed_at = CASE
           WHEN doi = 1 THEN COALESCE(registration_confirmed_at, UTC_TIMESTAMP())
           ELSE registration_confirmed_at
       END;

ALTER TABLE register
    ADD UNIQUE KEY uq_register_prolific_id (prolific_id),
    ADD KEY ix_register_prolific_payment_worklist
        (registration_channel, study_completed_at, bonus_paid_at),
    ADD CONSTRAINT chk_register_registration_channel
        CHECK (registration_channel IN ('DIRECT', 'PROLIFIC')),
    ADD CONSTRAINT chk_register_identifier_separation
        CHECK (
            (registration_channel = 'DIRECT'
                AND email IS NOT NULL
                AND name IS NOT NULL
                AND iban IS NOT NULL
                AND bic IS NOT NULL
                AND prolific_id IS NULL)
            OR
            (registration_channel = 'PROLIFIC'
                AND prolific_id IS NOT NULL
                AND email IS NULL
                AND name IS NULL
                AND iban IS NULL
                AND bic IS NULL
                AND doi_token IS NULL
                AND registration_confirmed_at IS NOT NULL)
        );
