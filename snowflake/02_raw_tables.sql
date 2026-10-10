-- Synthetic zone-day observations for a fictional Philippine e-commerce
-- courier. A delivery zone is one service (same-day, next-day, cash on
-- delivery, bulky item, inter-island) in one Philippine city service area.
-- Nothing is seeded as a prediction. Randomness is HASH-seeded, so every rebuild
-- is reproducible: per-zone disruption propensity, rider capacity drift between rider
-- payouts, late payouts, service-weighted disruption causes, and two
-- city-wide typhoon flooding days.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

CREATE TABLE RAW.ZONES AS
WITH zones AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS ZONE_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 40))
), draws AS (
  SELECT ZONE_INDEX,
         MOD(ABS(HASH(ZONE_INDEX, 'phrd-age')), 1000000) / 1e6 AS U_AGE,
         MOD(ABS(HASH(ZONE_INDEX, 'phrd-rate')), 1000000) / 1e6 AS U_RATE,
         MOD(ABS(HASH(ZONE_INDEX, 'phrd-payout')), 1000000) / 1e6 AS U_PAYOUT,
         MOD(ABS(HASH(ZONE_INDEX, 'phrd-discipline')), 1000000) / 1e6 AS U_DISCIPLINE,
         MOD(ABS(HASH(ZONE_INDEX, 'phrd-tier')), 1000000) / 1e6 AS U_TIER
  FROM zones
), labelled AS (
  SELECT *,
         -- Deterministic spread (5 and 8 are coprime): every city and service is present.
         CASE MOD(ZONE_INDEX, 5) WHEN 0 THEN 'Quezon City' WHEN 1 THEN 'Caloocan City'
              WHEN 2 THEN 'Cebu City' WHEN 3 THEN 'Davao City' ELSE 'Cagayan de Oro City' END AS CITY,
         CASE MOD(ZONE_INDEX, 8) WHEN 0 THEN 'Same-day' WHEN 1 THEN 'Same-day'
              WHEN 2 THEN 'Same-day' WHEN 3 THEN 'Next-day' WHEN 4 THEN 'Next-day'
              WHEN 5 THEN 'Cash on delivery' WHEN 6 THEN 'Bulky item' ELSE 'Inter-island' END AS SERVICE
  FROM draws
)
SELECT 'ZON-' || LPAD(ZONE_INDEX::VARCHAR, 4, '0') AS ID,
       CITY || ' ' || SERVICE || ' zone ' || LPAD(ZONE_INDEX::VARCHAR, 4, '0') AS NAME,
       CITY AS REGION, SERVICE AS CATEGORY, ZONE_INDEX,
       1 + FLOOR(U_TIER * 3) AS ACCESS_TIER,
       ROUND(0.2 + U_AGE * 5.8, 1) AS ZONE_AGE_YEARS,
       -- Base daily probability of a delivery disruption 0.5%-2.9%; ~14% of zones are
       -- chronically hard to serve (x3).
       (0.005 + U_RATE * 0.024) * IFF(U_RATE > 0.86, 3, 1) AS BASE_DISRUPTION_RATE,
       7 * (1 + FLOOR(U_PAYOUT * 3)) AS PAYOUT_INTERVAL_DAYS,
       0.58 + U_DISCIPLINE * 0.4 AS PAYOUT_ON_TIME_PROB,
       'Active' AS STATUS
FROM labelled;

CREATE TABLE RAW.ZONE_DAILY AS
WITH days AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS DAY_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 90))
), city_events AS (
  -- Two city-wide typhoon flooding days; every zone in the city loses 5 delivery hours.
  SELECT * FROM VALUES (31, 'Quezon City'), (68, 'Cebu City') AS o(DAY_INDEX, REGION)
), base AS (
  SELECT z.ID AS ENTITY_ID, z.ZONE_INDEX, z.CATEGORY, z.REGION, z.ZONE_AGE_YEARS,
         z.BASE_DISRUPTION_RATE, z.PAYOUT_INTERVAL_DAYS, z.PAYOUT_ON_TIME_PROB,
         d.DAY_INDEX,
         DATEADD('day', d.DAY_INDEX - 89, CURRENT_DATE()) AS EVENT_DATE,
         MOD(d.DAY_INDEX + z.ZONE_INDEX * 3, z.PAYOUT_INTERVAL_DAYS) AS DAYS_SINCE_PAYOUT,
         MOD(ABS(HASH(z.ID, d.DAY_INDEX, 'phrd-short')), 1000000) / 1e6 AS U_SHORT,
         MOD(ABS(HASH(z.ID, d.DAY_INDEX, 'phrd-detect')), 1000000) / 1e6 AS U_DETECT,
         MOD(ABS(HASH(z.ID, d.DAY_INDEX, 'phrd-hours')), 1000000) / 1e6 AS U_HOURS,
         MOD(ABS(HASH(z.ID, d.DAY_INDEX, 'phrd-cause')), 1000000) / 1e6 AS U_CAUSE,
         MOD(ABS(HASH(z.ID, d.DAY_INDEX, 'phrd-done')), 1000000) / 1e6 AS U_DONE,
         MOD(ABS(HASH(z.ID, d.DAY_INDEX, 'phrd-volume')), 1000000) / 1e6 AS U_VOLUME,
         MOD(ABS(HASH(z.ID, d.DAY_INDEX, 'phrd-noise')), 1000000) / 1e6 AS U_NOISE,
         e.REGION IS NOT NULL AS CITY_EVENT
  FROM RAW.ZONES z CROSS JOIN days d
  LEFT JOIN city_events e ON e.DAY_INDEX = d.DAY_INDEX AND e.REGION = z.REGION
), payouts AS (
  SELECT *,
         IFF(DAYS_SINCE_PAYOUT = 0, 1, 0) AS PAYOUT_DUE,
         IFF(DAYS_SINCE_PAYOUT = 0 AND U_DONE < PAYOUT_ON_TIME_PROB, 1, 0) AS PAYOUT_SETTLED,
         -- Rider capacity drifts down between rider payouts; late payouts
         -- carry the drift over.
         DAYS_SINCE_PAYOUT / PAYOUT_INTERVAL_DAYS + (1 - PAYOUT_ON_TIME_PROB) AS DRIFT
  FROM base
), risk AS (
  SELECT *,
         CASE WHEN U_SHORT < LEAST(0.5, BASE_DISRUPTION_RATE * (0.4 + 1.6 * DRIFT) * (1 + 1 / (1 + ZONE_AGE_YEARS))) / 4 THEN 2
              WHEN U_SHORT < LEAST(0.5, BASE_DISRUPTION_RATE * (0.4 + 1.6 * DRIFT) * (1 + 1 / (1 + ZONE_AGE_YEARS))) THEN 1
              ELSE 0 END AS DISRUPTION_RISK
  FROM payouts
), disruptions AS (
  SELECT *,
         -- About 82% of at-risk days turn into measured disruption hours; spare
         -- riders from nearby hubs absorb the rest.
         IFF(CITY_EVENT, 5, IFF(U_DETECT < 0.82, DISRUPTION_RISK * (1 + FLOOR(U_HOURS * 3)), 0)) AS DISRUPTION_HOURS
  FROM risk
), measured AS (
  SELECT *,
         ROUND(CASE CATEGORY WHEN 'Same-day' THEN 1850 WHEN 'Next-day' THEN 2700
                             WHEN 'Cash on delivery' THEN 1450 WHEN 'Bulky item' THEN 260 ELSE 540 END
               * (0.75 + 0.5 * U_VOLUME) * (1 + 0.12 * DISRUPTION_RISK)) AS PARCEL_COUNT,
         CASE CATEGORY WHEN 'Same-day' THEN 680 WHEN 'Next-day' THEN 940
                       WHEN 'Cash on delivery' THEN 1180 WHEN 'Bulky item' THEN 4300 ELSE 1560 END
           * (0.85 + 0.3 * U_NOISE) * (1 + 0.02 * DISRUPTION_HOURS) AS AVG_VALUE_PHP
  FROM disruptions
), outcomes AS (
  SELECT *,
         ROUND(PARCEL_COUNT * (0.018 + 0.012 * DRIFT + 0.028 * DISRUPTION_HOURS)) AS FAILED_COUNT,
         ROUND(PARCEL_COUNT * (0.022 + 0.018 * U_NOISE + 0.005 * DISRUPTION_HOURS)) AS RETURNED_COUNT
  FROM measured
)
SELECT ENTITY_ID || '-' || TO_CHAR(EVENT_DATE, 'YYYYMMDD') AS EVENT_ID,
       ENTITY_ID, EVENT_DATE,
       PARCEL_COUNT,
       PARCEL_COUNT - FAILED_COUNT - RETURNED_COUNT AS DELIVERED_COUNT,
       FAILED_COUNT, RETURNED_COUNT,
       ROUND((PARCEL_COUNT - FAILED_COUNT - RETURNED_COUNT) * AVG_VALUE_PHP) AS PARCEL_VALUE_PHP,
       DISRUPTION_HOURS,
       CASE WHEN DISRUPTION_HOURS = 0 THEN 'None'
            WHEN CITY_EVENT THEN 'Typhoon flooding'
            WHEN CATEGORY = 'Same-day' THEN IFF(U_CAUSE < 0.45, 'Rider shortage', IFF(U_CAUSE < 0.8, 'Monsoon rain', 'Rider payout delay'))
            WHEN CATEGORY = 'Next-day' THEN IFF(U_CAUSE < 0.4, 'Hub backlog', IFF(U_CAUSE < 0.75, 'Address not found', 'Road flooding'))
            WHEN CATEGORY = 'Cash on delivery' THEN IFF(U_CAUSE < 0.55, 'Customer unreachable', 'Rider payout delay')
            WHEN CATEGORY = 'Bulky item' THEN IFF(U_CAUSE < 0.5, 'Truck shortage', 'Road flooding')
            ELSE IFF(U_CAUSE < 0.5, 'Ferry cancellation', IFF(U_CAUSE < 0.8, 'Port congestion', 'Hub backlog')) END AS DISRUPTION_CAUSE,
       PAYOUT_DUE, PAYOUT_SETTLED,
       ROUND(1.04 + 0.09 * DRIFT + 0.14 * DISRUPTION_RISK + 0.06 * U_NOISE, 2) AS AVG_ATTEMPTS,
       ROUND(6 + 3 * DRIFT + 4 * DISRUPTION_RISK + U_NOISE * 2, 1) AS AVG_DELIVERY_HOURS,
       CURRENT_TIMESTAMP() AS LOADED_AT
FROM outcomes;

-- Rider compliance document checks per zone (snapshot).
CREATE TABLE RAW.RIDER_DOCUMENTS AS
SELECT ID AS ENTITY_ID,
       CASE CATEGORY WHEN 'Same-day' THEN 'Motorcycle licence check'
                     WHEN 'Next-day' THEN 'Professional licence check'
                     WHEN 'Cash on delivery' THEN 'COD cash-handling training'
                     WHEN 'Bulky item' THEN 'Truck registration check'
                     ELSE 'Inter-island waybill training' END AS DOC_TYPE,
       1 + MOD(ABS(HASH(ID, 'phrd-req')), 5) AS REQUIRED_QTY,
       MOD(ABS(HASH(ID, 'phrd-file')), 5) AS ON_FILE_QTY,
       IFF(MOD(ABS(HASH(ID, 'phrd-file')), 5) < 1 + MOD(ABS(HASH(ID, 'phrd-req')), 5),
           MOD(ABS(HASH(ID, 'phrd-pending')), 3), 0) AS PENDING_QTY,
       CURRENT_DATE() AS SNAPSHOT_DATE
FROM RAW.ZONES;
