# GA4 BigQuery Growth Analytics (SQL-only)

This project builds a small analytics layer on top of GA4 BigQuery Export:
- Standardized events (staging)
- Sessionization (intermediate)
- Daily funnel + acquisition marts
- Cohort retention mart
- Data quality checks

## Tech
- BigQuery (GoogleSQL / Standard SQL)
- SQL only (no dbt required, but dbt-friendly structure)

## Input tables
Expected GA4 export tables:
- `project.dataset.events_*` (GA4 export)

## Output tables
- `analytics.stg_ga4_events`
- `analytics.int_sessions`
- `analytics.mart_funnel_daily`
- `analytics.mart_acquisition_daily`
- `analytics.mart_cohorts_retention`

## How to run
1. Edit variables in `sql/00_setup.sql`
2. Run scripts in order: `00_ → 10_ → 20_ → 30_ → 40_ → 50_ → 60_`

## Notes
- Includes pragmatic quality checks (duplicate keys, null rates, date completeness).
- Optimized for partitioned outputs.