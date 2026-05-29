# Snowflake Setup Guide

**Made by Aakar Gupta**

This guide covers the Snowflake objects needed by the ingestion pipeline.

## Outcome

After completing this guide, Snowflake will contain a working raw ingestion layer:

- `INGEST_WH` warehouse
- `INGEST_DB.RAW` schema
- `RAW.EVENTS` landing table
- `my_s3_int` storage integration
- `RAW.JSON_FF` file format
- `RAW.my_s3_stage` external stage
- `RAW.my_events_pipe` Snowpipe with auto-ingest

## Object Overview

| Object | Purpose |
|---|---|
| Warehouse | Executes SQL setup and validation |
| Database | Groups ingestion objects |
| Schema | Raw landing layer |
| Table | Stores loaded event data |
| Storage Integration | Connects Snowflake to AWS using IAM role assumption |
| File Format | Defines JSON parsing behavior |
| Stage | Points to the S3 prefix |
| Pipe | Auto-loads files from the stage |

## 1. Create Database Objects

Run:

```sql
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
```

Expected setup result:

| Object Type | Expected Name |
|---|---|
| Warehouse | `INGEST_WH` |
| Database | `INGEST_DB` |
| Schema | `RAW` |
| Table | `RAW.EVENTS` |

Expected table columns:

| Column | Role |
|---|---|
| `event_id` | Unique event identifier |
| `event_time` | Time when the upstream event occurred |
| `user_id` | Actor, service, user, or device that created the event |
| `payload` | Flexible JSON object for event-specific details |

## 2. Create Storage Integration

Replace placeholders:

```sql
CREATE OR REPLACE STORAGE INTEGRATION my_s3_int
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::<AWS_ACCOUNT_ID>:role/SnowpipeS3Role'
  STORAGE_ALLOWED_LOCATIONS = ('s3://<S3_BUCKET>/incoming/');

DESC INTEGRATION my_s3_int;
```

Use the `DESC INTEGRATION` output to configure the AWS trust policy.

Expected `DESC INTEGRATION` values:

| Property | What To Check |
|---|---|
| `ENABLED` | Returns `true` |
| `STORAGE_PROVIDER` | Returns `S3` |
| `STORAGE_ALLOWED_LOCATIONS` | Points to `s3://<S3_BUCKET>/incoming/` |
| `STORAGE_AWS_ROLE_ARN` | Uses the correct AWS account ID and role name |
| `STORAGE_AWS_IAM_USER_ARN` | Copy exactly into AWS trust policy |
| `STORAGE_AWS_EXTERNAL_ID` | Copy exactly into AWS trust policy |

## 3. Create File Format and Stage

```sql
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
```

Expected result:

- File format `RAW.JSON_FF` exists.
- Stage `RAW.my_s3_stage` exists.
- `LIST @RAW.my_s3_stage` runs successfully.
- If there are no files in S3 yet, `LIST` can return zero rows.

Expected `LIST` output shape when files exist:

| name | size | md5 | last_modified |
|---|---:|---|---|
| `s3://<S3_BUCKET>/incoming/test_events_001.json` | non-zero | hash value | timestamp |
| `s3://<S3_BUCKET>/incoming/test_gravity_patient_events.json` | non-zero | hash value | timestamp |

If the S3 prefix is empty, Snowflake may return no rows. That is acceptable as long as the query completes without an AWS role or permission error.

## 4. Create Snowpipe

```sql
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
```

Expected worksheet result:

| Statement | Expected Output |
|---|---|
| `CREATE OR REPLACE PIPE` | Success message; no table result is required |

Why a transform is used:

The staged JSON file is read as `$1`. The pipe extracts stable top-level fields into relational columns and keeps the full event-specific object in `payload`.

| Expression | Target Column |
|---|---|
| `$1:event_id::STRING` | `event_id` |
| `TRY_TO_TIMESTAMP_NTZ($1:event_time::STRING)` | `event_time` |
| `$1:user_id::STRING` | `user_id` |
| `$1:payload` | `payload` |

## 5. Get Notification Channel

```sql
SHOW PIPES LIKE 'MY_EVENTS_PIPE' IN SCHEMA INGEST_DB.RAW;
```

Copy the `notification_channel` value into the S3 event notification destination.

Expected `SHOW PIPES` fields:

| Field | Expected Value |
|---|---|
| `name` | `MY_EVENTS_PIPE` |
| `database_name` | `INGEST_DB` |
| `schema_name` | `RAW` |
| `owner` | Setup role, commonly `ACCOUNTADMIN` for a trial project |
| `notification_channel` | Snowflake-managed SQS ARN |
| `kind` | `STAGE` |

## Recommended Worksheet Organization

| Worksheet | Script |
|---|---|
| `setup_ingest_db.sql` | `sql/01_setup_ingest_db.sql` |
| `storage_integration.sql` | `sql/02_storage_integration.sql` |
| `external_stage.sql` | `sql/03_external_stage.sql` |
| `snowpipe.sql` | `sql/04_snowpipe.sql` and `sql/05_validation_queries.sql` |
