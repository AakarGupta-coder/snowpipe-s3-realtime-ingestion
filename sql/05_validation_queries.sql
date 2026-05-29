-- ============================================================
-- 05_validation_queries.sql
-- Purpose:
--   Validate that Snowpipe is healthy and that files uploaded to
--   S3 have loaded into INGEST_DB.RAW.EVENTS.
--
-- Expected output for included test data on a clean table:
--   total_loaded_rows = 27
--
-- Run after:
--   1. S3 event notification is configured
--   2. test-data/test_*.json files are uploaded to incoming/
--   3. Snowpipe has had a short time to process notifications
-- ============================================================

USE WAREHOUSE INGEST_WH;
USE DATABASE INGEST_DB;
USE SCHEMA RAW;

SELECT SYSTEM$PIPE_STATUS('INGEST_DB.RAW.MY_EVENTS_PIPE');

SELECT COUNT(*) AS total_loaded_rows
FROM INGEST_DB.RAW.EVENTS;

SELECT
  payload:event_type::STRING AS event_type,
  payload:source_system::STRING AS source_system,
  COUNT(*) AS event_count
FROM INGEST_DB.RAW.EVENTS
GROUP BY 1, 2
ORDER BY event_count DESC, event_type;

SELECT
  event_id,
  event_time,
  user_id,
  payload:event_type::STRING AS event_type,
  payload:source_system::STRING AS source_system,
  payload:patient_id::STRING AS patient_id,
  payload
FROM INGEST_DB.RAW.EVENTS
ORDER BY event_time DESC;

SELECT *
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
  TABLE_NAME => 'EVENTS',
  START_TIME => DATEADD(HOUR, -2, CURRENT_TIMESTAMP())
))
ORDER BY LAST_LOAD_TIME DESC;
