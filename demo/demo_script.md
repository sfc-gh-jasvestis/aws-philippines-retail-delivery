# Last-Mile Delivery Operations

**Philippines - E-Commerce Courier**
Use case: Failed deliveries, delivery disruptions and rider capacity risk

> Operations monitoring for 40 delivery zones of a fictional Philippine e-commerce courier across Quezon City, Caloocan City, Cebu City, Davao City and Cagayan de Oro City: dynamic tables, a holdout-evaluated delivery-disruption classifier, a failed-delivery forecast and grounded AI answers.

## Why Snowflake

- **Dynamic tables** reconcile parcels dispatched, delivered parcels, failed deliveries, returns to sender, disruption hours and rider payout timeliness from RAW zone data, with checks in `run_core.py`
- **Delivery-disruption classification** gives a holdout-evaluated next-7-day probability per zone
- **Failed-delivery forecast** projects 14 days of network-wide failed deliveries with prediction intervals, for rider capacity planning
- **Grounded AI**: the Cortex Agent (Analyst over a semantic view, plus Search over SOPs) shows its SQL and SOP citations
- **Live delivery attempts**: a native simulator (Snowflake only) or Firehose, S3 and Snowpipe (AWS build), then an alert and email

## What is built

| | |
|---|---|
| Dimension table | `RAW.ZONES` (40 rows) |
| Fact table | `RAW.ZONE_DAILY` (3,600 zone-days, 90 days) |
| Curated layer | `CURATED.KPI_SUMMARY`, `PERFORMANCE_SUMMARY`, `CAUSE_SUMMARY`, `TREND_ANALYSIS` |
| ML | `ML.DISRUPTION_RISK_SCORES`, `ML.DISRUPTION_RISK_HOLDOUT_METRICS`, `ML.FAILED_FORECAST`, `ML.DELIVERY_HOURS_ANOMALIES` |

Cities: Quezon City, Caloocan City, Cebu City, Davao City, Cagayan de Oro City. Services: Same-day, Next-day, Cash on delivery, Bulky item, Inter-island.
The courier is fictional; values are in PHP.

## KPI cards (live from `CURATED.KPI_SUMMARY`; no fallback values)

| Card | Value from the seeded data |
|---|---|
| Delivery Success Rate | 93.7% |
| Failed Deliveries | 183,291 |
| Delivery Disruption Hours | 493 |
| Return to Sender Rate | 3.2% |
| Disruption Zone-Days | 167 |
| Delivered Value (PHP M) | 5,338 |
| Parcels Delivered | 5,603,603 |
| Rider Payout On-Time Rate | 77.9% |
| Zones Monitored | 40 |
| Rider Document Coverage | 58.7% |
| Rider Documents Pending | 26 |

Values are synthetic. A rebuild reproduces them because the data is HASH-seeded; dates are relative to the build day.

## Demo flow

1. Executive Cockpit: KPIs, daily failed deliveries, delivery disruption by cause, zone table
2. Predictive: holdout metrics, risk bands, 14-day failed-delivery forecast, hub-to-door time anomalies
3. Controls: rider payout on-time rate, rider document coverage and pending checks, payout on-time rate against disruption hours, then generate the action memo
4. Live Deliveries: run `CALL APP.SIMULATE_DELIVERIES(20)` (Snowflake only) or `python aws/publish_deliveries.py --count 20` (AWS build). Then run `EXECUTE ALERT APP.LIVE_DELIVERY_ALERT` and show the alert log and email.
5. Ask AI: the Cortex Agent answers metric questions through the semantic view and cites SOPs from Cortex Search. The SQL is shown.
6. QuickSight (AWS build): the same Snowflake tables through DIRECT_QUERY
7. Architecture: both builds side by side

## Talking points

- 93.7% of dispatched parcels are delivered; the 183,291 failed deliveries that go back to the hub are where last-mile operations time goes.
- Hub backlog causes the most disruption hours (112 of 493). The two typhoon flooding days hit every zone in Quezon City or Cebu City at once.
- The risk model is evaluated on a time-based holdout: precision 0.40 and recall 0.41 at 0.5, against a 0.21 base rate. Present it as triage, not a verdict.
- Typhoon flooding days are excluded from model training, because they are not zone-driven.

## Business impact

Use only the sourced references in `README.md` (Business Impact).
