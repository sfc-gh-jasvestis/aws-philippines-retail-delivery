# Last-Mile Delivery Optimization & Geospatial Intelligence

**Philippines - Retail & E-Commerce**
Use case: Last-Mile Delivery

> Philippine archipelago logistics: 7,641 islands, 180M people — Snowflake uses H3 geospatial indexing to optimize last-mile delivery, ML.FORECAST to predict volumes, and Location Service integration for real-time routing intelligence.

## Why Snowflake

Snowflake combines AWS Location Service data with H3 geospatial functions and ML.FORECAST to optimize delivery operations across the Philippine archipelago — predicting volumes, identifying dead zones, and reducing failed deliveries

- **H3 geospatial indexing for delivery zones** - Only demo using Snowflake H3 functions for logistics zone analytics
- **ML.FORECAST for delivery volumes** - Predicts demand spikes (11.11, Christmas) per delivery zone
- **AWS Location Service integration** - GPS tracking data ingested into Snowflake for geospatial analysis
- **Philippine archipelago context** - 7,641 islands with unique addressing and access challenges
- **4.1M delivery notes searchable** - Cortex Search on rider notes for failure pattern discovery
- **ST_WITHIN proximity analysis** - Geospatial functions identify nearby successful deliveries for routing

## What is deployed

| | |
|---|---|
| Database | `PH_RETAIL_DELIVERY` |
| Service | `PH_RETAIL_DELIVERY_APP` |
| Compute pool | `SEA_DEMOS_PHILIPPINES_POOL` |
| Dimension table | `RAW.DELIVERY_HUBS` (20 rows) |
| Fact table | `RAW.LOCATION_DATA` (250,000 rows, 90 days) |
| Curated layer | `CURATED.PERFORMANCE_SUMMARY`, `CURATED.TREND_ANALYSIS`, `CURATED.KPI_SUMMARY` |
| Currency | PHP (₱) |

Regions in play: Metro Manila, Cebu, Davao, Pampanga, Iloilo
Segments: Metro Manila, Provincial Hub, Island Delivery, Same Day

Dynamic tables are created suspended and refreshed on demand:

```bash
./refresh_demo_data.sh PH_RETAIL_DELIVERY
```

## KPI cards

Every card below is served live from `CURATED.KPI_SUMMARY`. The app keeps the
original literal as a fallback, so it still renders if Snowflake is unreachable.

| Card | Value | Backed by |
|---|---|---|
| Deliveries (MTD) | `4.8M` | total across Delivery Hubs |
| On-Time Rate | `91%` | average per event |
| Avg Delivery Time | `2.8 hrs` | average per event |
| Active Riders | `24K` | total across Delivery Hubs |
| Fuel Cost/Delivery | `₱42` | average per event |
| Failed Delivery | `4.2%` | average per event |
| Rider Utilization | `84%` | average per event |


## Demo flow

1. Executive Cockpit
2. Geospatial Analytics
3. Demand & Capacity
4. Ask AI
5. Architecture & Data

## Talking points

- **3.2M parcels** - delivered monthly across 85 hubs
- **14 zones** - below 85% delivery success rate
- **4,200 zones** - H3 hexagonal delivery areas monitored
- **340% volume spike** - predicted for 11.11 sale event
- **₱450M** - annual cost of failed deliveries
- **12,000 riders** - tracked via Location Service GPS

## Business impact

- Philippine e-commerce logistics market reached $4.8B in 2023 (Ken Research)
- Failed deliveries cost Philippine e-commerce ₱28B annually (returns + redelivery) (DTI Philippines)
- H3 geospatial optimization reduces delivery costs 15-25% in complex geographies (Uber Engineering)
- Demand forecasting improves fleet utilization 20-30% during peak periods (McKinsey Logistics)

---
Generated from `generator/demo_specs/aws-philippines-retail-delivery.json`. Do not hand-edit: run
`python3 generator/gen_repo_docs.py aws-philippines-retail-delivery` instead.
