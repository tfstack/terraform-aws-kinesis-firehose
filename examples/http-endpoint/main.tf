terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

############################################
# Data Sources
############################################

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

############################################
# Random Resources
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
  name      = "http-endpoint"
  tags = {
    Environment = "dev"
    Project     = "http-endpoint"
  }
}

############################################
# S3 Bucket
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

resource "aws_cloudwatch_log_group" "firehose" {
  name              = "/aws/kinesisfirehose/${local.base_name}"
  retention_in_days = 1

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_cloudwatch_log_stream" "firehose" {
  name           = "HttpDelivery"
  log_group_name = aws_cloudwatch_log_group.firehose.name
}

############################################
# IAM Roles and Policies
############################################

resource "aws_iam_role" "firehose" {
  name = "${local.base_name}-firehose"

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

resource "aws_iam_role" "lambda" {
  name = "${local.base_name}-lambda"

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

resource "aws_iam_role_policy" "firehose_cloudwatch" {
  name = "${local.base_name}-firehose-cloudwatch"
  role = aws_iam_role.firehose.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:PutLogEvents"
        ]
        Resource = [
          aws_cloudwatch_log_group.firehose.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_logs" {
  name = "${local.base_name}-lambda-logs"
  role = aws_iam_role.lambda.id

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
          aws_cloudwatch_log_group.firehose.arn,
          "${aws_cloudwatch_log_group.firehose.arn}:*"
        ]
      }
    ]
  })
}

############################################
# Lambda Functions
############################################

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
        # Decode the data
        payload = base64.b64decode(record['data'])

        # Process the data (example: add metadata)
        processed_data = {
            'original_data': json.loads(payload.decode('utf-8')),
            'processed_at': context.aws_request_id,
            'source': 'kinesis-firehose'
        }

        # Encode the processed data
        encoded_data = base64.b64encode(json.dumps(processed_data).encode('utf-8')).decode('utf-8')

        output.append({
            'recordId': record['recordId'],
            'result': 'Ok',
            'data': encoded_data
        })

    return {'records': output}
EOF
    filename = "index.py"
  }
}

resource "aws_lambda_function" "firehose_processor" {
  filename         = "lambda_function.zip"
  function_name    = "${local.base_name}-processor"
  role             = aws_iam_role.lambda.arn
  handler          = "index.handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.lambda.output_base64sha256
}

resource "aws_lambda_permission" "allow_firehose" {
  statement_id  = "AllowExecutionFromFirehose"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.firehose_processor.function_name
  principal     = "firehose.amazonaws.com"
  source_arn    = module.kinesis_firehose.delivery_stream_arn
}

############################################
# Kinesis Firehose
############################################

module "kinesis_firehose" {
  source = "../../"

  name        = "${local.base_name}-stream"
  destination = "http_endpoint"

  http_endpoint_configuration = {
    url            = "https://httpbin.org/post" # Example HTTP endpoint
    name           = "http-endpoint"
    role_arn       = aws_iam_role.firehose.arn
    s3_backup_mode = "AllData"

    s3_configuration = {
      role_arn            = aws_iam_role.firehose.arn
      bucket_arn          = module.s3_bucket.bucket_arn
      prefix              = "http-backup/"
      error_output_prefix = "errors/"
      buffer_interval     = 60
      buffer_size         = 5
      compression_format  = "GZIP"
    }

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

    request_configuration = {
      content_encoding = "GZIP"
      common_attributes = [
        {
          name  = "source"
          value = "kinesis-firehose"
        },
        {
          name  = "environment"
          value = "production"
        }
      ]
    }
  }
}
