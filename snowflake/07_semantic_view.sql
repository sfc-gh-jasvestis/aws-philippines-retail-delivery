-- ============================================================================
-- 07_SEMANTIC_VIEW.SQL — Semantic View for Last-Mile Delivery Optimization & Geospatial Intelligence
-- ============================================================================
USE DATABASE DELIVERY_LOGISTICS;
USE SCHEMA APP;

CREATE OR REPLACE SEMANTIC VIEW APP.DELIVERY_ANALYTICS
  COMMENT = 'Last-mile delivery performance, geospatial optimization, and demand forecasting'
AS
  TABLES (
    CURATED.ZONE_PERFORMANCE AS zone_performance,CURATED.RIDER_UTILIZATION AS rider_utilization,CURATED.DEMAND_FORECAST_INPUT AS demand_forecast_input,CURATED.FAILED_DELIVERY_ANALYSIS AS failed_delivery_analysis
  );
