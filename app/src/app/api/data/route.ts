import { NextResponse } from 'next/server';
import { demoPlatform } from '@/lib/platform';
import { executeQuery } from '@/lib/snowflake';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export async function GET() {
  try {
    const [kpis, trend, causes, zones, freshness, risk, holdout, forecast, live, liveSummary, anomalies, alerts] = await Promise.all([
      executeQuery<{ TITLE: string; DISPLAY: string; STATUS: string }>(
        'SELECT TITLE, DISPLAY, STATUS FROM CURATED.KPI_SUMMARY ORDER BY SORT_ORDER'),
      executeQuery<{ PERIOD: string; FAILED: number | null; DISRUPTION_HOURS: number | null }>(`
        SELECT TO_CHAR(METRIC_DATE, 'YYYY-MM-DD') AS PERIOD,
               FAILED_COUNT AS FAILED, DISRUPTION_HOURS
        FROM CURATED.TREND_ANALYSIS ORDER BY METRIC_DATE`),
      executeQuery<{ DISRUPTION_CAUSE: string; DISRUPTION_DAYS: number; DISRUPTION_HOURS: number }>(`
        SELECT DISRUPTION_CAUSE, DISRUPTION_DAYS, DISRUPTION_HOURS
        FROM CURATED.CAUSE_SUMMARY ORDER BY DISRUPTION_HOURS DESC, DISRUPTION_DAYS DESC`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT ENTITY_ID, ENTITY_NAME, REGION, CATEGORY, ACCESS_TIER, EVENT_COUNT, PARCEL_COUNT, DELIVERED_COUNT,
               FAILED_COUNT, DISRUPTION_HOURS, ROUND(SUCCESS_PCT, 1) AS SUCCESS_PCT,
               PAYOUT_ON_TIME_PCT, ROUND(PARCEL_VALUE_PHP / 1e9, 2) AS PARCEL_VALUE_PHP_B
        FROM CURATED.PERFORMANCE_SUMMARY ORDER BY ENTITY_ID LIMIT 200`),
      executeQuery<{ RAW_WATERMARK: string | null; CURATED_WATERMARK: string | null }>(`
        SELECT (SELECT TO_CHAR(MAX(EVENT_DATE), 'YYYY-MM-DD') FROM RAW.ZONE_DAILY) AS RAW_WATERMARK,
               (SELECT TO_CHAR(MAX(METRIC_DATE), 'YYYY-MM-DD') FROM CURATED.TREND_ANALYSIS) AS CURATED_WATERMARK`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT ENTITY_ID, TO_CHAR(SCORED_AS_OF, 'YYYY-MM-DD') AS SCORED_AS_OF, DISRUPTION_PROB_7D, RISK_BAND
        FROM ML.DISRUPTION_RISK_SCORES ORDER BY DISRUPTION_PROB_7D DESC`),
      executeQuery<Record<string, string | number | null>>(
        'SELECT N, BASE_RATE, PRECISION_AT_50, RECALL_AT_50 FROM ML.DISRUPTION_RISK_HOLDOUT_METRICS'),
      executeQuery<Record<string, string | number | null>>(`
        SELECT TO_CHAR(FORECAST_DATE, 'YYYY-MM-DD') AS PERIOD, FAILED_COUNT, LOWER_BOUND, UPPER_BOUND
        FROM ML.FAILED_FORECAST ORDER BY FORECAST_DATE`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT ZONE_ID, TO_CHAR(EVENT_TS, 'YYYY-MM-DD HH24:MI:SS') AS EVENT_TS, ROUND(COD_PHP, 0) AS COD_PHP,
               DWELL_MINUTES, STATUS, TO_CHAR(LOADED_AT, 'YYYY-MM-DD HH24:MI:SS TZH:TZM') AS LOADED_AT
        FROM RAW.LIVE_DELIVERIES ORDER BY EVENT_TS DESC LIMIT 25`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT COUNT(*) AS N, COUNT_IF(STATUS = 'FAILED') AS FAILED,
               TO_CHAR(MAX(LOADED_AT), 'YYYY-MM-DD HH24:MI:SS TZH:TZM') AS LAST_LOADED,
               ROUND(MEDIAN(DATEDIFF('second', SENT_TS, CONVERT_TIMEZONE('UTC', LOADED_AT)::TIMESTAMP_NTZ)), 0) AS MEDIAN_LAG_S
        FROM RAW.LIVE_DELIVERIES`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT ENTITY_ID, TO_CHAR(EVENT_DATE, 'YYYY-MM-DD') AS EVENT_DATE, ROUND(DELIVERY_HOURS, 1) AS DELIVERY_HOURS,
               ROUND(EXPECTED, 1) AS EXPECTED, ROUND(UPPER_BOUND, 1) AS UPPER_BOUND
        FROM ML.DELIVERY_HOURS_ANOMALIES WHERE IS_ANOMALY ORDER BY EVENT_DATE DESC, ENTITY_ID LIMIT 50`),
      executeQuery<Record<string, string | number | null>>(`
        SELECT ZONE_ID, TO_CHAR(EVENT_TS, 'YYYY-MM-DD HH24:MI:SS') AS EVENT_TS, ROUND(COD_PHP, 0) AS COD_PHP,
               DWELL_MINUTES, PLAYBOOK_HINT
        FROM APP.ALERT_LOG ORDER BY ALERTED_AT DESC, EVENT_TS DESC LIMIT 25`),
    ]);
    const numberOrNull = (value: unknown): number | null => {
      if (value === null || value === undefined) return null;
      const numeric = Number(value);
      if (!Number.isFinite(numeric)) throw new Error('Non-numeric measure in curated contract');
      return numeric;
    };
    const watermark = freshness[0]?.CURATED_WATERMARK ?? null;
    const ageDays = watermark ? (Date.now() - Date.parse(`${watermark}T00:00:00Z`)) / 86400000 : null;
    return NextResponse.json({
      platform: demoPlatform(),
      kpiCards: kpis.map((row) => ({ title: row.TITLE, value: row.DISPLAY, status: row.STATUS })),
      timeseries: trend.map((row) => ({ period: row.PERIOD, failed: numberOrNull(row.FAILED), disruptionHours: numberOrNull(row.DISRUPTION_HOURS) })),
      categories: causes.map((row) => ({ category: row.DISRUPTION_CAUSE, days: numberOrNull(row.DISRUPTION_DAYS), hours: numberOrNull(row.DISRUPTION_HOURS) })),
      entities: zones.map((row) => ({
        id: row.ENTITY_ID, name: row.ENTITY_NAME, region: row.REGION, category: row.CATEGORY, tier: row.ACCESS_TIER,
        parcels: numberOrNull(row.PARCEL_COUNT), deliveries: numberOrNull(row.DELIVERED_COUNT), failed: numberOrNull(row.FAILED_COUNT),
        disruptionHours: numberOrNull(row.DISRUPTION_HOURS), success: numberOrNull(row.SUCCESS_PCT),
        value: numberOrNull(row.PARCEL_VALUE_PHP_B), payout: numberOrNull(row.PAYOUT_ON_TIME_PCT), events: numberOrNull(row.EVENT_COUNT),
      })),
      payoutRisk: zones.map((row) => ({
        name: row.ENTITY_NAME, payout: numberOrNull(row.PAYOUT_ON_TIME_PCT), disruptionHours: numberOrNull(row.DISRUPTION_HOURS),
      })).filter((row) => row.payout !== null && row.disruptionHours !== null),
      sourceWatermark: watermark,
      rawWatermark: freshness[0]?.RAW_WATERMARK ?? null,
      stale: ageDays === null || ageDays > 2,
      pipelineBehind: freshness[0]?.RAW_WATERMARK !== watermark,
      requestedAt: new Date().toISOString(),
      synthetic: true,
      risk: risk.map((row) => ({
        id: row.ENTITY_ID, scoredAsOf: row.SCORED_AS_OF,
        probability: numberOrNull(row.DISRUPTION_PROB_7D), band: row.RISK_BAND,
      })),
      holdout: holdout[0] ? {
        n: numberOrNull(holdout[0].N), baseRate: numberOrNull(holdout[0].BASE_RATE),
        precision: numberOrNull(holdout[0].PRECISION_AT_50), recall: numberOrNull(holdout[0].RECALL_AT_50),
      } : null,
      forecast: forecast.map((row) => ({
        period: row.PERIOD, value: numberOrNull(row.FAILED_COUNT),
        lower: numberOrNull(row.LOWER_BOUND), upper: numberOrNull(row.UPPER_BOUND),
      })),
      modelStatus: holdout[0] ? 'holdout_evaluated' : 'missing',
      live: live.map((row) => ({
        id: row.ZONE_ID, eventTs: row.EVENT_TS, cod: numberOrNull(row.COD_PHP),
        dwell: numberOrNull(row.DWELL_MINUTES), status: row.STATUS, loadedAt: row.LOADED_AT,
      })),
      liveSummary: {
        n: numberOrNull(liveSummary[0]?.N), failed: numberOrNull(liveSummary[0]?.FAILED),
        lastLoaded: liveSummary[0]?.LAST_LOADED ?? null, medianLagSeconds: numberOrNull(liveSummary[0]?.MEDIAN_LAG_S),
      },
      anomalies: anomalies.map((row) => ({
        id: row.ENTITY_ID, date: row.EVENT_DATE, hours: numberOrNull(row.DELIVERY_HOURS),
        expected: numberOrNull(row.EXPECTED), upper: numberOrNull(row.UPPER_BOUND),
      })),
      alerts: alerts.map((row) => ({
        id: row.ZONE_ID, eventTs: row.EVENT_TS, cod: numberOrNull(row.COD_PHP),
        dwell: numberOrNull(row.DWELL_MINUTES), hint: row.PLAYBOOK_HINT,
      })),
    }, { headers: { 'Cache-Control': 'no-store' } });
  } catch {
    return NextResponse.json({ error: 'Delivery data is unavailable. Verify the core deployment and application role.' },
      { status: 503, headers: { 'Cache-Control': 'no-store' } });
  }
}
