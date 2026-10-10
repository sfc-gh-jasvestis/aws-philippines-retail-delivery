-- ============================================================================
-- 06_INTELLIGENCE.SQL - search, anomaly detection, semantic view, agent,
-- live failed-delivery alert and on-demand refresh DAG.
-- Run with snowflake/run_intelligence.py (substitutes checked __DEMO_DB__ /
-- __DEMO_WH__ / __ALERT_EMAIL__). Requires 00-05, plus 08 (Snowflake only) or
-- aws/setup_aws.py (AWS build) for RAW.LIVE_DELIVERIES.
-- Alerts and tasks are created SUSPENDED; run them with EXECUTE ALERT / EXECUTE TASK.
-- ============================================================================
USE DATABASE __DEMO_DB__;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

-- ---------- Synthetic delivery disruption SOPs (clearly synthetic) ----------
CREATE OR REPLACE TABLE SEARCH.PLAYBOOK_DOCS AS
WITH causes AS (
  SELECT DISTINCT r.DISRUPTION_CAUSE, z.CATEGORY
  FROM RAW.ZONE_DAILY r JOIN RAW.ZONES z ON z.ID = r.ENTITY_ID
  WHERE r.DISRUPTION_HOURS > 0
)
SELECT
  'PLB-' || LPAD(ROW_NUMBER() OVER (ORDER BY CATEGORY, DISRUPTION_CAUSE)::VARCHAR, 3, '0') AS DOC_ID,
  'SOP' AS DOC_TYPE,
  CATEGORY,
  DISRUPTION_CAUSE,
  CATEGORY || ' - ' || DISRUPTION_CAUSE || ' delivery disruption SOP' AS TITLE,
  'Synthetic demo SOP. Service: ' || CATEGORY || '. Disruption cause: ' || DISRUPTION_CAUSE || '. '
  || 'Step 1: open a delivery incident for the zone and hold new same-day promises for it until the incident is triaged. '
  || 'Step 2: ' || CASE
       WHEN DISRUPTION_CAUSE = 'Rider shortage' THEN 'borrow riders from the nearest hub with spare capacity, cap each rider at 45 stops, and move the latest same-day cut-off one hour earlier.'
       WHEN DISRUPTION_CAUSE = 'Monsoon rain' THEN 'issue rain gear checks at dispatch, bag every parcel in a waterproof sleeve, and send customers a revised delivery window by SMS.'
       WHEN DISRUPTION_CAUSE = 'Rider payout delay' THEN 'escalate the late rider payout to courier finance, confirm the settlement date to affected riders in the rider app, and pause new rider incentive campaigns in the zone until it is paid.'
       WHEN DISRUPTION_CAUSE = 'Hub backlog' THEN 'open a second sorting shift, prioritise parcels already past their promise date, and stop accepting new pickups into the hub until the backlog is under one day.'
       WHEN DISRUPTION_CAUSE = 'Address not found' THEN 'send the parcel to the address-verification queue, ask the customer for a landmark and pin by SMS before the next attempt, and update the zone address notes.'
       WHEN DISRUPTION_CAUSE = 'Road flooding' THEN 'mark flooded barangays as no-go in the routing plan, hold parcels at the hub instead of attempting delivery, and reschedule them for the next dry window.'
       WHEN DISRUPTION_CAUSE = 'Customer unreachable' THEN 'call the customer twice before the attempt, offer a pickup point or a rescheduled slot, and keep cash-on-delivery parcels at the hub for up to three attempts.'
       WHEN DISRUPTION_CAUSE = 'Truck shortage' THEN 'book a partner truck for bulky items, consolidate stops by barangay, and notify customers of the new delivery day.'
       WHEN DISRUPTION_CAUSE = 'Ferry cancellation' THEN 'hold inter-island parcels at the origin port hub, rebook them on the next sailing, and tell customers the new estimated arrival date.'
       WHEN DISRUPTION_CAUSE = 'Port congestion' THEN 'move urgent parcels to air cargo where the merchant allows it, and stage the rest at the port hub in order of promise date.'
       WHEN DISRUPTION_CAUSE = 'Typhoon flooding' THEN 'stop all deliveries in the affected city, keep riders off the road until the local advisory is lifted, and send customers a delay notice.'
       ELSE 'review the disruption against the zone profile and escalate if unexplained.'
     END
  || ' Step 3: if failed deliveries in the zone stay above 10% or the average hub-to-door time stays above 14 hours after one day, keep the incident open and request a zone capacity review. '
  || 'Step 4: record the resolution; if rider payouts were late, log it for the weekly courier finance report.' AS CONTENT
FROM causes;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.PLAYBOOK_SEARCH
  ON CONTENT
  ATTRIBUTES CATEGORY, DISRUPTION_CAUSE
  WAREHOUSE = __DEMO_WH__
  TARGET_LAG = '7 days'
AS (SELECT DOC_ID, TITLE, CATEGORY, DISRUPTION_CAUSE, CONTENT FROM SEARCH.PLAYBOOK_DOCS);

-- ---------- Hub-to-door time anomaly detection (train first 75 days, detect last 15) ----------
CREATE OR REPLACE VIEW ML.DELIVERY_HOURS_SERIES AS
SELECT ENTITY_ID, EVENT_DATE::TIMESTAMP_NTZ AS TS, AVG_DELIVERY_HOURS::FLOAT AS DELIVERY_HOURS
FROM RAW.ZONE_DAILY;
CREATE OR REPLACE VIEW ML.DELIVERY_HOURS_TRAIN AS
SELECT * FROM ML.DELIVERY_HOURS_SERIES WHERE TS < (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.DELIVERY_HOURS_SERIES);
CREATE OR REPLACE VIEW ML.DELIVERY_HOURS_DETECT AS
SELECT * FROM ML.DELIVERY_HOURS_SERIES WHERE TS >= (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.DELIVERY_HOURS_SERIES);

CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION ML.DELIVERY_HOURS_ANOMALY_MODEL(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.DELIVERY_HOURS_TRAIN'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'DELIVERY_HOURS',
  LABEL_COLNAME => '');

CREATE OR REPLACE TABLE ML.DELIVERY_HOURS_ANOMALIES AS
SELECT SERIES::VARCHAR AS ENTITY_ID, TS::DATE AS EVENT_DATE, Y AS DELIVERY_HOURS, FORECAST AS EXPECTED,
       LOWER_BOUND, UPPER_BOUND, IS_ANOMALY, PERCENTILE
FROM TABLE(ML.DELIVERY_HOURS_ANOMALY_MODEL!DETECT_ANOMALIES(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.DELIVERY_HOURS_DETECT'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'DELIVERY_HOURS'));

-- ---------- Semantic view ----------
CREATE OR REPLACE SEMANTIC VIEW APP.DELIVERY_ANALYTICS
  TABLES (
    zones AS CURATED.PERFORMANCE_SUMMARY PRIMARY KEY (ENTITY_ID)
      COMMENT = 'One row per delivery zone (one service in one Philippine city), 90-day totals',
    risk AS ML.DISRUPTION_RISK_SCORES PRIMARY KEY (ENTITY_ID)
      COMMENT = 'Latest next-7-day delivery-disruption probability per zone',
    causes AS CURATED.CAUSE_SUMMARY PRIMARY KEY (DISRUPTION_CAUSE)
      COMMENT = 'Disruption zone-days, disruption hours and failed deliveries by disruption cause, 90 days',
    daily AS CURATED.TREND_ANALYSIS PRIMARY KEY (METRIC_DATE)
      COMMENT = 'Network-wide totals per day'
  )
  RELATIONSHIPS (risk_zone AS risk (ENTITY_ID) REFERENCES zones)
  FACTS (
    zones.parcels_f AS PARCEL_COUNT,
    zones.delivered_f AS DELIVERED_COUNT,
    zones.failed_f AS FAILED_COUNT,
    zones.returned_f AS RETURNED_COUNT,
    zones.value_f AS PARCEL_VALUE_PHP,
    zones.disruption_hours_f AS DISRUPTION_HOURS,
    zones.disruption_days_f AS DISRUPTION_DAYS,
    zones.payout_due_f AS PAYOUT_DUE,
    zones.payout_settled_f AS PAYOUT_SETTLED,
    zones.attempts_f AS AVG_ATTEMPTS,
    zones.hours_f AS AVG_DELIVERY_HOURS,
    risk.disruption_prob_f AS DISRUPTION_PROB_7D,
    causes.cause_days_f AS DISRUPTION_DAYS,
    causes.cause_hours_f AS DISRUPTION_HOURS,
    causes.cause_failed_f AS FAILED_COUNT,
    causes.cause_parcels_f AS PARCEL_COUNT,
    daily.day_parcels_f AS PARCEL_COUNT,
    daily.day_delivered_f AS DELIVERED_COUNT,
    daily.day_failed_f AS FAILED_COUNT,
    daily.day_value_f AS PARCEL_VALUE_PHP
  )
  DIMENSIONS (
    zones.zone_id AS ENTITY_ID WITH SYNONYMS = ('zone', 'delivery zone', 'service area'),
    zones.zone_name AS ENTITY_NAME,
    zones.city AS REGION WITH SYNONYMS = ('city', 'region', 'metro area')
      COMMENT = 'Philippine city: Quezon City, Caloocan City, Cebu City, Davao City or Cagayan de Oro City',
    zones.service AS CATEGORY WITH SYNONYMS = ('service', 'service type', 'delivery product')
      COMMENT = 'Same-day, Next-day, Cash on delivery, Bulky item or Inter-island',
    zones.access_tier AS ACCESS_TIER COMMENT = 'Last-mile access difficulty tier 1 (easy) to 3 (hard)',
    risk.risk_band AS RISK_BAND COMMENT = 'High >= 0.5, Medium >= 0.25, else Low',
    risk.scored_as_of AS SCORED_AS_OF,
    causes.disruption_cause AS DISRUPTION_CAUSE WITH SYNONYMS = ('cause', 'disruption reason', 'reason'),
    daily.metric_date AS METRIC_DATE
  )
  METRICS (
    zones.zone_count AS COUNT(zones.zone_id) WITH SYNONYMS = ('number of zones', 'zones monitored', 'entities'),
    zones.delivery_success_pct AS 100 * SUM(zones.delivered_f) / NULLIF(SUM(zones.parcels_f), 0)
      WITH SYNONYMS = ('delivery success rate', 'first-time delivery rate', 'success rate')
      COMMENT = 'Delivered parcels / parcels dispatched',
    zones.return_rate_pct AS 100 * SUM(zones.returned_f) / NULLIF(SUM(zones.parcels_f), 0)
      WITH SYNONYMS = ('return to sender rate', 'refusal rate')
      COMMENT = 'Parcels refused by the customer and returned to sender / parcels dispatched',
    zones.total_parcels AS SUM(zones.parcels_f) WITH SYNONYMS = ('parcels', 'parcel volume', 'dispatched parcels'),
    zones.total_delivered AS SUM(zones.delivered_f) WITH SYNONYMS = ('delivered parcels', 'successful deliveries'),
    zones.total_failed AS SUM(zones.failed_f) WITH SYNONYMS = ('failed deliveries', 'failed attempts', 'returned to hub'),
    zones.total_disruption_hours AS SUM(zones.disruption_hours_f) WITH SYNONYMS = ('disruption hours', 'delivery disruption'),
    zones.total_disruption_days AS SUM(zones.disruption_days_f),
    zones.total_value_php AS SUM(zones.value_f) WITH SYNONYMS = ('parcel value', 'delivered value', 'value in PHP'),
    zones.payout_on_time_pct AS 100 * SUM(zones.payout_settled_f) / NULLIF(SUM(zones.payout_due_f), 0)
      COMMENT = 'Rider payouts settled on time / payouts due',
    zones.mean_attempts AS AVG(zones.attempts_f),
    zones.mean_delivery_hours AS AVG(zones.hours_f),
    risk.avg_disruption_prob AS AVG(risk.disruption_prob_f),
    causes.cause_disruption_days AS SUM(causes.cause_days_f),
    causes.cause_disruption_hours AS SUM(causes.cause_hours_f),
    causes.cause_failed AS SUM(causes.cause_failed_f),
    causes.cause_failed_pct AS 100 * SUM(causes.cause_failed_f) / NULLIF(SUM(causes.cause_parcels_f), 0),
    daily.daily_parcels AS SUM(daily.day_parcels_f),
    daily.daily_delivered AS SUM(daily.day_delivered_f),
    daily.daily_failed AS SUM(daily.day_failed_f),
    daily.daily_value_php AS SUM(daily.day_value_f)
  )
  COMMENT = 'Synthetic Philippine last-mile delivery operations analytics (demo)';

-- ---------- Cortex Agent ----------
CREATE OR REPLACE AGENT APP.DELIVERY_OPS_AGENT
  COMMENT = 'Delivery operations assistant over a synthetic Philippine e-commerce courier network'
  FROM SPECIFICATION
$$
models:
  orchestration: claude-sonnet-4-5
instructions:
  response: "Answer only from tool results. State that data is synthetic. Give zone IDs and numbers with units (PHP, %, hours)."
  orchestration: "Use delivery_analyst for parcels, delivered parcels, delivery success rate, failed deliveries, returns to sender, disruption hours, parcel value, rider payouts, zones, cities, services, disruption causes and disruption risk. Use playbook_search for delivery disruption procedures."
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: delivery_analyst
      description: "Parcels dispatched, delivered parcels, delivery success rate, failed deliveries, returns to sender, delivery disruption hours, parcel value in PHP, rider payout on-time rate, disruption causes and delivery-disruption risk scores by zone, city and service"
  - tool_spec:
      type: cortex_search
      name: playbook_search
      description: "Synthetic delivery disruption SOPs by service and disruption cause"
tool_resources:
  delivery_analyst:
    semantic_view: __DEMO_DB__.APP.DELIVERY_ANALYTICS
    execution_environment:
      type: warehouse
      warehouse: __DEMO_WH__
  playbook_search:
    name: __DEMO_DB__.SEARCH.PLAYBOOK_SEARCH
    max_results: 3
    id_column: DOC_ID
    title_column: TITLE
$$;

-- ---------- Live-delivery alert ----------
CREATE TABLE IF NOT EXISTS APP.ALERT_LOG (
  ALERTED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(), ZONE_ID VARCHAR,
  EVENT_TS TIMESTAMP_NTZ, COD_PHP FLOAT, DWELL_MINUTES FLOAT, PLAYBOOK_HINT VARCHAR);

CREATE OR REPLACE NOTIFICATION INTEGRATION PH_RETAIL_DELIVERY_EMAIL_INT
  TYPE = EMAIL ENABLED = TRUE ALLOWED_RECIPIENTS = ('__ALERT_EMAIL__');

CREATE OR REPLACE PROCEDURE APP.LOG_LIVE_ALERTS()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  n NUMBER;
BEGIN
  INSERT INTO APP.ALERT_LOG (ZONE_ID, EVENT_TS, COD_PHP, DWELL_MINUTES, PLAYBOOK_HINT)
    SELECT t.ZONE_ID, t.EVENT_TS, t.COD_PHP, t.DWELL_MINUTES,
           'Check ' || z.CATEGORY || ' delivery disruption SOPs; current risk band ' || COALESCE(s.RISK_BAND, 'n/a')
    FROM RAW.LIVE_DELIVERIES t
    JOIN RAW.ZONES z ON z.ID = t.ZONE_ID
    LEFT JOIN ML.DISRUPTION_RISK_SCORES s ON s.ENTITY_ID = t.ZONE_ID
    WHERE t.STATUS = 'FAILED'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.ZONE_ID = t.ZONE_ID AND l.EVENT_TS = t.EVENT_TS);
  n := SQLROWCOUNT;
  IF (n > 0) THEN
    CALL SYSTEM$SEND_EMAIL('PH_RETAIL_DELIVERY_EMAIL_INT', '__ALERT_EMAIL__',
      '[Demo] Failed delivery alert',
      'New failed deliveries logged in APP.ALERT_LOG: ' || :n || '. Data is synthetic.');
  END IF;
  RETURN n;
END;
$$;

CREATE OR REPLACE ALERT APP.LIVE_DELIVERY_ALERT
  WAREHOUSE = __DEMO_WH__
  SCHEDULE = '5 MINUTE'
  IF (EXISTS (
    SELECT 1 FROM RAW.LIVE_DELIVERIES t
    WHERE t.STATUS = 'FAILED'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.ZONE_ID = t.ZONE_ID AND l.EVENT_TS = t.EVENT_TS)))
  THEN CALL APP.LOG_LIVE_ALERTS();

-- ---------- On-demand refresh DAG (suspended; run with EXECUTE TASK APP.TASK_REFRESH_CURATED) ----------
CREATE OR REPLACE PROCEDURE APP.REFRESH_CURATED()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
  ALTER DYNAMIC TABLE CURATED.PERFORMANCE_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.TREND_ANALYSIS REFRESH;
  ALTER DYNAMIC TABLE CURATED.CAUSE_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.KPI_SUMMARY REFRESH;
  RETURN 'refreshed';
END;
$$;

CREATE OR REPLACE TASK APP.TASK_REFRESH_CURATED
  WAREHOUSE = __DEMO_WH__
AS
  CALL APP.REFRESH_CURATED();

CREATE OR REPLACE TASK APP.TASK_RESCORE_RISK
  WAREHOUSE = __DEMO_WH__
  AFTER APP.TASK_REFRESH_CURATED
AS
  CREATE OR REPLACE TABLE ML.DISRUPTION_RISK_SCORES COPY GRANTS AS
  WITH latest AS (
    SELECT * FROM ML.DISRUPTION_FEATURES QUALIFY ROW_NUMBER() OVER (PARTITION BY ENTITY_ID ORDER BY EVENT_DATE DESC) = 1
  ), p AS (
    SELECT ENTITY_ID, EVENT_DATE,
           ML.DISRUPTION_RISK_MODEL!PREDICT(INPUT_DATA => OBJECT_CONSTRUCT(
             'CATEGORY', CATEGORY, 'ACCESS_TIER', ACCESS_TIER, 'ZONE_AGE_YEARS', ZONE_AGE_YEARS,
             'AVG_ATTEMPTS', AVG_ATTEMPTS, 'AVG_DELIVERY_HOURS', AVG_DELIVERY_HOURS,
             'DELIVERY_HOURS_7D', DELIVERY_HOURS_7D, 'DISRUPTION_HOURS_30D', DISRUPTION_HOURS_30D)) AS PRED
    FROM latest
  )
  SELECT ENTITY_ID, EVENT_DATE AS SCORED_AS_OF, ROUND(PRED:probability:DISRUPTION::FLOAT, 4) AS DISRUPTION_PROB_7D,
         CASE WHEN PRED:probability:DISRUPTION::FLOAT >= 0.5 THEN 'High'
              WHEN PRED:probability:DISRUPTION::FLOAT >= 0.25 THEN 'Medium' ELSE 'Low' END AS RISK_BAND,
         CURRENT_TIMESTAMP() AS SCORED_AT
  FROM p;
