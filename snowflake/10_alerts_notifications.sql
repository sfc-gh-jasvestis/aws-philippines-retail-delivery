-- ============================================================================
-- 10_ALERTS_NOTIFICATIONS.SQL — Alerts for Last-Mile Delivery Optimization & Geospatial Intelligence
-- ============================================================================
USE DATABASE DELIVERY_LOGISTICS;
USE SCHEMA APP;

-- Notification integration (email)
CREATE OR REPLACE NOTIFICATION INTEGRATION aws_philippines_retail_delivery_EMAIL_INT
  TYPE = EMAIL
  ENABLED = TRUE
  ALLOWED_RECIPIENTS = ('jonathan.asvestis@snowflake.com');

-- Alert: ZONE_FAILURE_ALERT
CREATE OR REPLACE ALERT APP.ZONE_FAILURE_ALERT
  WAREHOUSE = LOGISTICS_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Delivery failure rate exceeding threshold in zone'
IF (EXISTS (
  SELECT 1 FROM CURATED.ZONE_PERFORMANCE
  WHERE 1=1 -- Condition: ZONE_FAILURE_RATE > 15% for any H3 hex
))
THEN
  CALL SYSTEM$SEND_EMAIL(
    'aws_philippines_retail_delivery_EMAIL_INT',
    'jonathan.asvestis@snowflake.com',
    '[ALERT] Last-Mile Delivery Optimization & Geospatial Intelligence: Delivery failure rate exceeding threshold in zone',
    'Delivery failure rate exceeding threshold in zone'
  );

ALTER ALERT APP.ZONE_FAILURE_ALERT RESUME;

-- Alert: CAPACITY_ALERT
CREATE OR REPLACE ALERT APP.CAPACITY_ALERT
  WAREHOUSE = LOGISTICS_WH
  SCHEDULE = '5 MINUTE'
  COMMENT = 'Hub approaching capacity limit'
IF (EXISTS (
  SELECT 1 FROM CURATED.ZONE_PERFORMANCE
  WHERE 1=1 -- Condition: HUB_UTILIZATION > 95% for any hub
))
THEN
  CALL SYSTEM$SEND_EMAIL(
    'aws_philippines_retail_delivery_EMAIL_INT',
    'jonathan.asvestis@snowflake.com',
    '[ALERT] Last-Mile Delivery Optimization & Geospatial Intelligence: Hub approaching capacity limit',
    'Hub approaching capacity limit'
  );

ALTER ALERT APP.CAPACITY_ALERT RESUME;

