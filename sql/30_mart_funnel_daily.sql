CREATE OR REPLACE TABLE `YOUR_PROJECT.analytics.mart_funnel_daily`
PARTITION BY date AS
WITH daily AS (
  SELECT
    event_date AS date,
    user_pseudo_id,
    ga_session_id,
    MAX(IF(event_name = 'view_item', 1, 0)) AS did_view_item,
    MAX(IF(event_name = 'add_to_cart', 1, 0)) AS did_add_to_cart,
    MAX(IF(event_name = 'begin_checkout', 1, 0)) AS did_begin_checkout,
    MAX(IF(event_name = 'purchase', 1, 0)) AS did_purchase,
    SUM(IFNULL(revenue_usd, 0)) AS revenue_usd
  FROM `YOUR_PROJECT.analytics.stg_ga4_events`
  WHERE ga_session_id IS NOT NULL
  GROUP BY 1,2,3
)
SELECT
  date,
  COUNT(DISTINCT CONCAT(user_pseudo_id, '-', CAST(ga_session_id AS STRING))) AS sessions,
  SUM(did_view_item) AS sessions_view_item,
  SUM(did_add_to_cart) AS sessions_add_to_cart,
  SUM(did_begin_checkout) AS sessions_begin_checkout,
  SUM(did_purchase) AS sessions_purchase,
  SAFE_DIVIDE(SUM(did_add_to_cart), SUM(did_view_item)) AS view_to_cart_rate,
  SAFE_DIVIDE(SUM(did_begin_checkout), SUM(did_add_to_cart)) AS cart_to_checkout_rate,
  SAFE_DIVIDE(SUM(did_purchase), SUM(did_begin_checkout)) AS checkout_to_purchase_rate,
  SAFE_DIVIDE(SUM(did_purchase), COUNT(DISTINCT CONCAT(user_pseudo_id, '-', CAST(ga_session_id AS STRING)))) AS purchase_per_session,
  SUM(revenue_usd) AS revenue_usd
FROM daily
GROUP BY 1;
