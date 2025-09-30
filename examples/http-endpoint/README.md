# HTTP Endpoint Pipeline - Kinesis Firehose with HTTP Destination

A simple example demonstrating Kinesis Firehose with HTTP endpoint destination, including S3 backup and Lambda processing.

## Quick Start

```bash
terraform init
terraform apply
```

## Architecture

```plaintext
Data → Kinesis Firehose → Lambda Processor → HTTP Endpoint (httpbin.org)
                                    ↓
                            S3 Backup (AllData)
                                    ↓
                            CloudWatch Logs
```

## What Gets Created

- **Kinesis Firehose** delivery stream with HTTP endpoint destination
- **Lambda Processor** for data transformation before HTTP delivery
- **S3 Bucket** for backing up all data (not just failures)
- **HTTP Endpoint** configuration pointing to httpbin.org
- **CloudWatch Logs** for monitoring and debugging
- **IAM Roles** with least privilege permissions

## Testing

Use the test commands from Terraform outputs:

```bash
# Test Lambda processor
aws lambda invoke --function-name http-endpoint-xxxx-processor --region ap-southeast-2 --cli-binary-format raw-in-base64-out --payload '{"records":[{"recordId":"test-1","data":"eyJ0ZXN0IjoidGVzdCJ9"}]}' response.json && cat response.json | jq '.'

# Send data to Firehose
aws firehose put-record --delivery-stream-name http-endpoint-xxxx-stream --region ap-southeast-2 --record '{"Data":"$(echo "{\"test\": \"firehose-test\", \"timestamp\": \"$(date -Iseconds)\"}" | base64 -w 0)"}'

# Check S3 for backup data
aws s3 ls s3://http-endpoint-xxxx/ --recursive
```

## Data Flow

1. **Data** is sent to Kinesis Firehose delivery stream
2. **Firehose** processes data through Lambda processor
3. **Lambda** transforms and enriches the data
4. **Firehose** delivers processed data to HTTP endpoint
5. **S3** backs up all data for reliability
6. **CloudWatch** logs all operations for monitoring

## Configuration

- **HTTP Endpoint**: httpbin.org (test endpoint)
- **S3 Backup**: AllData mode (backups everything)
- **Buffer settings**: 60 seconds or 5 MB
- **Compression**: GZIP
- **Processing**: Lambda function for data transformation

## Monitoring

Check CloudWatch logs for:

- Firehose delivery logs
- Lambda processor execution logs
- HTTP endpoint delivery status
- S3 backup operations

## Cleanup

```bash
terraform destroy
```
