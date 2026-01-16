CREATE OR REPLACE TABLE `YOUR_PROJECT.analytics.int_sessions`
PARTITION BY session_date AS
WITH base AS (
  SELECT
    event_date AS session_date,
    user_pseudo_id,
    ga_session_id,
    MIN(event_timestamp) AS session_start_ts,
    MAX(event_timestamp) AS session_end_ts,
    ANY_VALUE(device_category) AS device_category,
    ANY_VALUE(country) AS country,
    ANY_VALUE(source) AS source,
    ANY_VALUE(medium) AS medium,
    ANY_VALUE(campaign) AS campaign,
    COUNTIF(event_name = 'page_view') AS pageviews,
    COUNT(*) AS events
  FROM `YOUR_PROJECT.analytics.stg_ga4_events`
  WHERE ga_session_id IS NOT NULL
  GROUP BY 1,2,3
)
SELECT
  session_date,
  user_pseudo_id,
  ga_session_id,
  TIMESTAMP_MICROS(session_start_ts) AS session_start_time,
  TIMESTAMP_MICROS(session_end_ts) AS session_end_time,
  SAFE_DIVIDE(session_end_ts - session_start_ts, 1000000) AS session_duration_seconds,
  device_category,
  country,
  source,
  medium,
  campaign,
  pageviews,
  events
FROM base;
