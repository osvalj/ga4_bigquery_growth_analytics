CREATE OR REPLACE TABLE `YOUR_PROJECT.analytics.stg_ga4_events`
PARTITION BY event_date AS
SELECT
  PARSE_DATE('%Y%m%d', event_date) AS event_date,
  event_timestamp,
  user_pseudo_id,
  (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS ga_session_id,
  (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_number') AS ga_session_number,
  event_name,
  platform,
  device.category AS device_category,
  geo.country AS country,
  traffic_source.source AS source,
  traffic_source.medium AS medium,
  traffic_source.name AS campaign,
  ecommerce.purchase_revenue_in_usd AS revenue_usd,
  ecommerce.transaction_id AS transaction_id
FROM `YOUR_PROJECT.YOUR_GA4_DATASET.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20250101' AND '20251231';
