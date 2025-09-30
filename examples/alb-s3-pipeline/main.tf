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
  azs                  = ["ap-southeast-2a", "ap-southeast-2b", "ap-southeast-2c"]
  enable_dns_hostnames = true
  enable_https         = false

  name            = "waf"
  base_name       = local.suffix != "" ? "${local.name}-${local.suffix}" : local.name
  suffix          = random_string.suffix.result
  private_subnets = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  region          = "ap-southeast-2"
  vpc_cidr        = "10.0.0.0/16"
  tags = {
    Environment = "dev"
    Project     = "waf-logging"
  }
}

############################################
# VPC Configuration
############################################

module "vpc" {
  source = "cloudbuildlab/vpc/aws"

  vpc_name           = local.base_name
  vpc_cidr           = local.vpc_cidr
  availability_zones = local.azs

  public_subnet_cidrs  = local.public_subnets
  private_subnet_cidrs = local.private_subnets

  # Enable Internet Gateway & NAT Gateway
  create_igw       = true
  nat_gateway_type = "single"

  tags = local.tags
}

############################################
# S3 Bucket for Logs
############################################

module "s3_bucket" {
  source = "tfstack/s3/aws"

  # General Configuration
  bucket_name       = "${local.base_name}-waf-logging"
  bucket_suffix     = random_string.suffix.result
  force_destroy     = true
  enable_versioning = true

  tags = local.tags
}

############################################
# CloudWatch Logs for Firehose
############################################

# CloudWatch Log Group for Firehose
resource "aws_cloudwatch_log_group" "firehose" {
  name              = "/aws/kinesisfirehose/${local.base_name}-waf-logs"
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

# IAM Role for Lambda
resource "aws_iam_role" "lambda" {
  name = "${local.base_name}-lambda-role"

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

  tags = local.tags
}

# IAM Policy for Lambda execution
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

# IAM Policy for Lambda to send logs to Firehose
resource "aws_iam_role_policy" "lambda_firehose" {
  name = "${local.base_name}-lambda-firehose"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "firehose:PutRecord",
          "firehose:PutRecordBatch"
        ]
        Resource = module.kinesis_firehose.delivery_stream_arn
      }
    ]
  })
}

# IAM Role for Kinesis Firehose
resource "aws_iam_role" "firehose" {
  name = "${local.base_name}-firehose-role"

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

# IAM Policy for Firehose S3 access
resource "aws_iam_role_policy" "firehose_s3_policy" {
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
resource "aws_iam_role_policy" "firehose_cloudwatch_policy" {
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

############################################
# Lambda Function
############################################

# Create Lambda deployment package with dependencies
resource "null_resource" "lambda_package" {
  triggers = {
    lambda_code  = filemd5("${path.module}/external/lambda.js")
    package_json = filemd5("${path.module}/external/package.json")
  }

  provisioner "local-exec" {
    command = <<-EOT
      cd ${path.module}/external
      npm install --production
      zip -r lambda.zip lambda.js node_modules package.json
    EOT
  }
}

data "archive_file" "lambda_function" {
  type        = "zip"
  source_dir  = "${path.module}/external"
  output_path = "${path.module}/external/lambda-deploy.zip"

  depends_on = [
    null_resource.lambda_package
  ]
}

# Lambda Function
resource "aws_lambda_function" "api" {
  filename      = data.archive_file.lambda_function.output_path
  function_name = "${local.base_name}-api"
  role          = aws_iam_role.lambda.arn
  handler       = "lambda.handler"
  runtime       = "nodejs20.x"
  timeout       = 30
  memory_size   = 128

  environment {
    variables = {
      ENVIRONMENT          = "dev"
      FIREHOSE_STREAM_NAME = module.kinesis_firehose.delivery_stream_name
    }
  }

  tags = local.tags
}

# Lambda permission for ALB
resource "aws_lambda_permission" "alb" {
  statement_id  = "AllowExecutionFromALB"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = "arn:aws:elasticloadbalancing:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:targetgroup/${local.base_name}-http/*"
}

############################################
# Application Load Balancer
############################################

module "alb" {
  source = "tfstack/alb/aws"

  name              = local.name
  suffix            = random_string.suffix.result
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids

  enable_https     = false
  http_port        = 80
  target_http_port = 80
  target_type      = "lambda"
  targets          = [aws_lambda_function.api.arn]

  # Health check configuration for Lambda (disabled)
  health_check_enabled = false

  tags = local.tags

  depends_on = [
    aws_lambda_permission.alb
  ]
}

############################################
# WAF Configuration
############################################

# WAF Web ACL
resource "aws_wafv2_web_acl" "main" {
  name  = "${local.base_name}-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "KnownBadInputsRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.base_name}-waf"
    sampled_requests_enabled   = true
  }

  tags = local.tags
}

# Associate WAF with ALB
resource "aws_wafv2_web_acl_association" "main" {
  resource_arn = module.alb.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}

############################################
# Kinesis Firehose
############################################

module "kinesis_firehose" {
  source = "../../"

  name        = "${local.base_name}-waf-logs"
  destination = "extended_s3"

  s3_configuration = {
    role_arn            = aws_iam_role.firehose.arn
    bucket_arn          = module.s3_bucket.bucket_arn
    prefix              = "waf-logs/!{timestamp:yyyy/MM/dd/}"
    error_output_prefix = "errors/!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    buffer_interval     = 60
    buffer_size         = 10
    compression_format  = "GZIP"

    cloudwatch_logging_options = {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose.name
      log_stream_name = aws_cloudwatch_log_stream.firehose.name
    }
  }

  tags = local.tags
}
