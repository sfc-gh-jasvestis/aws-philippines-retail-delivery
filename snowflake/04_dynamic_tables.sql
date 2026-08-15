-- ============================================================================
-- 04_DYNAMIC_TABLES.SQL — Curated layer for Last-Mile Delivery Optimization & Geospatial Intelligence
-- ============================================================================
USE DATABASE DELIVERY_LOGISTICS;
USE SCHEMA CURATED;

-- ZONE_PERFORMANCE: Delivery performance metrics per H3 hexagon zone
-- Source: DELIVERY_HUBS, PARCELS, DELIVERY_ATTEMPTS
CREATE OR REPLACE DYNAMIC TABLE CURATED.ZONE_PERFORMANCE
  TARGET_LAG = '5 minutes'
  WAREHOUSE = LOGISTICS_WH
AS
SELECT * FROM RAW.DELIVERY_HUBS;
-- TODO: Replace with actual join/aggregation logic per demo

-- RIDER_UTILIZATION: Rider capacity and efficiency metrics
-- Source: RIDERS, DELIVERY_ATTEMPTS
CREATE OR REPLACE DYNAMIC TABLE CURATED.RIDER_UTILIZATION
  TARGET_LAG = '5 minutes'
  WAREHOUSE = LOGISTICS_WH
AS
SELECT * FROM RAW.RIDERS;
-- TODO: Replace with actual join/aggregation logic per demo

-- DEMAND_FORECAST_INPUT: Daily volumes by zone for ML.FORECAST
-- Source: DEMAND_HISTORY, PARCELS
CREATE OR REPLACE DYNAMIC TABLE CURATED.DEMAND_FORECAST_INPUT
  TARGET_LAG = '5 minutes'
  WAREHOUSE = LOGISTICS_WH
AS
SELECT * FROM RAW.DEMAND_HISTORY;
-- TODO: Replace with actual join/aggregation logic per demo

-- FAILED_DELIVERY_ANALYSIS: Failed delivery patterns by zone, time, reason
-- Source: DELIVERY_ATTEMPTS, PARCELS
CREATE OR REPLACE DYNAMIC TABLE CURATED.FAILED_DELIVERY_ANALYSIS
  TARGET_LAG = '5 minutes'
  WAREHOUSE = LOGISTICS_WH
AS
SELECT * FROM RAW.DELIVERY_ATTEMPTS;
-- TODO: Replace with actual join/aggregation logic per demo

