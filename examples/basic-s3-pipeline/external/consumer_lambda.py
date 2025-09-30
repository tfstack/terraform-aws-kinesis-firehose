import json
import boto3
import gzip
import os
from urllib.parse import unquote_plus

def handler(event, context):
    """
    Consumer Lambda - validates processed data from S3
    Triggered by S3 PUT events when Firehose writes files
    """

    s3 = boto3.client('s3')
    sns = boto3.client('sns')
    cloudwatch = boto3.client('cloudwatch')

    results = []

    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = unquote_plus(record['s3']['object']['key'])

        try:
            print(f"🔍 Consumer: Processing {key}")

            # Get object from S3
            response = s3.get_object(Bucket=bucket, Key=key)
            content = response['Body'].read()

            # Decompress if gzipped
            if key.endswith('.gz'):
                content = gzip.decompress(content)

            # Parse and validate data
            lines = content.decode('utf-8').strip().split('\n')
            valid_records = 0
            invalid_records = 0

            for line in lines:
                if line.strip():
                    try:
                        data = json.loads(line)

                        # Validate required fields from processor
                        if all(field in data for field in ['original_data', 'processed_at']):
                            # Check original data structure
                            original = data['original_data']
                            if all(field in original for field in ['id', 'timestamp', 'user_id', 'action']):
                                valid_records += 1
                            else:
                                invalid_records += 1
                        else:
                            invalid_records += 1

                    except json.JSONDecodeError:
                        invalid_records += 1

            total_records = valid_records + invalid_records
            success_rate = (valid_records / total_records * 100) if total_records > 0 else 0

            result = {
                'file': key,
                'total_records': total_records,
                'valid_records': valid_records,
                'invalid_records': invalid_records,
                'success_rate': success_rate
            }
            results.append(result)

            print(f"📊 Consumer: {key} - {valid_records}/{total_records} valid records ({success_rate:.1f}%)")

            # Put CloudWatch metrics
            cloudwatch.put_metric_data(
                Namespace='KinesisFirehose/Pipeline',
                MetricData=[
                    {
                        'MetricName': 'RecordsConsumed',
                        'Value': valid_records,
                        'Unit': 'Count'
                    },
                    {
                        'MetricName': 'DataQuality',
                        'Value': success_rate,
                        'Unit': 'Percent'
                    }
                ]
            )

        except Exception as e:
            print(f"❌ Consumer error processing {key}: {str(e)}")
            results.append({
                'file': key,
                'error': str(e)
            })

    # Send SNS notification with results
    try:
        total_valid = sum(r.get('valid_records', 0) for r in results)
        total_files = len(results)

        message = {
            "pipeline_status": "SUCCESS" if total_valid > 0 else "FAILED",
            "timestamp": context.aws_request_id,
            "summary": {
                "files_processed": total_files,
                "total_valid_records": total_valid,
                "results": results
            }
        }

        sns_topic_arn = os.environ['SNS_TOPIC_ARN']

        sns.publish(
            TopicArn=sns_topic_arn,
            Subject=f"Firehose Pipeline Status: {message['pipeline_status']}",
            Message=json.dumps(message, indent=2)
        )

        print(f"📢 Consumer: Sent SNS notification - {total_valid} records processed from {total_files} files")

    except Exception as e:
        print(f"❌ Consumer: Failed to send SNS notification: {str(e)}")

    return {
        'statusCode': 200,
        'body': json.dumps({
            'processed_files': len(results),
            'total_valid_records': sum(r.get('valid_records', 0) for r in results)
        })
    }
