-- Rollback for 002_activation_completion_mode_up.sql.
-- Removing the mode makes Prolific allowlist rows indistinguishable from direct
-- rows. Run this only before Prolific app activation has opened, or after those
-- rows have been removed under the approved data-handling procedure.

SET time_zone = '+00:00';

ALTER TABLE valid_app_token_hashes
    DROP CHECK chk_valid_app_token_completion_mode,
    DROP COLUMN completion_mode;
