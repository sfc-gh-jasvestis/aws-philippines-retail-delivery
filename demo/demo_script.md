# Demo Script: Last-Mile Delivery Optimization & Geospatial Intelligence
## ~4-Minute Recorded Walkthrough
**Format**: Screen recording with voiceover
**Target**: Customer meeting / booth loop / social share
**Narrative**: "Snowflake combines AWS Location Service data with H3 geospatial functions and ML.FORECAST to optimize delivery operations across the Philippine archipelago — predicting volumes, identifying dead zones, and reducing failed deliveries"
**Demo Mode**: Open app with `?demo=true` for presenter notes

---

## Two Personas

| Persona | Role | Tool | What they care about |
|---|---|---|---|
| **Ricardo Jose Villar** | VP Logistics & Fulfillment | React App (SPCS) | Delivery success rates, cost per delivery, hub capacity, SLA compliance |
| **Ana Patricia Dimaculangan** | Route Optimization Manager | Amazon QuickSight | Driver utilization, route efficiency, delivery density, failed delivery reasons |

---

## What's Built

| Layer | Component | Detail |
|---|---|---|
| **RAW** | 6 tables | DELIVERY_HUBS (85), PARCELS (3200000), RIDERS (12000), DELIVERY_ATTEMPTS (4100000), LOCATION_DATA (8500000), DEMAND_HISTORY (180000) |
| **CURATED** | 4 Dynamic Tables | ZONE_PERFORMANCE, RIDER_UTILIZATION, DEMAND_FORECAST_INPUT, FAILED_DELIVERY_ANALYSIS |
| **ML** | ML.FORECAST + ML.CLASSIFICATION | Forecasting + anomaly detection |
| **AI** | COMPLETE, AI_CLASSIFY | Classification + extraction |
| **Search** | Cortex Search | 4100000 documents indexed |
| **Agent** | LOGISTICS_INTELLIGENCE_AGENT | Semantic View + Search tools |


---

## The Story

The Philippines is the world's most complex last-mile delivery market: 7,641 islands, 180 million people, monsoon seasons, and incomplete addressing systems. A leading delivery company handles 3.2M parcels monthly but loses ₱450M annually to failed deliveries — returned to hub, rider overtime, and customer refunds. Traditional route planning tools don't understand archipelago geography. H3 geospatial + ML.FORECAST does.

---

## Script

### [0:00–0:45] EXECUTIVE COCKPIT

**Show**: Executive Cockpit tab

> "3.2 million parcels delivered monthly through 85 hubs and 12,000 riders."

**Action**: Point at 3.2M parcels KPI

### [0:45–1:30] GEOSPATIAL ANALYTICS

**Show**: Geospatial Analytics tab

> "H3 hexagonal indexing: Philippines divided into 4,200 delivery zones at resolution 6."

**Action**: Show H3 hexagonal map with delivery density

### [1:30–2:15] DEMAND & CAPACITY

**Show**: Demand & Capacity tab

> "ML.FORECAST predicts: 11.11 sale will spike volumes 340% — 3 hubs will exceed capacity."

**Action**: Show demand forecast with 11.11 spike

### [2:15–3:00] ASK AI

**Show**: Ask AI tab

> "Ricardo asks: 'Where should we open the next micro-hub?'"

**Action**: Type: 'Best location for next micro-hub?'

### [3:00–3:45] ARCHITECTURE & DATA

**Show**: Architecture & Data tab

> "Location Service → Snowpipe Streaming → H3 aggregation → ML.FORECAST → zone optimization."

**Action**: Walk through architecture diagram


---

## Key Demo Differentiators

1. **H3 geospatial indexing for delivery zones** — Only demo using Snowflake H3 functions for logistics zone analytics
2. **ML.FORECAST for delivery volumes** — Predicts demand spikes (11.11, Christmas) per delivery zone
3. **AWS Location Service integration** — GPS tracking data ingested into Snowflake for geospatial analysis
4. **Philippine archipelago context** — 7,641 islands with unique addressing and access challenges
5. **4.1M delivery notes searchable** — Cortex Search on rider notes for failure pattern discovery
6. **ST_WITHIN proximity analysis** — Geospatial functions identify nearby successful deliveries for routing


---

## Demo Prep Checklist

### Data Verification
- [ ] `SELECT COUNT(*) FROM DELIVERY_LOGISTICS.RAW.PARCELS` → 3200000
- [ ] `SELECT COUNT(*) FROM DELIVERY_LOGISTICS.RAW.LOCATION_DATA` → 8500000
- [ ] `SELECT COUNT(DISTINCT ZONE_H3) FROM DELIVERY_LOGISTICS.CURATED.ZONE_PERFORMANCE WHERE SUCCESS_RATE < 0.85` → 14

### ML Model Verification
- [ ] `SELECT COUNT(*) FROM DELIVERY_LOGISTICS.ML.DELIVERY_VOLUME_FORECAST_RESULTS` → >0
- [ ] `SELECT COUNT(*) FROM DELIVERY_LOGISTICS.ML.DELIVERY_FAILURE_CLASSIFICATION_RESULTS` → >0

### AI/Agent Verification
- [ ] `SELECT COUNT(*) FROM DELIVERY_LOGISTICS.AI.DELIVERY_REASON_CLASSIFICATION` → >0

