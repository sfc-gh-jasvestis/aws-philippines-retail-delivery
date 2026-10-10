import { NextResponse } from 'next/server';
import { executeQuery } from '@/lib/snowflake';
import { demoPlatform } from '@/lib/platform';

export const dynamic = 'force-dynamic';

// Only these fixed, read-only queries can run. The model never writes SQL; it
// only summarises rows returned here, so every answer is traceable to data.
const INTENTS: Record<string, { match: RegExp; sql: string }> = {
  zones: {
    match: /zone|disruption|fail|worst|highest|city|service/i,
    sql: `SELECT ENTITY_ID, ENTITY_NAME, REGION, CATEGORY, DISRUPTION_HOURS, DISRUPTION_DAYS, FAILED_COUNT, ROUND(SUCCESS_PCT, 1) AS SUCCESS_PCT
FROM CURATED.PERFORMANCE_SUMMARY
QUALIFY DENSE_RANK() OVER (ORDER BY DISRUPTION_HOURS DESC) <= 3
ORDER BY DISRUPTION_HOURS DESC, FAILED_COUNT DESC`,
  },
  causes: {
    match: /cause|reason|why|rain|flood|typhoon|ferry|backlog/i,
    sql: `SELECT DISRUPTION_CAUSE, DISRUPTION_DAYS, DISRUPTION_HOURS, FAILED_COUNT, ROUND(FAILED_PCT, 1) AS FAILED_PCT
FROM CURATED.CAUSE_SUMMARY ORDER BY DISRUPTION_HOURS DESC LIMIT 8`,
  },
  kpis: {
    match: /.*/,
    sql: `SELECT TITLE, DISPLAY, SOURCE_WATERMARK FROM CURATED.KPI_SUMMARY ORDER BY SORT_ORDER`,
  },
};

const DEFINITIONS =
  'Delivery success rate = delivered parcels / parcels dispatched. A failed delivery went back to the hub after the attempt; parcels refused by the customer are counted separately as returns to sender. ' +
  'A disruption hour is an hour in a zone when riders could not complete the planned route. Typhoon flooding hits every zone in a city at once and is not zone-driven. ' +
  'Parcel value is in PHP. Zones are one delivery service in one Philippine city. All data is synthetic demo data.';

// provider 'cortex' = Snowflake AI_COMPLETE; 'bedrock' = Amazon Bedrock Claude
// via the external-access UDF APP.BEDROCK_GENERATE (aws/setup_aws.py).
async function summarise(question: string, rows: unknown[], provider: 'cortex' | 'bedrock' = 'cortex'): Promise<string> {
  const prompt =
    'You are a last-mile operations analyst at a Philippine e-commerce courier. Answer ONLY from the JSON rows and definitions below. ' +
    'If the rows do not answer the question, say so. Do not invent numbers. Keep it under 120 words.\n' +
    `Definitions: ${DEFINITIONS}\nRows: ${JSON.stringify(rows)}\nQuestion: ${question}`;
  const out = await executeQuery<{ R: string }>(
    provider === 'bedrock' ? 'SELECT APP.BEDROCK_GENERATE(?) AS R' : `SELECT AI_COMPLETE('claude-sonnet-4-5', ?) AS R`,
    [prompt],
  );
  const raw = String(out[0]?.R ?? '').trim();
  // AI_COMPLETE returns a JSON string literal; decode it when present.
  try {
    const parsed = JSON.parse(raw);
    return typeof parsed === 'string' ? parsed : raw;
  } catch {
    return raw;
  }
}

export async function POST(req: Request) {
  let body: any;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }
  const question = typeof body?.question === 'string' ? body.question.trim().slice(0, 2000) : '';
  const memo = body?.mode === 'memo';
  if (!memo && !question) return NextResponse.json({ error: 'Question required' }, { status: 400 });

  try {
    if (memo) {
      const provider = demoPlatform() === 'aws' ? 'bedrock' : 'cortex';
      const [kpis, zones, causes, risk, bands] = await Promise.all([
        executeQuery(INTENTS.kpis.sql),
        executeQuery(INTENTS.zones.sql),
        executeQuery(INTENTS.causes.sql),
        executeQuery(`SELECT ENTITY_ID, ROUND(DISRUPTION_PROB_7D, 2) AS DISRUPTION_PROB_7D, RISK_BAND
FROM ML.DISRUPTION_RISK_SCORES ORDER BY DISRUPTION_PROB_7D DESC LIMIT 5`),
        executeQuery(`SELECT RISK_BAND, COUNT(*) AS ZONES FROM ML.DISRUPTION_RISK_SCORES GROUP BY RISK_BAND`),
      ]);
      const rows = { kpis, topDisruptionZones: zones, disruptionCauses: causes, top5ByRisk: risk, zonesPerRiskBand: bands };
      const answer = await summarise(
        'Draft a short action memo for the VP Last-Mile Operations with 3 prioritised actions, citing the figures.',
        [rows],
        provider,
      );
      return NextResponse.json({ answer, sources: rows, provider: provider === 'bedrock' ? 'Amazon Bedrock (Claude Sonnet 4.5)' : 'Snowflake Cortex AI_COMPLETE (claude-sonnet-4-5)', draft: true, synthetic: true });
    }
    const key = Object.keys(INTENTS).find((k) => INTENTS[k].match.test(question))!;
    const rows = await executeQuery(INTENTS[key].sql);
    const answer = await summarise(question, rows);
    return NextResponse.json({ answer, sql: INTENTS[key].sql, sources: rows, synthetic: true });
  } catch (err) {
    console.error('ask route failed', err);
    return NextResponse.json({ error: 'AI service unavailable' }, { status: 503 });
  }
}
