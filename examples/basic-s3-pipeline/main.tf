terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

############################################
# Random Suffix for Resource Names
############################################

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

############################################
# Local Variables
############################################

locals {
  suffix    = random_string.suffix.result
  base_name = local.suffix != "" ? "${local.name}-${local.suffix}" : local.name
  name      = "s3-firehose"
  tags = {
    Environment = "dev"
    Project     = "s3-firehose"
  }
}

############################################
# S3 Bucket for Logs
############################################

module "s3_bucket" {
  source = "tfstack/s3/aws"

  bucket_name       = local.name
  bucket_suffix     = local.suffix
  force_destroy     = true
  enable_versioning = true

  tags = local.tags
}

############################################
# CloudWatch Logs
############################################

# CloudWatch Log Group for Firehose
resource "aws_cloudwatch_log_group" "firehose" {
  name              = "/aws/kinesisfirehose/${local.name}-waf-logs"
  retention_in_days = 1

  lifecycle {
    prevent_destroy = false
  }
}

# CloudWatch Log Groups for Lambda Functions
locals {
  lambda_functions = {
    general  = "firehose-processor"
    producer = "firehose-producer"
    consumer = "firehose-consumer"
  }
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  for_each = local.lambda_functions

  name              = "/aws/lambda/${each.value}-${local.suffix}"
  retention_in_days = 1

  lifecycle {
    prevent_destroy = false
  }

  tags = local.tags
}

# CloudWatch Log Stream for Firehose
resource "aws_cloudwatch_log_stream" "firehose" {
  name           = "S3Delivery"
  log_group_name = aws_cloudwatch_log_group.firehose.name
}

############################################
# IAM Roles and Policies
############################################

# IAM Role for Kinesis Firehose
resource "aws_iam_role" "firehose" {
  name = local.base_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Firehose S3 access
resource "aws_iam_role_policy" "firehose_s3" {
  name = "${local.base_name}-firehose-s3"
  role = aws_iam_role.firehose.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = [
          module.s3_bucket.bucket_arn,
          "${module.s3_bucket.bucket_arn}/*"
        ]
      }
    ]
  })
}

# IAM Policy for Firehose CloudWatch logs
resource "aws_iam_role_policy" "firehose_logs" {
  name = "${local.base_name}-firehose-logs"
  role = aws_iam_role.firehose.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:PutLogEvents",
          "logs:CreateLogGroup",
          "logs:CreateLogStream"
        ]
        Resource = [
          aws_cloudwatch_log_group.firehose.arn,
          "${aws_cloudwatch_log_group.firehose.arn}:*"
        ]
      }
    ]
  })
}

# IAM policy for Firehose to invoke Lambda
resource "aws_iam_role_policy" "firehose_lambda" {
  name = "firehose-lambda-${local.suffix}"
  role = aws_iam_role.firehose.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          aws_lambda_function.firehose_processor.arn
        ]
      }
    ]
  })

  depends_on = [aws_lambda_function.firehose_processor]
}

# IAM Roles for Lambda Functions
resource "aws_iam_role" "lambda_roles" {
  for_each = local.lambda_functions

  name = "${each.key}-lambda-${local.suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policies for Lambda CloudWatch logs
resource "aws_iam_role_policy" "lambda_logs" {
  for_each = local.lambda_functions

  name = "${local.base_name}-${each.key}-lambda-logs"
  role = aws_iam_role.lambda_roles[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          aws_cloudwatch_log_group.lambda_logs[each.key].arn,
          "${aws_cloudwatch_log_group.lambda_logs[each.key].arn}:*"
        ]
      }
    ]
  })
}

# Producer Lambda Firehose permissions
resource "aws_iam_role_policy" "producer_lambda_firehose" {
  name = "producer-lambda-firehose"
  role = aws_iam_role.lambda_roles["producer"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "firehose:PutRecord",
          "firehose:PutRecordBatch"
        ]
        Resource = [
          module.kinesis_firehose.delivery_stream_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      }
    ]
  })
}

# Consumer Lambda S3 and SNS permissions
resource "aws_iam_role_policy" "consumer_lambda" {
  name = "consumer-lambda"
  role = aws_iam_role.lambda_roles["consumer"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = [
          "${module.s3_bucket.bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = [
          aws_sns_topic.pipeline_status.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      }
    ]
  })
}

############################################
# Lambda Functions
############################################

# Lambda function code
data "archive_file" "lambda" {
  type        = "zip"
  output_path = "lambda_function.zip"
  source {
    content  = <<EOF
import json
import base64

def handler(event, context):
    output = []

    for record in event['records']:
        try:
            # Debug: log what we're receiving
            print(f"Processing record {record['recordId']}")
            print(f"Data type: {type(record['data'])}")
            print(f"Data content: {repr(record['data'])}")

            # Decode the base64 data first
            payload = base64.b64decode(record['data'])
            print(f"Decoded payload: {payload.decode('utf-8')}")

            # Parse the decoded JSON
            original_data = json.loads(payload.decode('utf-8'))

            # Process the data (example: add timestamp)
            processed_data = {
                'original_data': original_data,
                'processed_at': context.aws_request_id,
                'processing_timestamp': context.aws_request_id
            }

            # Encode the processed data
            encoded_data = base64.b64encode(json.dumps(processed_data).encode('utf-8')).decode('utf-8')

            output.append({
                'recordId': record['recordId'],
                'result': 'Ok',
                'data': encoded_data
            })

        except Exception as e:
            print(f"[ERROR] Processing record {record['recordId']}: {str(e)}")
            # Return the record as failed
            output.append({
                'recordId': record['recordId'],
                'result': 'ProcessingFailed',
                'data': record['data']  # Return original data
            })

    return {'records': output}
EOF
    filename = "index.py"
  }
}

# Producer Lambda ZIP
data "archive_file" "producer_lambda" {
  type        = "zip"
  output_path = "${path.module}/external/producer_lambda.zip"
  source {
    content  = file("${path.module}/external/producer_lambda.py")
    filename = "index.py"
  }
}

# Consumer Lambda ZIP
data "archive_file" "consumer_lambda" {
  type        = "zip"
  output_path = "${path.module}/external/consumer_lambda.zip"
  source {
    content  = file("${path.module}/external/consumer_lambda.py")
    filename = "index.py"
  }
}

# Lambda function for data processing
resource "aws_lambda_function" "firehose_processor" {
  filename         = "lambda_function.zip"
  function_name    = "firehose-processor-${local.suffix}"
  role             = aws_iam_role.lambda_roles["general"].arn
  handler          = "index.handler"
  runtime          = "python3.13"
  source_code_hash = data.archive_file.lambda.output_base64sha256
}

# Producer Lambda function
resource "aws_lambda_function" "producer" {
  filename      = "${path.module}/external/producer_lambda.zip"
  function_name = "firehose-producer"
  role          = aws_iam_role.lambda_roles["producer"].arn
  handler       = "index.handler"
  runtime       = "python3.13"
  timeout       = 60

  source_code_hash = data.archive_file.producer_lambda.output_base64sha256

  environment {
    variables = {
      DELIVERY_STREAM_NAME = module.kinesis_firehose.delivery_stream_name
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda_logs["producer"],
    aws_cloudwatch_log_group.lambda_logs["producer"],
  ]
}

# Consumer Lambda function
resource "aws_lambda_function" "consumer" {
  filename      = "${path.module}/external/consumer_lambda.zip"
  function_name = "firehose-consumer"
  role          = aws_iam_role.lambda_roles["consumer"].arn
  handler       = "index.handler"
  runtime       = "python3.13"
  timeout       = 300

  source_code_hash = data.archive_file.consumer_lambda.output_base64sha256

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.pipeline_status.arn
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda_logs["consumer"],
    aws_cloudwatch_log_group.lambda_logs["consumer"],
  ]
}

# Permission for Firehose to invoke Lambda
resource "aws_lambda_permission" "allow_firehose" {
  statement_id  = "AllowExecutionFromFirehose"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.firehose_processor.function_name
  principal     = "firehose.amazonaws.com"
  source_arn    = "arn:aws:firehose:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:deliverystream/firehose-delivery-stream"
}

# Permission for EventBridge to invoke producer Lambda
resource "aws_lambda_permission" "allow_eventbridge_producer" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.producer.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.producer_schedule.arn
}

# Permission for S3 to invoke consumer Lambda
resource "aws_lambda_permission" "allow_s3_consumer" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.consumer.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = module.s3_bucket.bucket_arn
}

############################################
# SNS and EventBridge
############################################

# SNS Topic for pipeline status
resource "aws_sns_topic" "pipeline_status" {
  name = "firehose-pipeline-status"
}

# EventBridge rule to trigger producer every 2 minutes
resource "aws_cloudwatch_event_rule" "producer_schedule" {
  name                = "firehose-producer-schedule"
  description         = "Trigger producer lambda every 2 minutes"
  schedule_expression = "rate(2 minutes)"
}

# EventBridge target
resource "aws_cloudwatch_event_target" "producer_target" {
  rule      = aws_cloudwatch_event_rule.producer_schedule.name
  target_id = "ProducerLambdaTarget"
  arn       = aws_lambda_function.producer.arn
}

############################################
# S3 Notifications
############################################

# S3 bucket notification to trigger consumer Lambda
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = module.s3_bucket.bucket_id

  lambda_function {
    lambda_function_arn = aws_lambda_function.consumer.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "firehose/"
    filter_suffix       = ".gz"
  }

  depends_on = [aws_lambda_permission.allow_s3_consumer]
}

############################################
# Kinesis Firehose
############################################

# Kinesis Firehose Delivery Stream
module "kinesis_firehose" {
  source = "../../"

  name        = "aws-waf-logs-${local.base_name}-basic-s3"
  destination = "extended_s3"

  s3_configuration = {
    role_arn            = aws_iam_role.firehose.arn
    bucket_arn          = module.s3_bucket.bucket_arn
    prefix              = "firehose/"
    error_output_prefix = "errors/"
    buffer_interval     = 60
    buffer_size         = 5
    compression_format  = "GZIP"

    cloudwatch_logging_options = {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose.name
      log_stream_name = aws_cloudwatch_log_stream.firehose.name
    }

    processing_configuration = {
      enabled = true
      processors = [
        {
          type = "Lambda"
          parameters = [
            {
              parameter_name  = "LambdaArn"
              parameter_value = aws_lambda_function.firehose_processor.arn
            }
          ]
        }
      ]
    }
  }
}
