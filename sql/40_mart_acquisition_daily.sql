CREATE OR REPLACE TABLE `YOUR_PROJECT.analytics.mart_acquisition_daily`
PARTITION BY date AS
WITH s AS (
  SELECT
    session_date AS date,
    source,
    medium,
    campaign,
    COUNT(*) AS sessions
  FROM `YOUR_PROJECT.analytics.int_sessions`
  GROUP BY 1,2,3
),
p AS (
  SELECT
    event_date AS date,
    source,
    medium,
    campaign,
    COUNTIF(event_name = 'purchase') AS purchases,
    SUM(IFNULL(revenue_usd, 0)) AS revenue_usd
  FROM `YOUR_PROJECT.analytics.stg_ga4_events`
  GROUP BY 1,2,3
)
SELECT
  COALESCE(s.date, p.date) AS date,
  COALESCE(s.source, p.source) AS source,
  COALESCE(s.medium, p.medium) AS medium,
  COALESCE(s.campaign, p.campaign) AS campaign,
  IFNULL(s.sessions, 0) AS sessions,
  IFNULL(p.purchases, 0) AS purchases,
  IFNULL(p.revenue_usd, 0) AS revenue_usd,
  SAFE_DIVIDE(IFNULL(p.purchases, 0), NULLIF(IFNULL(s.sessions, 0), 0)) AS purchase_rate_per_session,
  SAFE_DIVIDE(IFNULL(p.revenue_usd, 0), NULLIF(IFNULL(s.sessions, 0), 0)) AS revenue_per_session
FROM s
FULL OUTER JOIN p
USING(date, source, medium, campaign);
