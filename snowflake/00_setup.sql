-- Generated from generator/demo_specs/aws-philippines-retail-delivery.json
-- Regenerate with: python3 generator/gen_repo_docs.py aws-philippines-retail-delivery
-- This is the schema that is actually deployed for PH_RETAIL_DELIVERY.

-- PH_RETAIL_DELIVERY  (Last-Mile Delivery Optimization & Geospatial Intelligence)
-- generated from generator/demo_specs/aws-philippines-retail-delivery.json - do not hand-edit
CREATE DATABASE IF NOT EXISTS PH_RETAIL_DELIVERY;
CREATE SCHEMA IF NOT EXISTS PH_RETAIL_DELIVERY.RAW;
CREATE SCHEMA IF NOT EXISTS PH_RETAIL_DELIVERY.CURATED;
CREATE SCHEMA IF NOT EXISTS PH_RETAIL_DELIVERY.APP;
USE DATABASE PH_RETAIL_DELIVERY;

-- 5 real regions; entity names carry their region so the two always agree
