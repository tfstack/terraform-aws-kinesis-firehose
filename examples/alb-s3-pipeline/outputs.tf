output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = module.alb.alb_dns
}

output "alb_arn" {
  description = "ARN of the ALB"
  value       = module.alb.alb_arn
}

output "firehose_delivery_stream_arn" {
  description = "ARN of the Kinesis Firehose delivery stream"
  value       = module.kinesis_firehose.delivery_stream_arn
}

output "firehose_delivery_stream_name" {
  description = "Name of the Kinesis Firehose delivery stream"
  value       = module.kinesis_firehose.delivery_stream_name
}

output "s3_bucket_id" {
  description = "ID of the S3 bucket for application logs"
  value       = module.s3_bucket.bucket_id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for application logs"
  value       = module.s3_bucket.bucket_arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.api.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.api.arn
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for Firehose"
  value       = aws_cloudwatch_log_group.firehose.name
}

output "firehose_role_arn" {
  description = "ARN of the IAM role for Kinesis Firehose"
  value       = aws_iam_role.firehose.arn
}

output "test_commands" {
  description = "Example curl commands to test the ALB + Lambda pipeline"
  value = {
    health_check   = "curl -v http://${module.alb.alb_dns}/health"
    hello_endpoint = "curl -v http://${module.alb.alb_dns}/api/hello"
    info_endpoint  = "curl -v http://${module.alb.alb_dns}/api/info"
    root_endpoint  = "curl -v http://${module.alb.alb_dns}/"
    not_found      = "curl -v http://${module.alb.alb_dns}/nonexistent"
    post_request   = "curl -v -X POST http://${module.alb.alb_dns}/api/hello -H 'Content-Type: application/json' -d '{\"test\": \"data\"}'"
    test_request   = "curl -v 'http://${module.alb.alb_dns}/api/hello?test=malicious'"
  }
}

output "alb_url" {
  description = "The ALB URL for testing"
  value       = "http://${module.alb.alb_dns}"
}

output "test_script" {
  description = "A bash script to test the ALB + Lambda pipeline"
  value       = <<-EOT
#!/bin/bash
# Test script for ALB S3 Pipeline

echo "Testing ALB S3 Pipeline..."
echo "ALB URL: http://${module.alb.alb_dns}"
echo ""

# Test basic endpoints
echo "1. Testing health endpoint..."
curl -s "http://${module.alb.alb_dns}/health" | jq '.'

echo -e "\n2. Testing hello endpoint..."
curl -s "http://${module.alb.alb_dns}/api/hello" | jq '.'

echo -e "\n3. Testing info endpoint..."
curl -s "http://${module.alb.alb_dns}/api/info" | jq '.'

echo -e "\n4. Testing root endpoint..."
curl -s "http://${module.alb.alb_dns}/" | jq '.'

echo -e "\n5. Testing 404 endpoint..."
curl -s "http://${module.alb.alb_dns}/nonexistent" | jq '.'

echo -e "\n6. Testing POST request..."
curl -s -X POST "http://${module.alb.alb_dns}/api/hello" \
  -H "Content-Type: application/json" \
  -d '{"test": "data", "timestamp": "'$(date -Iseconds)'"}' | jq '.'

echo -e "\n7. Testing various request types..."
curl -s "http://${module.alb.alb_dns}/api/hello?test=malicious&param=1" | jq '.'

echo -e "\n8. Testing different user agents..."
curl -s "http://${module.alb.alb_dns}/api/hello" \
  -H "User-Agent: TestAgent/1.0" | jq '.'

echo -e "\n9. Testing query parameters..."
curl -s "http://${module.alb.alb_dns}/api/hello?user=admin&action=test" | jq '.'

echo -e "\n10. Testing multiple requests to generate traffic..."
for i in {1..5}; do
  echo "Request $i..."
  curl -s "http://${module.alb.alb_dns}/api/hello?request=$i" > /dev/null
  sleep 1
done

echo -e "\nTest completed! Check CloudWatch logs and S3 bucket for application logs."
echo "S3 Bucket: ${module.s3_bucket.bucket_id}"
echo "CloudWatch Log Group: ${aws_cloudwatch_log_group.firehose.name}"
EOT
}

output "s3_ls_command" {
  description = "Command to list S3 bucket contents"
  value       = "aws s3 ls s3://${module.s3_bucket.bucket_id}/ --recursive"
}

output "s3_view_gz_command" {
  description = "Command template to view the content of a GZ file from S3 (replace FILE_PATH with actual file path)"
  value       = "aws s3 cp s3://${module.s3_bucket.bucket_id}/FILE_PATH - | gunzip | jq '.'"
}

output "s3_view_latest_log" {
  description = "Command to view the latest log file from S3"
  value       = <<-EOT
# Find and view the latest log file
LATEST_FILE=$(aws s3 ls s3://${module.s3_bucket.bucket_id}/waf-logs/ --recursive | sort | tail -1 | awk '{print $4}')
aws s3 cp s3://${module.s3_bucket.bucket_id}/$LATEST_FILE - | gunzip | jq '.'
EOT
}

output "s3_view_all_logs" {
  description = "Command to view all log files from S3 (concatenated)"
  value       = <<-EOT
# View all log files concatenated
aws s3 ls s3://${module.s3_bucket.bucket_id}/waf-logs/ --recursive | awk '{print $4}' | while read file; do
  echo "=== $file ==="
  aws s3 cp s3://${module.s3_bucket.bucket_id}/$file - | gunzip | jq '.'
done
EOT
}
