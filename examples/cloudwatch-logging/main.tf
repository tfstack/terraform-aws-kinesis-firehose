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
  base_name = "firehose-${local.suffix}"
  tags = {
    Environment = "dev"
    Project     = "cloudwatch-logging-example"
  }
}

############################################
# S3 Bucket for Logs
############################################

module "s3_bucket" {
  source = "tfstack/s3/aws"

  bucket_name   = local.base_name
  force_destroy = true
  tags          = local.tags
}

############################################
# IAM Role for Firehose S3
############################################

resource "aws_iam_role" "firehose_s3" {
  name = "${local.base_name}-s3"

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

  tags = local.tags
}

resource "aws_iam_role_policy" "firehose_s3" {
  name = "${local.base_name}-s3"
  role = aws_iam_role.firehose_s3.id

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

############################################
# Example 1: Using create_cloudwatch_log_group = true (Force Destroy Enabled)
############################################

module "kinesis_firehose_with_auto_logging" {
  source = "../../"

  name        = "aws-waf-logs-${local.base_name}-auto"
  destination = "extended_s3"

  # Enable automatic CloudWatch log group creation with force destroy
  create_cloudwatch_log_group         = true
  cloudwatch_log_group_name           = "/aws/kinesisfirehose/${local.base_name}-auto"
  cloudwatch_log_stream_name          = "${local.base_name}-auto-stream"
  cloudwatch_log_group_retention_days = 30
  cloudwatch_log_group_force_destroy  = true # Can be destroyed easily

  s3_configuration = {
    role_arn            = aws_iam_role.firehose_s3.arn
    bucket_arn          = module.s3_bucket.bucket_arn
    prefix              = "auto-logs/"
    error_output_prefix = "auto-errors/"
    buffer_interval     = 60
    buffer_size         = 5
    compression_format  = "GZIP"
    # cloudwatch_logging_options is automatically configured with proper IAM permissions
  }

  tags = local.tags
}

############################################
# Example 2: Using create_cloudwatch_log_group = true (Force Destroy Disabled)
############################################

module "kinesis_firehose_with_protected_logging" {
  source = "../../"

  name        = "aws-waf-logs-${local.base_name}-protected"
  destination = "extended_s3"

  # Enable automatic CloudWatch log group creation with protection
  create_cloudwatch_log_group         = true
  cloudwatch_log_group_name           = "/aws/kinesisfirehose/${local.base_name}-protected"
  cloudwatch_log_stream_name          = "${local.base_name}-protected-stream"
  cloudwatch_log_group_retention_days = 90
  cloudwatch_log_group_force_destroy  = false # Protected from accidental deletion

  s3_configuration = {
    role_arn            = aws_iam_role.firehose_s3.arn
    bucket_arn          = module.s3_bucket.bucket_arn
    prefix              = "protected-logs/"
    error_output_prefix = "protected-errors/"
    buffer_interval     = 60
    buffer_size         = 5
    compression_format  = "GZIP"
    # cloudwatch_logging_options is automatically configured with proper IAM permissions
  }

  tags = local.tags
}

############################################
# Example 3: Using manual CloudWatch log group (Legacy approach)
############################################

resource "aws_cloudwatch_log_group" "manual" {
  name              = "/aws/kinesisfirehose/${local.base_name}-manual"
  retention_in_days = 14
  tags              = local.tags
}

resource "aws_cloudwatch_log_stream" "manual" {
  name           = "${local.base_name}-manual-stream"
  log_group_name = aws_cloudwatch_log_group.manual.name
}

# IAM Role for Firehose CloudWatch Logs (Manual)
resource "aws_iam_role" "firehose_cloudwatch_manual" {
  name = "${local.base_name}-cloudwatch-manual"

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

  tags = local.tags
}

resource "aws_iam_role_policy" "firehose_cloudwatch_manual" {
  name = "${local.base_name}-cloudwatch-manual"
  role = aws_iam_role.firehose_cloudwatch_manual.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          aws_cloudwatch_log_group.manual.arn,
          "${aws_cloudwatch_log_group.manual.arn}:*"
        ]
      }
    ]
  })
}

module "kinesis_firehose_with_manual_logging" {
  source = "../../"

  name        = "aws-waf-logs-${local.base_name}-manual"
  destination = "extended_s3"

  # Disable automatic CloudWatch log group creation
  create_cloudwatch_log_group = false

  s3_configuration = {
    role_arn            = aws_iam_role.firehose_s3.arn
    bucket_arn          = module.s3_bucket.bucket_arn
    prefix              = "manual-logs/"
    error_output_prefix = "manual-errors/"
    buffer_interval     = 60
    buffer_size         = 5
    compression_format  = "GZIP"

    # Manual CloudWatch logging configuration
    cloudwatch_logging_options = {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.manual.name
      log_stream_name = aws_cloudwatch_log_stream.manual.name
    }
  }

  tags = local.tags
}

############################################
# Outputs
############################################

output "auto_logging_firehose" {
  description = "Firehose with automatic CloudWatch logging (force destroy enabled)"
  value = {
    delivery_stream_name = module.kinesis_firehose_with_auto_logging.delivery_stream_name
    log_group_name       = module.kinesis_firehose_with_auto_logging.cloudwatch_log_group_name
    log_group_arn        = module.kinesis_firehose_with_auto_logging.cloudwatch_log_group_arn
    cloudwatch_role_arn  = module.kinesis_firehose_with_auto_logging.cloudwatch_logs_role_arn
  }
}

output "protected_logging_firehose" {
  description = "Firehose with protected CloudWatch logging (force destroy disabled)"
  value = {
    delivery_stream_name = module.kinesis_firehose_with_protected_logging.delivery_stream_name
    log_group_name       = module.kinesis_firehose_with_protected_logging.cloudwatch_log_group_name
    log_group_arn        = module.kinesis_firehose_with_protected_logging.cloudwatch_log_group_arn
    cloudwatch_role_arn  = module.kinesis_firehose_with_protected_logging.cloudwatch_logs_role_arn
  }
}

output "manual_logging_firehose" {
  description = "Firehose with manual CloudWatch logging"
  value = {
    delivery_stream_name = module.kinesis_firehose_with_manual_logging.delivery_stream_name
    log_group_name       = aws_cloudwatch_log_group.manual.name
    log_group_arn        = aws_cloudwatch_log_group.manual.arn
    cloudwatch_role_arn  = aws_iam_role.firehose_cloudwatch_manual.arn
  }
}

output "s3_bucket_name" {
  description = "S3 bucket name for logs"
  value       = module.s3_bucket.bucket_id
}
