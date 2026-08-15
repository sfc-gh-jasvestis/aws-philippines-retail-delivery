-- ============================================================================
-- Last-Mile Delivery Optimization & Geospatial Intelligence
-- Philippine archipelago logistics: 7,641 islands, 180M people — Snowflake uses H3 geospatial indexing to optimize last-mile delivery, ML.FORECAST to predict volumes, and Location Service integration for real-time routing intelligence.
-- ============================================================================
USE ROLE ACCOUNTADMIN;
CREATE DATABASE IF NOT EXISTS DELIVERY_LOGISTICS;
CREATE WAREHOUSE IF NOT EXISTS LOGISTICS_WH WAREHOUSE_SIZE = 'MEDIUM' AUTO_SUSPEND = 120 AUTO_RESUME = TRUE;
USE DATABASE DELIVERY_LOGISTICS;
CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS CURATED;
CREATE SCHEMA IF NOT EXISTS ML;
CREATE SCHEMA IF NOT EXISTS AI;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

USE WAREHOUSE LOGISTICS_WH;
