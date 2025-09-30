# ALB S3 Pipeline - Application Load Balancer with WAF and Lambda Logging

A simple example demonstrating WAF + ALB + Lambda + Kinesis Firehose + S3 integration for request logging.

## Quick Start

```bash
terraform init
terraform apply
```

## Architecture

```plaintext
Internet → WAF → ALB → Lambda Function → Kinesis Firehose → S3
```

## What Gets Created

- **VPC** with public and private subnets
- **ALB** with Lambda target
- **WAFv2** with basic security rules
- **Lambda Function** that logs requests to Firehose
- **S3 Bucket** for log storage
- **CloudWatch Dashboard** for monitoring

## Testing

Get the ALB URL from outputs and test:

```bash
curl http://your-alb-dns-name/health
curl http://your-alb-dns-name/api/hello
curl http://your-alb-dns-name/api/info
```

## Log Format

Each request generates a JSON log entry:

```json
{
  "timestamp": "2024-01-01T12:00:00.000Z",
  "requestId": "12345678-1234-1234-1234-123456789012",
  "method": "GET",
  "path": "/api/hello",
  "userAgent": "curl/7.68.0",
  "sourceIp": "203.0.113.1",
  "wafAction": "ALLOW",
  "responseCode": 200
}
```

## Configuration

- **Log retention**: 7 days (adjustable in `main.tf`)
- **WAF rules**: Common Rule Set and Known Bad Inputs
- **S3 prefix**: `waf-logs/!{timestamp:yyyy/MM/dd/}`

## Monitoring

Check CloudWatch dashboard for:

- WAF metrics (allowed/blocked requests)
- Lambda metrics (invocations, errors)
- Firehose metrics (delivery success)
- S3 metrics (storage usage)

## Cleanup

```bash
terraform destroy
```
