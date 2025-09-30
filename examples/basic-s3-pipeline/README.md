# Basic S3 Pipeline - Kinesis Firehose with Lambda Processing

A simple example demonstrating EventBridge + Lambda + Kinesis Firehose + S3 integration for automated data processing.

## Quick Start

```bash
terraform init
terraform apply
```

## Architecture

```plaintext
EventBridge → Producer Lambda → Kinesis Firehose → Processor Lambda → S3
                                        ↓                              ↓
                                CloudWatch Logs              Consumer Lambda
                                                                     ↓
                                                            SNS Notifications
```

## What Gets Created

- **EventBridge Rule** for scheduled data generation
- **Producer Lambda** that generates test data every 2 minutes
- **Kinesis Firehose** with Lambda processing and S3 destination
- **Processor Lambda** for data transformation during Firehose processing
- **Consumer Lambda** for data validation and SNS notifications
- **S3 Bucket** for processed data storage
- **CloudWatch Logs** for monitoring and debugging

## Testing

Use the test commands from Terraform outputs:

```bash
# Test producer Lambda
aws lambda invoke --function-name firehose-producer --region ap-southeast-2 --payload '{}' response.json && cat response.json | jq '.'

# Check S3 for processed data
aws s3 ls s3://your-bucket-name/firehose/ --recursive

# View latest processed data
aws s3 ls s3://your-bucket-name/firehose/ --recursive | sort | tail -1 | awk '{print $4}' | xargs -I {} aws s3 cp s3://your-bucket-name/{} - | gunzip | jq '.'
```

## Data Flow

1. **EventBridge** triggers producer Lambda every 2 minutes
2. **Producer Lambda** generates test data and sends to Firehose
3. **Firehose** processes data through processor Lambda
4. **Processor Lambda** transforms and enriches the data
5. **Firehose** delivers processed data to S3
6. **Consumer Lambda** validates data and sends SNS notifications

## Configuration

- **Data generation**: Every 2 minutes via EventBridge
- **S3 prefix**: `firehose/!{timestamp:yyyy/MM/dd/HH/}`
- **Compression**: GZIP
- **Log retention**: 1 day (adjustable in `main.tf`)

## Monitoring

Check CloudWatch logs for:

- Producer Lambda execution logs
- Firehose processing logs
- Consumer Lambda validation logs
- S3 delivery success metrics

## Cleanup

```bash
terraform destroy
```
