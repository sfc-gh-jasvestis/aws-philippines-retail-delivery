-- ============================================================================
-- 08_native_deliveries.sql - Snowflake-only build: live delivery-attempt feed without AWS.
-- Creates RAW.LIVE_DELIVERIES (same columns as the Snowpipe target created by
-- aws/setup_aws.py) and APP.SIMULATE_DELIVERIES(N), which inserts synthetic delivery-attempt
-- events with the same value ranges and ~12% FAILED rate as
-- aws/publish_deliveries.py. Rows are inserted directly; this simulates a delivery-attempt
-- feed and is not Snowpipe Streaming.
-- Run before 06_intelligence.sql (the alert reads RAW.LIVE_DELIVERIES).
-- Idempotent: safe to run in the AWS build too.
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS APP;

CREATE TABLE IF NOT EXISTS RAW.LIVE_DELIVERIES (
  ZONE_ID VARCHAR, EVENT_TS TIMESTAMP_NTZ, COD_PHP FLOAT, DWELL_MINUTES FLOAT,
  STATUS VARCHAR, SENT_TS TIMESTAMP_NTZ, SOURCE_FILE VARCHAR,
  LOADED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP());

CREATE OR REPLACE PROCEDURE APP.SIMULATE_DELIVERIES(N NUMBER)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
  IF (N < 1 OR N > 1000) THEN
    RETURN 0;
  END IF;
  INSERT INTO RAW.LIVE_DELIVERIES (ZONE_ID, EVENT_TS, COD_PHP, DWELL_MINUTES, STATUS, SENT_TS, SOURCE_FILE)
    WITH g AS (
      SELECT 'ZON-' || LPAD(UNIFORM(0, 39, RANDOM())::VARCHAR, 4, '0') AS ZONE_ID,
             UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.12 AS IS_FAILED,
             SYSDATE() AS TS, SEQ4() AS I
      FROM TABLE(GENERATOR(ROWCOUNT => 1000))
    )
    -- NORMAL() needs constant arguments, so the status offset is applied outside it.
    SELECT ZONE_ID, TS,
           IFF(IS_FAILED, 0, ROUND(950 * EXP(NORMAL(0, 0.6, RANDOM())), 0)),
           ROUND(IFF(IS_FAILED, 190, 85) * EXP(NORMAL(0, 0.35, RANDOM())), 0),
           IFF(IS_FAILED, 'FAILED', 'DELIVERED'), TS, 'APP.SIMULATE_DELIVERIES'
    FROM g
    WHERE I < :N;
  RETURN SQLROWCOUNT;
END;
$$;

-- Optional continuous feed for longer demos (suspended; RESUME to start, SUSPEND after).
CREATE OR REPLACE TASK APP.TASK_SIMULATE_DELIVERIES
  WAREHOUSE = __DEMO_WH__
  SCHEDULE = '1 MINUTE'
AS
  CALL APP.SIMULATE_DELIVERIES(5);
