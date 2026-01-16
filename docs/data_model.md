# Data Model (GA4 BigQuery Growth Analytics)

This project builds an analytics layer on top of GA4 BigQuery Export. The model is organized in three layers: staging (standardize raw events), intermediate (derive stable analytical entities such as sessions), and marts (business-ready KPI tables for reporting).

The intended consumption is BI dashboards and ad-hoc analysis. No raw data is included in this repository; the input is assumed to be the standard GA4 export table pattern `events_*`.

## Source

**GA4 Export (raw)**
- Table pattern: `YOUR_PROJECT.YOUR_GA4_DATASET.events_*`
- Granularity: one row per event
- Date handling: `event_date` is provided as `YYYYMMDD` string; `_TABLE_SUFFIX` represents the daily shard

## Output datasets

All curated tables are created in `YOUR_PROJECT.analytics`.

## Entity Overview

| Layer | Table | Purpose | Grain (one row per…) | Primary Key (logical) | Partition |
|---|---|---|---|---|---|
| Staging | `analytics.stg_ga4_events` | Standardized event table extracted from GA4 export with commonly used fields materialized (session id, traffic, ecommerce) | Event | (event_timestamp, user_pseudo_id, event_name) *not strictly unique in GA4; treated as event-level records* | `event_date` |
| Intermediate | `analytics.int_sessions` | Sessionized view derived from events, producing a stable “session” entity used by marts | Session | (session_date, user_pseudo_id, ga_session_id) | `session_date` |
| Mart | `analytics.mart_funnel_daily` | Daily funnel KPI table based on session-level flags for key steps (view → cart → checkout → purchase) | Day | `date` | `date` |
| Mart | `analytics.mart_acquisition_daily` | Daily acquisition KPI table by source/medium/campaign combining sessions and purchase outcomes | Day + channel tuple | (date, source, medium, campaign) | `date` |
| Mart | `analytics.mart_cohorts_retention` | Cohort retention table measuring active users by cohort date and day index | Cohort date + day index | (cohort_date, day_index) | `cohort_date` |

## Table Contracts

### `analytics.stg_ga4_events` (Staging)
This table materializes GA4 fields that are frequently needed for analytics and reporting: `ga_session_id`, `ga_session_number`, traffic dimensions (source/medium/campaign), device and geo, plus ecommerce fields (`transaction_id`, `revenue_usd`).

Staging explicitly selects fields instead of using `SELECT *` to keep the schema stable, reduce query scanning costs, and make downstream logic readable and auditable. The table is partitioned by `event_date` because most event-level queries filter by date ranges.

Key columns:
- `event_date` (DATE): parsed from GA4 `event_date` string
- `event_timestamp` (INT64): GA4 event timestamp in microseconds
- `user_pseudo_id` (STRING): GA4 pseudo user identifier
- `ga_session_id` (INT64): session identifier extracted from `event_params`
- `event_name` (STRING): GA4 event name
- `source`, `medium`, `campaign` (STRING): traffic attribution fields
- `transaction_id` (STRING), `revenue_usd` (NUMERIC/FLOAT): purchase identifiers and revenue

### `analytics.int_sessions` (Intermediate)
This table creates a session entity by grouping events on `(user_pseudo_id, ga_session_id)` and computing session boundaries. It is the foundation for session-level KPIs and is intentionally separated from marts so the session definition is centralized and consistent.

Partitioning by `session_date` optimizes typical reporting queries (daily/weekly/monthly). Logical uniqueness is defined by `(session_date, user_pseudo_id, ga_session_id)`, which supports “one row per session” semantics.

Key columns:
- `session_date` (DATE): session reference date (aligned to event_date from GA4 export for the session)
- `session_start_time`, `session_end_time` (TIMESTAMP): derived from min/max event timestamps
- `session_duration_seconds` (FLOAT): computed duration (safe handling)
- `device_category`, `country`, `source`, `medium`, `campaign`: session descriptors
- `pageviews`, `events`: session activity measures

### `analytics.mart_funnel_daily` (Mart)
This mart is designed for executive dashboards and growth analysis. It aggregates sessions per day and computes funnel progression using session-level binary flags. A session is counted once per funnel step regardless of repeated events (e.g., multiple add_to_cart events in the same session).

Partitioning by `date` supports efficient time-series dashboard queries and incremental refresh patterns.

Key outputs:
- `sessions`: number of sessions per day
- `sessions_view_item`, `sessions_add_to_cart`, `sessions_begin_checkout`, `sessions_purchase`
- Step conversion rates (safe division to avoid errors)
- `revenue_usd`

### `analytics.mart_acquisition_daily` (Mart)
This mart is designed to connect acquisition with outcomes. It combines session counts from `int_sessions` with purchase and revenue information from the event layer. The join is performed on `(date, source, medium, campaign)` to produce a reporting-ready channel performance table.

A FULL OUTER JOIN is used to avoid dropping records in cases of tracking gaps or partial data (e.g., sessions without purchase rows, or purchase events without sessionized sessions). This design makes data issues visible rather than silently excluding them.

Key outputs:
- `sessions`, `purchases`, `revenue_usd`
- `purchase_rate_per_session`, `revenue_per_session`

### `analytics.mart_cohorts_retention` (Mart)
This mart provides a cohort-based retention view. The cohort date is defined as the first observed event date for a user (`MIN(event_date)`), and retention is measured as the number of distinct active users at each `day_index` after the cohort date.

The output is shaped for cohort heatmaps and retention curves. The default horizon is limited (e.g., 60 days) to balance usefulness and cost.

Key outputs:
- `cohort_date` (DATE)
- `day_index` (INT64): days since cohort date
- `active_users` (INT64)

## Lineage

Raw GA4 export → `stg_ga4_events` → `int_sessions` → marts:
- `mart_funnel_daily` uses `stg_ga4_events` (session-level flags derived per day)
- `mart_acquisition_daily` uses `int_sessions` for sessions and `stg_ga4_events` for purchases/revenue
- `mart_cohorts_retention` uses `stg_ga4_events` for first seen + subsequent activity

## Performance Considerations

Partitioning is applied to all derived tables on their primary time dimension (event_date/session_date/date/cohort_date) to reduce scan cost and improve dashboard performance. The design is compatible with incremental rebuild strategies and dbt-style layering, while remaining tool-agnostic.

## Known Limitations (high level)

This model assumes the presence and reliability of `ga_session_id` in GA4 export. Attribution fields in GA4 can vary depending on implementation and consent mode; acquisition marts should be interpreted accordingly. Cohorts are “first seen” cohorts unless a true signup/customer creation timestamp is provided.
