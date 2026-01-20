CREATE OR REPLACE TABLE `YOUR_PROJECT.analytics.mart_cohorts_retention`
PARTITION BY cohort_date AS
WITH first_seen (user_pseudo_id, cohort_date) AS (
  SELECT
    user_pseudo_id,
    MIN(event_date) AS cohort_date
  FROM `YOUR_PROJECT.analytics.stg_ga4_events`
  GROUP BY 1
),
activity AS (
  SELECT
    f.cohort_date,
    e.user_pseudo_id,
    e.event_date AS activity_date,
    DATE_DIFF(e.event_date, f.cohort_date, DAY) AS day_index
  FROM first_seen f
  JOIN `YOUR_PROJECT.analytics.stg_ga4_events` e
  ON e.user_pseudo_id = f.user_pseudo_id
)
SELECT
  cohort_date,
  day_index,
  COUNT(DISTINCT user_pseudo_id) AS active_users
FROM activity
WHERE day_index BETWEEN 0 AND 60
GROUP BY 1,2
ORDER BY cohort_date, day_index;
