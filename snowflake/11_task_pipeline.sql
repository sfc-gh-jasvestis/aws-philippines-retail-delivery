-- ============================================================================
-- 11_TASK_PIPELINE.SQL — Task DAG for Last-Mile Delivery Optimization & Geospatial Intelligence
-- ============================================================================
USE DATABASE DELIVERY_LOGISTICS;
USE SCHEMA APP;

CREATE OR REPLACE TASK APP.TASK_INGEST_GPS
  WAREHOUSE = LOGISTICS_WH
  SCHEDULE = 'USING CRON */10 * * * * UTC'
  COMMENT = 'Ingest latest Location Service tracking data'
AS
  SELECT 1; -- Replace with actual refresh logic

CREATE OR REPLACE TASK APP.TASK_UPDATE_ZONES
  WAREHOUSE = LOGISTICS_WH
  AFTER APP.TASK_INGEST_GPS
  COMMENT = 'Refresh zone performance metrics with H3 aggregation'
AS
  SELECT 1; -- Replace with actual refresh logic

CREATE OR REPLACE TASK APP.TASK_FORECAST_DEMAND
  WAREHOUSE = LOGISTICS_WH
  SCHEDULE = 'USING CRON 0 4 * * * UTC'
  COMMENT = 'Generate next 7 days demand forecast by zone'
AS
  SELECT 1; -- Replace with actual refresh logic

ALTER TASK APP.TASK_FORECAST_DEMAND RESUME;
ALTER TASK APP.TASK_UPDATE_ZONES RESUME;
ALTER TASK APP.TASK_INGEST_GPS RESUME;
