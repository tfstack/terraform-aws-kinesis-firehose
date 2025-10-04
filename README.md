# terraform-aws-kinesis-firehose

[![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)](https://aws.amazon.com/)

A comprehensive Terraform module for creating and managing AWS Kinesis Firehose delivery streams with support for multiple destinations including S3, Redshift, Elasticsearch, Splunk, and HTTP endpoints.

## Features

- 🚀 **Multiple Destinations**: Support for S3, Redshift, Elasticsearch, Splunk, and HTTP endpoints
- 🔧 **Flexible Configuration**: Comprehensive configuration options for all destination types
- 📊 **Data Processing**: Built-in support for Lambda-based data processing
- 📝 **CloudWatch Logging**: Integrated logging and monitoring capabilities
- 🔒 **Security**: IAM roles and policies for secure access
- 🏷️ **Tagging**: Full support for resource tagging
- 📚 **Examples**: Complete examples for all supported destinations

## Supported Destinations

- **Extended S3** (`extended_s3`) - Store data in S3 with advanced features
- **Redshift** (`redshift`) - Load data directly into Redshift clusters
- **Elasticsearch** (`elasticsearch`) - Stream data to Elasticsearch domains
- **Splunk** (`splunk`) - Send data to Splunk via HTTP Event Collector (HEC)
- **HTTP Endpoint** (`http_endpoint`) - Send data to any HTTP endpoint

## Usage

### Basic S3 Destination

```hcl
module "kinesis_firehose" {
  source = "github.com/your-org/terraform-aws-kinesis-firehose"

  name        = "my-firehose-stream"
  destination = "extended_s3"

  s3_configuration = {
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.my_bucket.arn
    prefix     = "firehose/"
    buffer_interval = 60
    buffer_size     = 5
    compression_format = "GZIP"
  }

  tags = {
    Environment = "production"
    Project     = "data-pipeline"
  }
}
```

### Redshift Destination

```hcl
module "kinesis_firehose" {
  source = "github.com/your-org/terraform-aws-kinesis-firehose"

  name        = "my-redshift-stream"
  destination = "redshift"

  redshift_configuration = {
    role_arn        = aws_iam_role.firehose_role.arn
    cluster_jdbcurl = "jdbc:redshift://my-cluster.abc123.us-east-1.redshift.amazonaws.com:5439/mydb"
    username        = "firehose_user"
    password        = "secure_password"
    data_table_name = "firehose_data"

    s3_configuration = {
      role_arn   = aws_iam_role.firehose_role.arn
      bucket_arn = aws_s3_bucket.staging_bucket.arn
      prefix     = "redshift/"
    }
  }
}
```

### HTTP Endpoint Destination

```hcl
module "kinesis_firehose" {
  source = "github.com/your-org/terraform-aws-kinesis-firehose"

  name        = "my-http-stream"
  destination = "http_endpoint"

  http_endpoint_configuration = {
    url        = "https://api.example.com/webhook"
    name       = "my-endpoint"
    role_arn   = aws_iam_role.firehose_role.arn

    s3_configuration = {
      role_arn   = aws_iam_role.firehose_role.arn
      bucket_arn = aws_s3_bucket.backup_bucket.arn
    }

    request_configuration = {
      content_encoding = "GZIP"
      common_attributes = [
        {
          name  = "source"
          value = "kinesis-firehose"
        }
      ]
    }
  }
}
```

## Examples

This module includes comprehensive examples for all supported destinations:

- [S3 Destination Example](examples/s3-destination/) - Complete S3 setup with Lambda processing
- [Redshift Destination Example](examples/redshift-destination/) - Full Redshift cluster setup
- [HTTP Endpoint Example](examples/http-endpoint/) - HTTP endpoint with backup configuration

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_name"></a> [name](#input\_name) | A name to identify the stream. This is unique to the AWS account and region the stream is created in. | `string` | n/a | yes |
| <a name="input_destination"></a> [destination](#input\_destination) | The destination for the delivery stream. Valid values are `extended_s3`, `redshift`, `elasticsearch`, `splunk`, and `http_endpoint`. | `string` | n/a | yes |
| <a name="input_s3_configuration"></a> [s3_configuration](#input\_s3_configuration) | Configuration for S3 destination. Required when destination is `extended_s3`. | <pre>object({<br>  role_arn           = string<br>  bucket_arn         = string<br>  prefix             = optional(string)<br>  error_output_prefix = optional(string)<br>  buffer_interval    = optional(number, 60)<br>  buffer_size        = optional(number, 5)<br>  compression_format = optional(string, "UNCOMPRESSED")<br>  # ... additional configuration options<br>})</pre> | `null` | no |
| <a name="input_redshift_configuration"></a> [redshift_configuration](#input\_redshift_configuration) | Configuration for Redshift destination. | <pre>object({<br>  role_arn        = string<br>  cluster_jdbcurl = string<br>  username        = string<br>  password        = string<br>  data_table_name = string<br>  # ... additional configuration options<br>})</pre> | `null` | no |
| <a name="input_elasticsearch_configuration"></a> [elasticsearch_configuration](#input\_elasticsearch_configuration) | Configuration for Elasticsearch destination. | <pre>object({<br>  domain_arn = string<br>  role_arn   = string<br>  index_name = string<br>  # ... additional configuration options<br>})</pre> | `null` | no |
| <a name="input_splunk_configuration"></a> [splunk_configuration](#input\_splunk_configuration) | Configuration for Splunk destination. | <pre>object({<br>  hec_endpoint = string<br>  hec_token    = string<br>  # ... additional configuration options<br>})</pre> | `null` | no |
| <a name="input_http_endpoint_configuration"></a> [http_endpoint_configuration](#input\_http_endpoint_configuration) | Configuration for HTTP endpoint destination. | <pre>object({<br>  url      = string<br>  name     = string<br>  role_arn = string<br>  # ... additional configuration options<br>})</pre> | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to assign to the resource. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_delivery_stream_arn"></a> [delivery_stream_arn](#output\_delivery_stream_arn) | The ARN of the Kinesis Firehose delivery stream |
| <a name="output_delivery_stream_name"></a> [delivery_stream_name](#output\_delivery_stream_name) | The name of the Kinesis Firehose delivery stream |
| <a name="output_delivery_stream_destination"></a> [delivery_stream_destination](#output\_delivery_stream_destination) | The destination of the Kinesis Firehose delivery stream |
| <a name="output_delivery_stream_status"></a> [delivery_stream_status](#output\_delivery_stream_status) | The status of the Kinesis Firehose delivery stream |

## Advanced Features

### Data Processing

The module supports Lambda-based data processing for all destinations:

```hcl
processing_configuration = {
  enabled = true
  processors = [
    {
      type = "Lambda"
      parameters = [
        {
          parameter_name  = "LambdaArn"
          parameter_value = aws_lambda_function.processor.arn
        }
      ]
    }
  ]
}
```

### Data Format Conversion

For S3 destinations, you can configure data format conversion:

```hcl
data_format_conversion_configuration = {
  enabled = true
  input_format_configuration = {
    deserializer = {
      open_x_json_ser_de = {
        case_insensitive = true
      }
    }
  }
  output_format_configuration = {
    serializer = {
      parquet_ser_de = {
        compression = "SNAPPY"
      }
    }
  }
  schema_configuration = {
    database_name = "my_database"
    table_name    = "my_table"
    role_arn      = aws_iam_role.schema_role.arn
  }
}
```

### CloudWatch Logging

Enable CloudWatch logging for monitoring:

```hcl
cloudwatch_logging_options = {
  enabled         = true
  log_group_name  = "/aws/kinesisfirehose/my-stream"
  log_stream_name = "S3Delivery"
}
```

## Security Considerations

- Ensure proper IAM roles and policies are configured
- Use least privilege principle for permissions
- Enable encryption for data at rest and in transit
- Consider VPC endpoints for private network access
- Regularly rotate access keys and secrets

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This module is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Support

For questions, issues, or contributions, please open an issue on the GitHub repository.
