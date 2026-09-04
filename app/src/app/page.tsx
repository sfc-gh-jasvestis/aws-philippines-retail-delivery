'use client';

import { useEffect, useState } from 'react';
import { AppLayout } from '@/components/AppLayout';
import { KPICard } from '@/components/KPICard';
import { Chart } from '@/components/Chart';
import { DataTable } from '@/components/DataTable';
import { AskAI } from '@/components/AskAI';
import { ActionMemo } from '@/components/ActionMemo';
import { GeoMap } from '@/components/GeoMap';
import { ArchitectureDiagram } from '@/components/ArchitectureDiagram';

interface DemoNarrative {
  title: string;
  duration: string;
  thesis: string;
  tabs: any[];
}

export default function HomePage() {
  const [narrative, setNarrative] = useState<DemoNarrative | null>(null);
  const [data, setData] = useState<any>(null);

  useEffect(() => {
    fetch('/demo_narrative.json')
      .then((r) => r.json())
      .then(setNarrative)
      .catch(() => {});
    fetch('/api/data')
      .then((r) => r.json())
      .then(setData)
      .catch(() => {});
  }, []);


  // KPI values come from /api/data, which reads CURATED.KPI_SUMMARY. The literal
  // stays as a fallback so the card still renders if the API is unavailable.
  const kpiVal = (title: string, fallback: string): string =>
    (data?.kpiCards as { title: string; value: string }[] | undefined)
      ?.find((k) => k.title === title)?.value ?? fallback;

  const title = narrative?.title || 'SEA AWS Demo';

  const executiveCockpit = (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <KPICard title="Deliveries (MTD)" value={kpiVal('Deliveries (MTD)', '4.8M')} status="neutral" />
        <KPICard title="On-Time Rate" value={kpiVal('On-Time Rate', '91%')} status="warning" />
        <KPICard title="Avg Delivery Time" value={kpiVal('Avg Delivery Time', '2.8 hrs')} status="neutral" />
        <KPICard title="Active Riders" value={kpiVal('Active Riders', '24K')} status="neutral" />
      </div>
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <div className="lg:col-span-1">
          <GeoMap
            country="philippines"
            labels={{ entity: 'Hubs', event: 'Location Pings', alert: 'Failed Drops' }}
            regions={data?.regions}
            markers={[{"label": "Quezon City", "value": "Hub: 4.2K orders/hr", "color": "blue", "size": "lg"}, {"label": "Makati", "value": "Hub: 2.8K orders/hr", "color": "green", "size": "lg"}, {"label": "Cebu", "value": "Hub: 1.2K orders/hr", "color": "green", "size": "md"}, {"label": "Davao", "value": "Hub: 800 orders/hr", "color": "amber", "size": "md"}]}
            routes={[]}
            title="Geographic Overview"
            height={400}
          />
        </div>
        <div className="lg:col-span-1 grid grid-cols-1 gap-4">
      <div className="grid grid-cols-1 gap-4 grid-cols-1">
        <Chart
          data={data?.timeseries || [{ period: 'Jan', value: 112 }, { period: 'Feb', value: 118 }, { period: 'Mar', value: 135 }, { period: 'Apr', value: 148 }, { period: 'May', value: 156 }, { period: 'Jun', value: 142 }, { period: 'Jul', value: 138 }, { period: 'Aug', value: 151 }, { period: 'Sep', value: 144 }, { period: 'Oct', value: 132 }, { period: 'Nov', value: 121 }, { period: 'Dec', value: 115 }]}
          type="line"
          xKey="period"
          yKeys={[{ key: 'value', name: 'Deliveries (K)' }]}
          title="Delivery Volume (Hourly)"
        />
        <Chart
          data={data?.categories || [{ category: 'North', count: 82 }, { category: 'Central', count: 74 }, { category: 'South', count: 91 }, { category: 'Highland', count: 68 }, { category: 'Coastal', count: 77 }]}
          type="bar"
          xKey="category"
          yKeys={[{ key: 'count', name: 'On-Time %' }]}
          title="SLA by Metro Area"
        />
      </div>
        </div>
      </div>
      <DataTable
        columns={[
          { key: 'id', header: '#' },
          { key: 'name', header: 'Hub' },
          { key: 'region', header: 'Region' },
          { key: 'status', header: 'SLA' },
          { key: 'm1', header: 'Deliveries/Day' },
          { key: 'm2', header: 'Delivery Time' },
          { key: 'm3', header: 'Fuel Cost Delivery' },
          { key: 'events', header: 'Location Pings' },
          { key: 'alerts', header: 'Failed Drops' },
        ]}
        data={data?.entities || []}
        title="Hub Performance"
      />
    </div>
  );

  const domainTab1 = (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <KPICard title="Fuel Cost/Delivery" value={kpiVal('Fuel Cost/Delivery', '₱42')} />
        <KPICard title="Failed Delivery" value={kpiVal('Failed Delivery', '4.2%')} />
        <KPICard title="Rider Utilization" value={kpiVal('Rider Utilization', '84%')} />
      </div>
      <Chart
        data={data?.detail || [{ x: 'Mon', y: 24 }, { x: 'Tue', y: 28 }, { x: 'Wed', y: 22 }, { x: 'Thu', y: 31 }, { x: 'Fri', y: 26 }, { x: 'Sat', y: 19 }, { x: 'Sun', y: 23 }]}
        type="area"
        xKey="x"
        yKeys={[{ key: 'y', name: 'Minutes' }]}
        title="Delivery Time by Distance"
        height={400}
      />
    </div>
  );

  const domainTab2 = (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <Chart
          data={data?.breakdown || [{ label: 'Zone North', value: 35 }, { label: 'Zone Central', value: 28 }, { label: 'Zone South', value: 22 }, { label: 'Zone East', value: 15 }]}
          type="pie"
          xKey="label"
          yKeys={[{ key: 'value', name: 'Ratio' }]}
          title="Demand vs Rider Supply"
        />
        <ActionMemo
          persona={{ name: 'Mark Espiritu', role: 'VP Last-Mile Operations' }}
          context={{}}
          onGenerate={async () => {
            const memos = [
              {
                subject: 'Urgent: Operational Action Required',
                body: `Dear Leadership Team,\n\nBased on our analysis of the latest operational data, I am writing to recommend immediate action on the following critical items.\n\nKey Findings:\n- Performance metrics indicate a deviation from target KPIs in several areas\n- Predictive models suggest these trends will continue without intervention\n- Estimated impact: 12-15% improvement in efficiency if addressed within 2 weeks\n\nI recommend we schedule a review meeting this week to align on next steps.\n\nBest regards`,
                urgency: 'HIGH' as const,
                actions: ['Activate surge riders for 11.11 sale (projected +180% volume)', 'Deploy cold-chain motorcycle fleet for grocery pilot', 'Optimize Cebu hub routes (currently 12% above target time)'],
              },
              {
                subject: 'Weekly Performance Summary & Recommendations',
                body: `Dear Team,\n\nPlease find below the AI-generated weekly performance summary.\n\nHighlights:\n- Overall performance trending 8% above quarterly targets\n- Three areas identified for optimization with potential 20% cost savings\n- New anomaly patterns detected that warrant monitoring\n\nRecommended next steps are outlined below. Please review and confirm priority assignments by end of week.\n\nRegards`,
                urgency: 'MEDIUM' as const,
                actions: ['Activate surge riders for 11.11 sale (projected +180% volume)', 'Deploy cold-chain motorcycle fleet for grocery pilot', 'Optimize Cebu hub routes (currently 12% above target time)'],
              },
              {
                subject: 'Strategic Initiative: Data-Driven Optimization',
                body: `Dear Stakeholders,\n\nOur AI analysis has identified a significant opportunity for operational optimization.\n\nExecutive Summary:\n- Current utilization rate: 78% (target: 90%)\n- Root cause analysis points to 3 primary factors\n- Projected ROI of recommended changes: 2.4x within 6 months\n\nThe attached data supports a phased implementation approach starting with the highest-impact items.\n\nPlease advise on scheduling a planning session.\n\nBest regards`,
                urgency: 'HIGH' as const,
                actions: ['Activate surge riders for 11.11 sale (projected +180% volume)', 'Deploy cold-chain motorcycle fleet for grocery pilot', 'Optimize Cebu hub routes (currently 12% above target time)'],
              },
            ];
            return memos[Math.floor(Math.random() * memos.length)];
          }}
        />
      </div>
    </div>
  );

  const askAiTab = (
    <div className="h-[600px]">
      <AskAI
        title="Ask AI"
        sampleQuestions={[
          'Which areas have the worst delivery times?',
          'Show rider supply vs demand gap by hour',
          'What is the optimal dark store location for Quezon City?',
        ]}
        mode="sql"
        onSubmit={async (question, mode) => {
          return {
            answer: `[Demo Mode] Response to: "${question}" (${mode} mode). Connect to Snowflake for live data.`,
            sql: mode === 'sql' ? 'SELECT * FROM CURATED.SUMMARY LIMIT 10;' : undefined,
          };
        }}
      />
    </div>
  );

  const architectureTab = (
    <ArchitectureDiagram
      snowflakeFeatures={['Dynamic Tables (5-min refresh)', 'ML Functions (Forecast + Anomaly)', 'Cortex Search + Agent', 'Semantic View + Intelligence', 'Alerts + Notifications']}
      awsServices={[{ name: 'Amazon S3', role: 'Strategy Docs' }, { name: 'Amazon S3 + Kinesis', role: 'Integration' }, { name: 'Amazon SNS', role: 'Integration' }, { name: 'Amazon QuickSight + Q', role: 'Integration' }]}
    />
  );

  const tabs = [
    { id: 'executive-cockpit', label: 'Executive Cockpit', icon: '📊', content: executiveCockpit },
    { id: 'domain-1', label: 'Route Optimization', icon: '📈', content: domainTab1 },
    { id: 'domain-2', label: 'Capacity', icon: '⚡', content: domainTab2 },
    { id: 'ask-ai', label: 'Ask AI', icon: '🤖', content: askAiTab },
    { id: 'architecture', label: 'Architecture & Data', icon: '🏗️', content: architectureTab },
  ];

  return (
    <AppLayout
      title={title}
      tabs={tabs}
      narrative={narrative}
    />
  );
}
