-- ============================================================
-- 04_snowpipe.sql
-- Purpose:
--   Create a Snowpipe object that automatically loads JSON files
--   from the external stage into RAW.EVENTS.
--
-- Expected output:
--   SHOW PIPES returns MY_EVENTS_PIPE with a notification_channel.
--   Use that notification_channel as the S3 event notification
--   SQS destination.
--
-- Transform:
--   $1 is each JSON object from the staged file. The pipe extracts
--   stable top-level fields into columns and stores the event-specific
--   object in payload.
-- ============================================================

USE WAREHOUSE INGEST_WH;
USE DATABASE INGEST_DB;
USE SCHEMA RAW;

CREATE OR REPLACE PIPE RAW.my_events_pipe
  AUTO_INGEST = TRUE
AS
COPY INTO RAW.EVENTS (event_id, event_time, user_id, payload)
FROM (
  SELECT
    $1:event_id::STRING,
    TRY_TO_TIMESTAMP_NTZ($1:event_time::STRING),
    $1:user_id::STRING,
    $1:payload
  FROM @RAW.my_s3_stage
)
FILE_FORMAT = (FORMAT_NAME = RAW.JSON_FF)
ON_ERROR = 'CONTINUE';

SHOW PIPES LIKE 'MY_EVENTS_PIPE' IN SCHEMA INGEST_DB.RAW;
