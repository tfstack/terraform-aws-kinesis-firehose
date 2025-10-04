output "test_commands" {
  description = "Example commands to test the S3 Firehose pipeline"
  value = {
    invoke_producer = "aws lambda invoke --function-name ${aws_lambda_function.producer.function_name} --region ${data.aws_region.current.region} --payload '{}' response.json && cat response.json | jq '.'"
    invoke_consumer = "aws lambda invoke --function-name ${aws_lambda_function.consumer.function_name} --region ${data.aws_region.current.region} --payload '{}' response.json && cat response.json | jq '.'"
    check_s3_logs   = "aws s3 ls s3://${module.s3_bucket.bucket_id}/firehose/ --recursive"
    view_latest_log = "aws s3 ls s3://${module.s3_bucket.bucket_id}/firehose/ --recursive | sort | tail -1 | awk '{print $4}' | xargs -I {} aws s3 cp s3://${module.s3_bucket.bucket_id}/{} - | gunzip | jq '.'"
  }
}

output "test_script" {
  description = "A bash script to test the S3 Firehose pipeline"
  value       = <<-EOT
#!/bin/bash
# Test script for S3 Firehose Pipeline

echo "Testing S3 Firehose Pipeline..."
echo "S3 Bucket: ${module.s3_bucket.bucket_id}"
echo "Firehose Stream: ${module.kinesis_firehose.delivery_stream_name}"
echo ""

# Test producer Lambda
echo "1. Testing producer Lambda function..."
echo "Using region: $(aws configure get region || echo '${data.aws_region.current.region}')"
aws lambda invoke --function-name ${aws_lambda_function.producer.function_name} \
  --region ${data.aws_region.current.region} \
  --payload '{}' \
  producer_response.json
echo "Producer response:"
cat producer_response.json | jq '.'
rm producer_response.json

echo -e "\n2. Waiting for data to flow through Firehose (30 seconds)..."
sleep 30

# Check S3 for logs
echo -e "\n3. Checking S3 bucket for logs..."
aws s3 ls s3://${module.s3_bucket.bucket_id}/firehose/ --recursive

echo -e "\n4. Viewing latest log file..."
LATEST_FILE=$(aws s3 ls s3://${module.s3_bucket.bucket_id}/firehose/ --recursive | sort | tail -1 | awk '{print $4}')
if [ ! -z "$LATEST_FILE" ]; then
  echo "Latest file: $LATEST_FILE"
  aws s3 cp s3://${module.s3_bucket.bucket_id}/$LATEST_FILE - | gunzip | jq '.'
else
  echo "No log files found yet. Wait a bit longer and try again."
fi

echo -e "\n5. Testing consumer Lambda function..."
aws lambda invoke --function-name ${aws_lambda_function.consumer.function_name} \
  --region ${data.aws_region.current.region} \
  --payload '{}' \
  consumer_response.json
echo "Consumer response:"
cat consumer_response.json | jq '.'
rm consumer_response.json

echo -e "\n6. Checking CloudWatch logs..."
echo "Firehose logs: ${aws_cloudwatch_log_group.firehose.name}"
echo "Lambda logs: ${aws_cloudwatch_log_group.lambda_logs["general"].name}"

echo -e "\n7. Testing multiple producer invocations..."
for i in {1..3}; do
  echo "Producer invocation $i..."
  aws lambda invoke --function-name ${aws_lambda_function.producer.function_name} \
    --region ${data.aws_region.current.region} \
    --payload '{}' \
    /dev/null
  sleep 5
done

echo -e "\n8. Final S3 bucket contents:"
aws s3 ls s3://${module.s3_bucket.bucket_id}/firehose/ --recursive

echo -e "\nTest completed! Check S3 bucket and CloudWatch logs for results."
echo "S3 Bucket: ${module.s3_bucket.bucket_id}"
echo "CloudWatch Log Groups:"
echo "  - Firehose: ${aws_cloudwatch_log_group.firehose.name}"
echo "  - Lambda: ${aws_cloudwatch_log_group.lambda_logs["general"].name}"
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
LATEST_FILE=$(aws s3 ls s3://${module.s3_bucket.bucket_id}/firehose/ --recursive | sort | tail -1 | awk '{print $4}')
aws s3 cp s3://${module.s3_bucket.bucket_id}/$LATEST_FILE - | gunzip | jq '.'
EOT
}

output "s3_view_all_logs" {
  description = "Command to view all log files from S3 (concatenated)"
  value       = <<-EOT
# View all log files concatenated
aws s3 ls s3://${module.s3_bucket.bucket_id}/firehose/ --recursive | awk '{print $4}' | while read file; do
  echo "=== $file ==="
  aws s3 cp s3://${module.s3_bucket.bucket_id}/$file - | gunzip | jq '.'
done
EOT
}
