-- Rollback for 003_app_review_account_up.sql.

SET time_zone = '+00:00';

ALTER TABLE register
    DROP COLUMN app_review_account;
