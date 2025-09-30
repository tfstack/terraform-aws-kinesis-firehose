# CloudWatch Dashboard for WAF Pipeline
resource "aws_cloudwatch_dashboard" "waf_pipeline" {
  dashboard_name = "${local.base_name}-waf-pipeline"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/WAFV2", "AllowedRequests", "WebACL", aws_wafv2_web_acl.main.name, "Region", data.aws_region.current.region],
            [".", "BlockedRequests", ".", ".", ".", "."],
            [".", "CountedRequests", ".", ".", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.region
          title   = "WAF Request Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Firehose", "DeliveryToS3.Records", "DeliveryStreamName", module.kinesis_firehose.delivery_stream_name],
            [".", "DeliveryToS3.Bytes", ".", "."],
            [".", "DeliveryToS3.Success", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.region
          title   = "Firehose Delivery Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.api.function_name],
            [".", "Errors", ".", "."],
            [".", "Duration", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.region
          title   = "Lambda Function Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/S3", "BucketSizeBytes", "BucketName", module.s3_bucket.bucket_id, "StorageType", "StandardStorage"],
            [".", "NumberOfObjects", ".", ".", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.region
          title   = "S3 Storage Metrics"
          period  = 300
        }
      }
    ]
  })
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "waf_blocked_requests" {
  alarm_name          = "${local.base_name}-waf-blocked-requests"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors blocked requests by WAF"
  alarm_actions       = []

  dimensions = {
    WebACL = aws_wafv2_web_acl.main.name
    Region = data.aws_region.current.region
  }

  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${local.base_name}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors Lambda function errors"
  alarm_actions       = []

  dimensions = {
    FunctionName = aws_lambda_function.api.function_name
  }

  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "firehose_delivery_failures" {
  alarm_name          = "${local.base_name}-firehose-delivery-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DeliveryToS3.Failed"
  namespace           = "AWS/Firehose"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors Firehose delivery failures"
  alarm_actions       = []

  dimensions = {
    DeliveryStreamName = module.kinesis_firehose.delivery_stream_name
  }

  tags = local.tags
}
