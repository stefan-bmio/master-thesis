-- CueLens research allowlist migration (MySQL 8.0.46).
-- Derived from SHOW CREATE TABLE valid_app_token_hashes on 2026-08-09.
-- Apply before deploying the dual-channel activation backend.
-- Existing rows are backfilled by the NOT NULL column default.

SET time_zone = '+00:00';

ALTER TABLE valid_app_token_hashes
    ADD COLUMN completion_mode VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin
        NOT NULL DEFAULT 'COMPENSATION_CODE' AFTER hash,
    ADD CONSTRAINT chk_valid_app_token_completion_mode
        CHECK (completion_mode IN ('COMPENSATION_CODE', 'PROLIFIC_MANUAL'));
