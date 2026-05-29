# Data Contract

This document defines the event structure expected by the Snowpipe ingestion pipeline.

## Contract Purpose

The data contract makes the ingestion pattern predictable. Snowpipe can load flexible JSON, but the top-level fields must remain stable so downstream analytics can identify, sort, and group events consistently.

## Target Table

```sql
CREATE OR REPLACE TABLE RAW.EVENTS (
  event_id STRING,
  event_time TIMESTAMP,
  user_id STRING,
  payload VARIANT
);
```

## Required Fields

Every JSON record should include:

| Field | Type | Required | Description |
|---|---|---|---|
| `event_id` | string | Yes | Unique event identifier |
| `event_time` | string timestamp | Yes | Event timestamp in ISO-like format |
| `user_id` | string | Yes | User, service, device, or actor that produced the event |
| `payload` | object | Yes | Semi-structured event detail |

## Recommended Payload Fields

| Field | Type | Description |
|---|---|---|
| `event_type` | string | Business event type |
| `source_system` | string | Upstream system, such as `gravity`, `claims_feed`, `website`, or `mobile_app` |
| `patient_id` | string | Healthcare patient identifier when applicable |
| `provider_id` | string | Provider identifier when applicable |
| `facility_id` | string | Facility identifier when applicable |
| `claim_id` | string | Claim identifier when applicable |
| `appointment_id` | string | Appointment identifier when applicable |
| `campaign_id` | string | Outreach campaign identifier when applicable |

## Example Event

```json
{
  "event_id": "gap-20260529-5101",
  "event_time": "2026-05-29T09:02:15",
  "user_id": "quality-engine-01",
  "payload": {
    "event_type": "care_gap_identified",
    "source_system": "gravity",
    "patient_id": "P-900143",
    "measure_id": "HBD",
    "measure_name": "HbA1c Poor Control",
    "gap_status": "open",
    "priority": "high"
  }
}
```

## Design Rationale

The target table keeps core event fields as first-class columns and stores the rest of the data in `payload`.

This allows:

- Flexible ingestion across multiple event types.
- Compatibility with changing upstream schemas.
- Later transformation into curated dimensional or analytics models.
- Easy connection to healthcare workflow systems such as care gap, outreach, claims, and appointment modules.

## Event Families

| Event Family | Example Event Types | Common Identifiers |
|---|---|---|
| Patient | `patient_profile_updated`, `patient_enrolled_in_program` | `patient_id`, `program_id` |
| Care Gap | `care_gap_identified`, `care_gap_closed`, `care_gap_reassigned` | `patient_id`, `measure_id`, `provider_id` |
| Appointment | `appointment_scheduled`, `appointment_cancelled` | `appointment_id`, `patient_id`, `provider_id` |
| Claims | `claim_received`, `claim_adjudicated` | `claim_id`, `patient_id`, `payer` |
| Provider | `provider_panel_updated`, `provider_capacity_changed` | `provider_id`, `facility_id` |
| Outreach | `outreach_sent`, `outreach_response_received`, `outreach_failed` | `campaign_id`, `patient_id`, `channel` |

## Data Quality Expectations

- `event_id` should be unique.
- `event_time` should parse into a Snowflake timestamp.
- `payload` should be valid JSON.
- `payload:event_type` should be present for operational reporting.
- Healthcare identifiers in test data are synthetic and should not contain real PHI.

## Compatibility Notes

Files other than JSON can be ingested by Snowpipe, including CSV and Parquet, but this repository is optimized for JSON because healthcare workflow events often have variable shapes. To use another file type, create a different file format and adjust the pipe's `COPY INTO` transformation.
