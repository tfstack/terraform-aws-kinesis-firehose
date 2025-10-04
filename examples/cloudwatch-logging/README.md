# CloudWatch Logging Example

This example demonstrates the two approaches for configuring CloudWatch logging with Kinesis Firehose:

1. **Automatic CloudWatch Log Group Creation** (Recommended)
2. **Manual CloudWatch Log Group Creation** (Legacy)

## Architecture

```plaintext
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Kinesis       │    │   CloudWatch     │    │      S3         │
│   Firehose      │───▶│   Logs           │    │     Bucket      │
│                 │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## What Gets Created

### Automatic Approach (Recommended)

- **Kinesis Firehose Delivery Stream** with automatic CloudWatch logging
- **CloudWatch Log Group** created automatically by the module
- **IAM Role for CloudWatch Logs** with proper permissions
- **S3 Bucket** for storing logs
- **IAM Role for S3** for Firehose permissions

### Manual Approach (Legacy)

- **Kinesis Firehose Delivery Stream** with manual CloudWatch logging
- **CloudWatch Log Group** created manually
- **CloudWatch Log Stream** created manually
- **IAM Role for CloudWatch Logs** created manually
- **S3 Bucket** for storing logs
- **IAM Role for S3** for Firehose permissions

## Key Features

### Automatic CloudWatch Logging (Force Destroy Enabled)

```hcl
module "kinesis_firehose_with_auto_logging" {
  source = "../../"

  name        = "aws-waf-logs-${local.base_name}-auto"
  destination = "extended_s3"

  # Enable automatic CloudWatch log group creation with force destroy
  create_cloudwatch_log_group        = true
  cloudwatch_log_group_name          = "/aws/kinesisfirehose/${local.base_name}-auto"
  cloudwatch_log_stream_name         = "${local.base_name}-auto-stream"
  cloudwatch_log_group_retention_days = 30
  cloudwatch_log_group_force_destroy  = true  # Can be destroyed easily

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
```

### Automatic CloudWatch Logging (Force Destroy Disabled)

```hcl
module "kinesis_firehose_with_protected_logging" {
  source = "../../"

  name        = "aws-waf-logs-${local.base_name}-protected"
  destination = "extended_s3"

  # Enable automatic CloudWatch log group creation with protection
  create_cloudwatch_log_group        = true
  cloudwatch_log_group_name          = "/aws/kinesisfirehose/${local.base_name}-protected"
  cloudwatch_log_stream_name         = "${local.base_name}-protected-stream"
  cloudwatch_log_group_retention_days = 90
  cloudwatch_log_group_force_destroy  = false  # Protected from accidental deletion

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
```

### Manual CloudWatch Logging

```hcl
# Create CloudWatch resources manually
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
```

## IAM Permissions

### Automatic Approach

When `create_cloudwatch_log_group = true`, the module automatically creates:

1. **IAM Role** (`{name}-cloudwatch-logs`)
2. **IAM Policy** with CloudWatch Logs permissions:
   - `logs:CreateLogGroup`
   - `logs:CreateLogStream`
   - `logs:PutLogEvents`
   - `logs:DescribeLogGroups`
   - `logs:DescribeLogStreams`

### Manual Approach

You need to create your own IAM role and policy with the same permissions.

## Usage

1. **Deploy the infrastructure:**

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

2. **Check the outputs:**

   ```bash
   terraform output
   ```

3. **View CloudWatch logs:**

   ```bash
   # Auto-created log groups
   aws logs describe-log-groups --log-group-name-prefix "/aws/kinesisfirehose/firehose-"

   # Manual log group
   aws logs describe-log-groups --log-group-name-prefix "/aws/kinesisfirehose/firehose-"
   ```

## Benefits of Automatic Approach

- **Simplified Configuration**: No need to create CloudWatch resources manually
- **Automatic IAM Permissions**: Proper CloudWatch Logs permissions are created automatically
- **Consistent Naming**: Automatic naming follows AWS conventions
- **Reduced Boilerplate**: Less code to maintain
- **Better Integration**: Module handles all CloudWatch configuration automatically

## Configuration Options

### New Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `create_cloudwatch_log_group` | `bool` | `false` | Whether to create a CloudWatch log group |
| `cloudwatch_log_group_name` | `string` | `null` | Custom log group name (defaults to `/aws/kinesisfirehose/{name}`) |
| `cloudwatch_log_stream_name` | `string` | `null` | Custom log stream name (defaults to `{name}`) |
| `cloudwatch_log_group_retention_days` | `number` | `14` | Number of days to retain CloudWatch logs |
| `cloudwatch_log_group_force_destroy` | `bool` | `false` | Whether to force destroy the CloudWatch log group |

### New Outputs

| Output | Description |
|--------|-------------|
| `cloudwatch_log_group_arn` | ARN of the created CloudWatch log group |
| `cloudwatch_log_group_name` | Name of the created CloudWatch log group |
| `cloudwatch_logs_role_arn` | ARN of the IAM role for CloudWatch logs |

## Use Cases

**Development/Testing:**

- `retention_days = 7`
- `force_destroy = true`
- Quick cleanup and cost savings

**Production:**

- `retention_days = 90` (or longer)
- `force_destroy = false`
- Data protection and compliance

## Cleanup

```bash
terraform destroy
```

This will remove all created resources including the CloudWatch log groups and S3 bucket.
