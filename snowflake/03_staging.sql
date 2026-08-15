-- ============================================================================
-- 03_STAGING.SQL — Generate synthetic data for Last-Mile Delivery Optimization & Geospatial Intelligence
-- Country: PHILIPPINES | Currency: PHP
-- ============================================================================
USE DATABASE DELIVERY_LOGISTICS;
USE SCHEMA RAW;

-- Data generation scripts are demo-specific.
-- See the handcrafted SQL in the aws-malaysia-semiconductor-yield demo for
-- the full pattern: GENERATOR + UNIFORM + LATERAL for distribution,
-- Cortex Complete for text generation, engineered key demo numbers.

-- Target row counts:
-- DELIVERY_HUBS: 85 rows — Fulfillment hubs and micro-hubs across Philippines
-- PARCELS: 3,200,000 rows — 60 days of parcel records with delivery status
-- RIDERS: 12,000 rows — Delivery riders (motorcycle, van, bike)
-- DELIVERY_ATTEMPTS: 4,100,000 rows — Individual delivery attempts with GPS coordinates
-- LOCATION_DATA: 8,500,000 rows — AWS Location Service tracking points
-- DEMAND_HISTORY: 180,000 rows — Daily delivery volumes by zone for forecasting
