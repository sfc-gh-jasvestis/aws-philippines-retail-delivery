-- Validate the producer contract before building downstream objects.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

EXECUTE IMMEDIATE $$
DECLARE
  violations INTEGER;
  invalid_source EXCEPTION (-20001, 'Synthetic source failed grain or measure validation');
BEGIN
  SELECT COUNT(*) INTO :violations FROM (
    SELECT ENTITY_ID, EVENT_DATE
    FROM RAW.ZONE_DAILY
    GROUP BY ENTITY_ID, EVENT_DATE HAVING COUNT(*) <> 1
    UNION ALL
    SELECT observation.ENTITY_ID, observation.EVENT_DATE
    FROM RAW.ZONE_DAILY observation
    LEFT JOIN RAW.ZONES zone ON zone.ID = observation.ENTITY_ID
    WHERE zone.ID IS NULL OR observation.PARCEL_COUNT <= 0
       OR observation.PARCEL_VALUE_PHP < 0 OR observation.DELIVERED_COUNT < 0
       OR observation.FAILED_COUNT < 0 OR observation.RETURNED_COUNT < 0
       OR observation.DELIVERED_COUNT + observation.FAILED_COUNT + observation.RETURNED_COUNT <> observation.PARCEL_COUNT
       OR observation.DISRUPTION_HOURS NOT BETWEEN 0 AND 24
       OR observation.PAYOUT_SETTLED > observation.PAYOUT_DUE
  );
  IF (violations > 0) THEN
    RAISE invalid_source;
  END IF;
END;
$$;
