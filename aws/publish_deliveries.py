"""Publish simulated delivery-attempt events to Amazon Data Firehose (stream <prefix>-deliveries).

Firehose batches the records into S3 (deliveries/); Snowpipe loads them into RAW.LIVE_DELIVERIES.
Zone IDs come from RAW.ZONES (ZON-0000..ZON-0039). Values are seeded random.
"""
import argparse
import json
import random
import time
from datetime import datetime, timezone


def make_event(rng):
    failed = rng.random() < 0.12
    return {'zone_id': f'ZON-{rng.randint(0, 39):04d}',
            'event_ts': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3],
            'cod_php': 0 if failed else round(950 * rng.lognormvariate(0, 0.6)),
            'dwell_minutes': round((190 if failed else 85) * rng.lognormvariate(0, 0.35)),
            'status': 'FAILED' if failed else 'DELIVERED',
            'sent_ms': int(time.time() * 1000)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--region', default='us-west-2')
    ap.add_argument('--prefix', default='ph-retail-delivery')
    ap.add_argument('--count', type=int, default=40)
    ap.add_argument('--seed', type=int)
    args = ap.parse_args()
    import boto3
    firehose = boto3.client('firehose', region_name=args.region)
    stream = f'{args.prefix}-deliveries'
    rng = random.Random(args.seed)
    records = [{'Data': (json.dumps(make_event(rng)) + '\n').encode()} for _ in range(args.count)]
    for start in range(0, len(records), 500):
        out = firehose.put_record_batch(DeliveryStreamName=stream, Records=records[start:start + 500])
        if out['FailedPutCount']:
            raise RuntimeError(f"{out['FailedPutCount']} records were rejected by Firehose")
    print(f'published {args.count} delivery-attempt events to Firehose stream {stream}; S3 delivery buffers up to 60 s')


if __name__ == '__main__':
    main()
