-- ============================================================================
-- 01_MARKETPLACE_INSTALL.SQL — Install marketplace data for Last-Mile Delivery Optimization & Geospatial Intelligence
-- ============================================================================
USE DATABASE DELIVERY_LOGISTICS;
USE SCHEMA RAW;

-- Free listings to install from Snowflake Marketplace:
-- Install: Snowflake Public Data (Free)
--   https://app.snowflake.com/marketplace/listing/GZTSZ290BV255

-- Paid listing (mock): OnPoint Historical Weather
--   Real data: https://app.snowflake.com/marketplace/listing/GZSOZBT22EH
--   Using mock table: WEATHER_IMPACT
CREATE TABLE IF NOT EXISTS RAW.WEATHER_IMPACT (
  ID INT AUTOINCREMENT, DATA VARIANT, LOADED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

