-- 1) Null session id rate (should be low for app/web sessions)
SELECT
  event_date,
  COUNT(*) AS events,
  COUNTIF(ga_session_id IS NULL) AS null_session_events,
  SAFE_DIVIDE(COUNTIF(ga_session_id IS NULL), COUNT(*)) AS null_session_rate
FROM `YOUR_PROJECT.analytics.stg_ga4_events`
GROUP BY 1
ORDER BY 1 DESC;

-- 2) Duplicate session key (should be 0)
SELECT
  session_date,
  user_pseudo_id,
  ga_session_id,
  COUNT(*) AS rows
FROM `YOUR_PROJECT.analytics.int_sessions`
GROUP BY 1,2,3
HAVING COUNT(*) > 1;

-- 3) Partition completeness (days missing)
WITH days AS (
  SELECT day
  FROM UNNEST(GENERATE_DATE_ARRAY('2025-01-01','2025-12-31')) AS day
),
present AS (
  SELECT DISTINCT date AS day
  FROM `YOUR_PROJECT.analytics.mart_funnel_daily`
)
SELECT d.day
FROM days d
LEFT JOIN present p USING(day)
WHERE p.day IS NULL;
