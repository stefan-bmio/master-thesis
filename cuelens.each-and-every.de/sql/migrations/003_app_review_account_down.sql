-- Rollback for 003_app_review_account_up.sql.

SET time_zone = '+00:00';

ALTER TABLE register
    DROP CHECK chk_register_app_review_account,
    DROP INDEX uq_register_app_review_account,
    DROP COLUMN app_review_account_singleton,
    DROP COLUMN is_app_review_account;
