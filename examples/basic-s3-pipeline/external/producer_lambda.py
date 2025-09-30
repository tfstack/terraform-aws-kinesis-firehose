import json
import boto3
import random
import base64
import os
from datetime import datetime

def handler(event, context):
    """
    Producer Lambda - generates test data and sends to Kinesis Firehose
    Triggered by EventBridge scheduler every 2 minutes
    """

    firehose = boto3.client('firehose')
    delivery_stream_name = os.environ['DELIVERY_STREAM_NAME']

    # Generate test data
    test_records = []
    for i in range(5):  # Send 5 records per batch
        record_data = {
            "id": f"record-{random.randint(1000, 9999)}",
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "user_id": f"user-{random.randint(100, 999)}",
            "action": random.choice(["login", "logout", "view_page", "purchase", "search"]),
            "status": random.choice(["success", "error", "pending"]),
            "value": random.randint(1, 1000),
            "source": "producer-lambda"
        }

        # Firehose will automatically base64-encode the data, so send raw bytes
        test_records.append({'Data': json.dumps(record_data)})

    try:
        # Send to Firehose
        response = firehose.put_record_batch(
            DeliveryStreamName=delivery_stream_name,
            Records=test_records
        )

        success_count = len(test_records) - response['FailedPutCount']

        print(f"✅ Producer: Sent {success_count}/{len(test_records)} records to Firehose")

        # Put custom metric
        cloudwatch = boto3.client('cloudwatch')
        cloudwatch.put_metric_data(
            Namespace='KinesisFirehose/Pipeline',
            MetricData=[
                {
                    'MetricName': 'RecordsProduced',
                    'Value': success_count,
                    'Unit': 'Count'
                }
            ]
        )

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Successfully sent {success_count} records',
                'failed_count': response['FailedPutCount']
            })
        }

    except Exception as e:
        print(f"❌ Producer error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
