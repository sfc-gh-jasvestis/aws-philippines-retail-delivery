-- ============================================================================
-- 08_AGENT.SQL — Cortex Agent for Last-Mile Delivery Optimization & Geospatial Intelligence
-- ============================================================================
USE DATABASE DELIVERY_LOGISTICS;
USE SCHEMA APP;

CREATE OR REPLACE CORTEX AGENT APP.LOGISTICS_INTELLIGENCE_AGENT
  COMMENT = 'Last-Mile Delivery Optimization & Geospatial Intelligence AI Assistant'
  MODEL = 'claude-opus-4-8'
  TOOLS = (
    SEMANTIC_VIEW_TOOL(SEMANTIC_VIEW => 'DELIVERY_LOGISTICS.APP.DELIVERY_ANALYTICS'),    CORTEX_SEARCH_TOOL(CORTEX_SEARCH_SERVICE => 'DELIVERY_LOGISTICS.SEARCH.DELIVERY_NOTES_SEARCH', TOOL_DESCRIPTION => 'Search documents for Retail & E-Commerce information')
  )
  SYSTEM_PROMPT = 'You are the Logistics Intelligence Agent for a Philippine delivery company operating 85 hubs, 12,000 riders, and 3.2M monthly parcels across the Philippine archipelago.';
