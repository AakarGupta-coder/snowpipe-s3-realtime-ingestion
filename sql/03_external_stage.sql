-- ============================================================
-- 03_external_stage.sql
-- Purpose:
--   Create the JSON file format and external stage that points
--   Snowflake to the S3 incoming/ prefix.
--
-- Replace before running:
--   <S3_BUCKET> with your S3 bucket name
--
-- Expected output:
--   - File format RAW.JSON_FF
--   - Stage RAW.my_s3_stage
--   - LIST @RAW.my_s3_stage completes successfully
--
-- Note:
--   LIST can return zero rows if the S3 prefix is empty. That is
--   acceptable as long as there is no AWS role/access error.
-- ============================================================

USE WAREHOUSE INGEST_WH;
USE DATABASE INGEST_DB;
USE SCHEMA RAW;

CREATE OR REPLACE FILE FORMAT RAW.JSON_FF
  TYPE = JSON
  STRIP_OUTER_ARRAY = TRUE;

CREATE OR REPLACE STAGE RAW.my_s3_stage
  STORAGE_INTEGRATION = my_s3_int
  URL = 's3://<S3_BUCKET>/incoming/'
  FILE_FORMAT = RAW.JSON_FF;

LIST @RAW.my_s3_stage;
