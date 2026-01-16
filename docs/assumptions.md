# Assumptions & Design Decisions

This document describes the main assumptions, constraints, and design decisions made in this project. The goal is to make the analytical logic explicit, transparent, and defensible in real-world scenarios.

The project is designed as a portfolio example that mirrors production-grade analytics practices while remaining tool-agnostic.

---

## 1. Data Source Assumptions (GA4 Export)

This project assumes a standard Google Analytics 4 (GA4) export to BigQuery with the following characteristics:

- One table per day using the pattern `events_YYYYMMDD`
- One row per event
- Core identifiers available:
  - `user_pseudo_id`
  - `event_timestamp`
  - `event_name`
  - `event_params`
  - `traffic_source`
  - `device`, `geo`, `ecommerce`

No raw GA4 data is included in this repository for privacy and confidentiality reasons.

---

## 2. User Identification

- The primary user identifier used is `user_pseudo_id`
- A true `user_id` (logged-in user) is not assumed to be available
- As a result:
  - Users may be over-counted across devices
  - Cohorts represent “first seen” users, not necessarily first registration

This reflects a common real-world limitation in GA4 implementations.

---

## 3. Session Definition

GA4 does not provide a session table by default. Sessions are reconstructed using:

- `user_pseudo_id`
- `ga_session_id` extracted from `event_params`

A session is defined as:
> All events sharing the same `(user_pseudo_id, ga_session_id)` pair.

Session boundaries:
- Session start = minimum `event_timestamp`
- Session end = maximum `event_timestamp`

Sessions with `ga_session_id IS NULL` are excluded from the session table, as they cannot be reliably sessionized.

This decision prioritizes data consistency over completeness.

---

## 4. Session Attributes (Device, Geo, Traffic)

Session-level attributes such as:
- `device_category`
- `country`
- `source`
- `medium`
- `campaign`

are assigned using `ANY_VALUE()` within the session.

Assumption:
- These attributes are stable within a session in the majority of GA4 implementations.

Trade-off:
- If attributes change mid-session, this approach may introduce minor inaccuracies.
- The alternative (first-touch per session) adds complexity without significant analytical gain for this use case.

---

## 5. Attribution Logic

Attribution in this project is intentionally simplified:

- Acquisition dimensions (`source`, `medium`, `campaign`) are taken directly from GA4 event-level traffic fields
- No custom attribution model (first-click, last-click, data-driven) is implemented

Rationale:
- The focus is on data modeling and KPI construction, not attribution modeling
- This mirrors many real-world BI layers where attribution is handled upstream or in dedicated tools

---

## 6. Funnel Logic

Funnels are calculated at the session level.

Assumptions:
- A funnel step is considered completed if at least one corresponding event occurred in the session
- Multiple occurrences of the same event within a session are counted once

Example:
- A session with multiple `add_to_cart` events is still counted as a single session reaching that step

This avoids inflating funnel metrics and aligns with how business stakeholders typically interpret funnel progression.

---

## 7. Revenue Handling

Revenue is sourced from:
- `ecommerce.purchase_revenue_in_usd`

Assumptions:
- Revenue values are correctly populated in GA4
- Refunds, cancellations, and partial refunds are not explicitly modeled
- Revenue is attributed to the session/day in which the purchase event occurred

This is a common simplification in analytics layers unless a dedicated financial system is integrated.

---

## 8. Cohort Definition

Cohorts are defined using a **first seen** approach:

- `cohort_date = MIN(event_date)` per `user_pseudo_id`

Retention is measured as:
- User activity on subsequent days relative to the cohort date

Assumptions:
- Any event counts as “active”
- Retention window is limited (e.g., 60 days) to balance insight and cost

This approach is suitable when no explicit signup or account creation timestamp is available.

---

## 9. Time Handling

- All reporting tables are partitioned by their primary date dimension
- Dates are treated as calendar dates, not timezone-adjusted session times

Assumption:
- GA4 export timezone is acceptable for business reporting purposes

Timezone normalization is intentionally omitted to keep the model simple and broadly applicable.

---

## 10. Data Quality Philosophy

This project includes explicit data quality checks focusing on:

- Missing session identifiers
- Duplicate session records
- Missing partition dates

The goal is not to enforce strict constraints, but to:
- Surface potential data issues
- Make data reliability visible to analysts and stakeholders

This reflects a pragmatic approach commonly used in analytics teams.

---

## 11. Performance & Cost Considerations

Design decisions prioritize:
- Partition pruning through date-based partitioning
- Minimal column selection in staging tables
- Separation of transformation layers to avoid repeated heavy joins

The model is compatible with incremental builds and dbt-style workflows, although dbt is not required.

---

## 12. Known Limitations

- Cross-device user unification is not addressed
- Consent mode impacts are not modeled
- Offline conversions and CRM data are not integrated
- Attribution is simplified

These limitations are acknowledged and considered acceptable for the scope of this project.

---

## 13. Intended Use

This project is intended as:
- A portfolio demonstration of analytics engineering principles
- A realistic example of GA4-based analytics modeling
- A foundation that can be extended with additional data sources or tooling

It is not intended to be a production-ready drop-in solution without adaptation.
