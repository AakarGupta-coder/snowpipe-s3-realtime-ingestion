# Testing and Validation Guide

This guide describes how to test the pipeline with the included JSON files.

## Goal

The goal of testing is to prove the full event-driven path:

```text
local test file -> S3 incoming/ -> S3 notification -> Snowpipe -> RAW.EVENTS
```

## Test Data Location

Local folder:

```text
test-data/
```

S3 destination:

```text
s3://<S3_BUCKET>/incoming/
```

## Included Test Volume

The repository includes 13 JSON test files and 27 expected event rows.

| Category | Files | Rows |
|---|---:|---:|
| Baseline tests | 3 | 4 |
| Gravity-style healthcare events | 6 | 14 |
| Real-life operational events | 4 | 9 |
| Total | 13 | 27 |

## Upload Process

Upload every `test_*.json` file to the S3 `incoming/` prefix.

You can upload through the AWS Console or AWS CLI:

```bash
aws s3 cp test-data/ s3://<S3_BUCKET>/incoming/ --recursive --exclude "*" --include "test_*.json"
```

## Validation Queries

### Pipe Status

```sql
SELECT SYSTEM$PIPE_STATUS('INGEST_DB.RAW.MY_EVENTS_PIPE');
```

Expected healthy output normally contains:

```json
{
  "executionState": "RUNNING",
  "pendingFileCount": 0
}
```

The exact JSON can vary by Snowflake account and timing. The important signs are that the pipe is running and pending files are not stuck.

### Total Rows

```sql
SELECT COUNT(*) AS total_loaded_rows
FROM INGEST_DB.RAW.EVENTS;
```

Expected result for a clean table:

| total_loaded_rows |
|---:|
| 27 |

If the table already contains older test data, the count can be higher. For a clean demo, truncate the table first.

### Event Type Breakdown

```sql
SELECT
  payload:event_type::STRING AS event_type,
  payload:source_system::STRING AS source_system,
  COUNT(*) AS event_count
FROM INGEST_DB.RAW.EVENTS
GROUP BY 1, 2
ORDER BY event_count DESC, event_type;
```

Expected output shape:

| event_type | source_system | event_count |
|---|---|---:|
| `care_gap_identified` | `gravity` | `>= 1` |
| `care_gap_closed` | `gravity` | `>= 1` |
| `appointment_scheduled` | `gravity` | `>= 1` |
| `claim_received` | `claims_feed` | `>= 1` |
| `outreach_sent` | `gravity` | `>= 1` |
| `sensor_reading` | nullable or app-defined | `>= 1` |

### Healthcare Event View

```sql
SELECT
  event_id,
  event_time,
  user_id,
  payload:event_type::STRING AS event_type,
  payload:source_system::STRING AS source_system,
  payload:patient_id::STRING AS patient_id,
  payload:provider_id::STRING AS provider_id,
  payload
FROM INGEST_DB.RAW.EVENTS
WHERE payload:source_system::STRING IN ('gravity', 'claims_feed')
ORDER BY event_time DESC;
```

Expected output should show Gravity-style healthcare rows with patient, provider, care gap, appointment, outreach, or claims information in the `payload` column.

### Copy History

```sql
SELECT *
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
  TABLE_NAME => 'EVENTS',
  START_TIME => DATEADD(HOUR, -2, CURRENT_TIMESTAMP())
))
ORDER BY LAST_LOAD_TIME DESC;
```

Expected signs:

| Output Area | Expected Signal |
|---|---|
| File name/location | Files from the S3 `incoming/` prefix are listed |
| Status | Loads show success instead of repeated errors |
| Row count | Uploaded test files have non-zero loaded rows |
| Last load time | Timestamps align with the recent test upload |

## Clean Re-Test

For a clean repeatable demo, truncate the table before uploading a fresh batch:

```sql
TRUNCATE TABLE INGEST_DB.RAW.EVENTS;
```

Expected result immediately after truncation:

| total_loaded_rows |
|---:|
| 0 |

Then upload files again under new object names or clear Snowpipe load metadata according to your test approach.

## Expected Event Type Examples

After loading the full test set, event types should include values like:

| Event Type | Source System | Business Meaning |
|---|---|---|
| `patient_profile_updated` | `gravity` | Patient risk or profile attributes changed |
| `patient_enrolled_in_program` | `gravity` | Patient enrolled into a care program |
| `care_gap_identified` | `gravity` | A quality or care gap was opened |
| `care_gap_closed` | `gravity` | A care gap was resolved |
| `appointment_scheduled` | `gravity` | A patient visit was scheduled |
| `claim_received` | `claims_feed` | A claim record arrived |
| `outreach_sent` | `gravity` | A patient campaign message was sent |
| `order_placed` | nullable or app-defined | A real-life order event was loaded |
| `sensor_reading` | nullable or app-defined | An IoT device emitted telemetry |

## Recommended Demo Query

```sql
SELECT
  payload:event_type::STRING AS event_type,
  COUNT(*) AS rows_loaded
FROM INGEST_DB.RAW.EVENTS
GROUP BY 1
ORDER BY rows_loaded DESC, event_type;
```

Expected result: a compact distribution of the loaded event types. For a clean upload of all included files, the grouped counts should add up to `27`.
