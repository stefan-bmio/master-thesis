-- Rollback for 004_test_data_markers_up.sql.
-- Do not run after review testing unless the marked rows have first been
-- removed under the approved test-data handling procedure.

SET time_zone = '+00:00';

ALTER TABLE compensation_code
    DROP CHECK chk_compensation_code_is_test,
    DROP INDEX ix_compensation_code_payment,
    DROP COLUMN is_test;

ALTER TABLE self_reports
    DROP CHECK chk_self_reports_is_test,
    DROP INDEX ix_self_reports_analysis,
    DROP COLUMN is_test;

ALTER TABLE valid_app_token_hashes
    DROP CHECK chk_valid_app_token_is_test,
    DROP COLUMN is_test;
