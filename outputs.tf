output "delivery_stream_arn" {
  description = "The ARN of the Kinesis Firehose delivery stream"
  value       = aws_kinesis_firehose_delivery_stream.this.arn
}

output "delivery_stream_name" {
  description = "The name of the Kinesis Firehose delivery stream"
  value       = aws_kinesis_firehose_delivery_stream.this.name
}

output "delivery_stream_destination" {
  description = "The destination of the Kinesis Firehose delivery stream"
  value       = aws_kinesis_firehose_delivery_stream.this.destination
}

output "delivery_stream_version_id" {
  description = "The version ID of the Kinesis Firehose delivery stream"
  value       = aws_kinesis_firehose_delivery_stream.this.version_id
}

output "delivery_stream_tags_all" {
  description = "A map of tags assigned to the resource, including those inherited from the provider default_tags configuration block"
  value       = aws_kinesis_firehose_delivery_stream.this.tags_all
}

output "cloudwatch_log_group_arn" {
  description = "The ARN of the CloudWatch log group (only created when create_cloudwatch_log_group is true)"
  value = var.create_cloudwatch_log_group ? (
    var.cloudwatch_log_group_force_destroy ?
    aws_cloudwatch_log_group.this_force_destroy[0].arn :
    aws_cloudwatch_log_group.this_protected[0].arn
  ) : null
}

output "cloudwatch_log_group_name" {
  description = "The name of the CloudWatch log group (only created when create_cloudwatch_log_group is true)"
  value = var.create_cloudwatch_log_group ? (
    var.cloudwatch_log_group_force_destroy ?
    aws_cloudwatch_log_group.this_force_destroy[0].name :
    aws_cloudwatch_log_group.this_protected[0].name
  ) : null
}

output "cloudwatch_logs_role_arn" {
  description = "The ARN of the IAM role for CloudWatch logs (only created when create_cloudwatch_log_group is true)"
  value       = var.create_cloudwatch_log_group ? aws_iam_role.firehose_cloudwatch_logs[0].arn : null
}
