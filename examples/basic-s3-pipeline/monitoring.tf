# CloudWatch Dashboard for monitoring the pipeline
resource "aws_cloudwatch_dashboard" "pipeline_dashboard" {
  dashboard_name = "KinesisFirehosePipeline-${local.suffix}"

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
            ["KinesisFirehose/Pipeline", "RecordsProduced"],
            [".", "RecordsConsumed"],
          ]
          view    = "timeSeries"
          stacked = false
          region  = "ap-southeast-2"
          title   = "Records Flow"
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
            ["KinesisFirehose/Pipeline", "DataQuality"],
          ]
          view    = "timeSeries"
          stacked = false
          region  = "ap-southeast-2"
          title   = "Data Quality (%)"
          period  = 300
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 24
        height = 6

        properties = {
          query  = "SOURCE '/aws/lambda/firehose-producer-${local.suffix}' | SOURCE '/aws/lambda/firehose-consumer-${local.suffix}' | fields @timestamp, @message | sort @timestamp desc | limit 100"
          region = "ap-southeast-2"
          title  = "Recent Lambda Logs"
        }
      }
    ]
  })
}

# CloudWatch Alarm for pipeline failures
resource "aws_cloudwatch_metric_alarm" "pipeline_failure_alarm" {
  alarm_name          = "firehose-pipeline-no-data-${local.suffix}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "RecordsConsumed"
  namespace           = "KinesisFirehose/Pipeline"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "This metric monitors if no records are being consumed"
  alarm_actions       = [aws_sns_topic.pipeline_status.arn]

  insufficient_data_actions = []
}

# Output the dashboard URL
output "dashboard_url" {
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=ap-southeast-2#dashboards:name=${aws_cloudwatch_dashboard.pipeline_dashboard.dashboard_name}"
  description = "CloudWatch Dashboard URL for monitoring the pipeline"
}
