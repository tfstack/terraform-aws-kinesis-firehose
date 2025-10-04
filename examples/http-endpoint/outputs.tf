output "http_endpoint_url" {
  description = "The HTTP endpoint URL"
  value       = "https://httpbin.org/post"
}

output "test_commands" {
  description = "Example commands to test the HTTP endpoint Firehose pipeline"
  value = {
    invoke_processor   = "aws lambda invoke --function-name ${aws_lambda_function.firehose_processor.function_name} --region ${data.aws_region.current.region} --cli-binary-format raw-in-base64-out --payload '{\"records\":[{\"recordId\":\"test-1\",\"data\":\"eyJ0ZXN0IjoidGVzdCJ9\"}]}' response.json && cat response.json | jq '.'"
    check_s3_backup    = "aws s3 ls s3://${module.s3_bucket.bucket_id}/http-backup/ --recursive"
    view_latest_backup = "aws s3 ls s3://${module.s3_bucket.bucket_id}/http-backup/ --recursive | sort | tail -1 | awk '{print $4}' | xargs -I {} aws s3 cp s3://${module.s3_bucket.bucket_id}/{} - | gunzip | jq '.'"
    test_http_endpoint = "curl -X POST https://httpbin.org/post -H 'Content-Type: application/json' -d '{\"test\": \"data\", \"timestamp\": \"$(date -Iseconds)\"}'"
    send_to_firehose   = "aws firehose put-record --delivery-stream-name ${module.kinesis_firehose.delivery_stream_name} --region ${data.aws_region.current.region} --record '{\"Data\":\"$(echo \"{\\\"test\\\": \\\"firehose-test\\\", \\\"timestamp\\\": \\\"$(date -Iseconds)\\\"}\" | base64 -w 0)\"}'"
    test_s3_backup     = "echo 'To test S3 backup, change HTTP endpoint URL in main.tf to invalid URL, then run: terraform apply && send_to_firehose command'"
  }
}

output "test_script" {
  description = "A bash script to test the HTTP endpoint Firehose pipeline"
  value       = <<-EOT
#!/bin/bash
# Test script for HTTP Endpoint Firehose Pipeline

echo "Testing HTTP Endpoint Firehose Pipeline..."
echo "S3 Bucket: ${module.s3_bucket.bucket_id}"
echo "Firehose Stream: ${module.kinesis_firehose.delivery_stream_name}"
echo "HTTP Endpoint: https://httpbin.org/post"
echo ""

# Test HTTP endpoint directly
echo "1. Testing HTTP endpoint directly..."
curl -X POST https://httpbin.org/post \
  -H "Content-Type: application/json" \
  -d '{"test": "data", "timestamp": "'$(date -Iseconds)'", "source": "direct-test"}' \
  | jq '.'

echo -e "\n2. Testing Lambda processor function..."
# Create proper Firehose payload with base64-encoded data
aws lambda invoke --function-name ${aws_lambda_function.firehose_processor.function_name} \
  --region ${data.aws_region.current.region} \
  --cli-binary-format raw-in-base64-out \
  --payload '{"records":[{"recordId":"test-1","data":"eyJ0ZXN0IjoidGVzdCJ9"}]}' \
  processor_response.json
echo "Processor response:"
cat processor_response.json | jq '.'
rm processor_response.json

echo -e "\n3. Sending test data to Firehose delivery stream..."
# Note: In a real scenario, you would send data to the Firehose delivery stream
# For this example, we'll simulate by checking if there are any delivery failures
echo "Checking Firehose delivery stream status..."
aws firehose describe-delivery-stream --delivery-stream-name ${module.kinesis_firehose.delivery_stream_name} --region ${data.aws_region.current.region} | jq '.DeliveryStreamDescription.DeliveryStreamStatus'

echo -e "\n4. Waiting for data to be processed and backed up (30 seconds)..."
sleep 30

# Check S3 for backup data
echo -e "\n5. Checking S3 bucket for backup data..."
aws s3 ls s3://${module.s3_bucket.bucket_id}/http-backup/ --recursive

echo -e "\n6. Viewing latest backup file..."
LATEST_FILE=$(aws s3 ls s3://${module.s3_bucket.bucket_id}/http-backup/ --recursive | sort | tail -1 | awk '{print $4}')
if [ ! -z "$LATEST_FILE" ]; then
  echo "Latest backup file: $LATEST_FILE"
  aws s3 cp s3://${module.s3_bucket.bucket_id}/$LATEST_FILE - | gunzip | jq '.'
else
  echo "No backup files found yet. Data may still be processing..."
  echo "S3 backup is configured to store ALL data sent through Firehose."
fi

echo -e "\n7. Checking CloudWatch logs..."
echo "Firehose logs: ${aws_cloudwatch_log_group.firehose.name}"

echo -e "\n8. Testing Firehose data flow..."
echo "Sending test data to Firehose delivery stream..."

# Send test data to Firehose
for i in {1..3}; do
  echo "Sending test record $i to Firehose..."
  aws firehose put-record \
    --delivery-stream-name ${module.kinesis_firehose.delivery_stream_name} \
    --region ${data.aws_region.current.region} \
    --record "{\"Data\":\"$(echo "{\"test\": \"firehose-test-$i\", \"timestamp\": \"$(date -Iseconds)\", \"request\": $i}" | base64 -w 0)\"}" \
    > /dev/null
  sleep 2
done

echo "Data sent to Firehose. Waiting for processing and S3 backup (60 seconds)..."
sleep 60

echo -e "\n9. Final S3 bucket contents:"
aws s3 ls s3://${module.s3_bucket.bucket_id}/http-backup/ --recursive

echo -e "\nTest completed! Check S3 bucket and CloudWatch logs for results."
echo "S3 Bucket: ${module.s3_bucket.bucket_id}"
echo "CloudWatch Log Group: ${aws_cloudwatch_log_group.firehose.name}"
echo "HTTP Endpoint: https://httpbin.org/post"
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

output "s3_view_latest_backup" {
  description = "Command to view the latest backup file from S3"
  value       = <<-EOT
# Find and view the latest backup file
LATEST_FILE=$(aws s3 ls s3://${module.s3_bucket.bucket_id}/http-backup/ --recursive | sort | tail -1 | awk '{print $4}')
aws s3 cp s3://${module.s3_bucket.bucket_id}/$LATEST_FILE - | gunzip | jq '.'
EOT
}

output "s3_view_all_backups" {
  description = "Command to view all backup files from S3 (concatenated)"
  value       = <<-EOT
# View all backup files concatenated
aws s3 ls s3://${module.s3_bucket.bucket_id}/http-backup/ --recursive | awk '{print $4}' | while read file; do
  echo "=== $file ==="
  aws s3 cp s3://${module.s3_bucket.bucket_id}/$file - | gunzip | jq '.'
done
EOT
}
