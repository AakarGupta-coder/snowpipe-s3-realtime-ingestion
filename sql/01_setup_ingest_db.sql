-- ============================================================
-- 01_setup_ingest_db.sql
-- Purpose:
--   Create the Snowflake compute and database objects required
--   for a raw event ingestion layer.
--
-- Expected output:
--   - Warehouse: INGEST_WH
--   - Database: INGEST_DB
--   - Schema: INGEST_DB.RAW
--   - Table: INGEST_DB.RAW.EVENTS
--
-- Notes:
--   The payload column is VARIANT so different event types can
--   land in one raw table without constant schema changes.
-- ============================================================

CREATE OR REPLACE WAREHOUSE INGEST_WH
  WITH WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE;

CREATE OR REPLACE DATABASE INGEST_DB;
CREATE OR REPLACE SCHEMA INGEST_DB.RAW;

USE WAREHOUSE INGEST_WH;
USE DATABASE INGEST_DB;
USE SCHEMA RAW;

CREATE OR REPLACE TABLE RAW.EVENTS (
  event_id STRING,
  event_time TIMESTAMP,
  user_id STRING,
  payload VARIANT
);

SHOW TABLES IN SCHEMA INGEST_DB.RAW;
