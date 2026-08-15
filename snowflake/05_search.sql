-- ============================================================================
-- 05_SEARCH.SQL — Cortex Search for Last-Mile Delivery Optimization & Geospatial Intelligence
-- ============================================================================
USE DATABASE DELIVERY_LOGISTICS;
USE SCHEMA SEARCH;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.DELIVERY_NOTES_SEARCH
  ON RIDER_NOTES
  ATTRIBUTES ZONE_H3, FAILURE_REASON, HUB_ID
  WAREHOUSE = LOGISTICS_WH
  TARGET_LAG = '1 hour'
AS (
  SELECT * FROM RAW.DELIVERY_ATTEMPTS
);
