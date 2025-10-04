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

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.14.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_kinesis_firehose_delivery_stream.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kinesis_firehose_delivery_stream) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_destination"></a> [destination](#input\_destination) | The destination for the delivery stream. Valid values are `extended_s3`, `redshift`, `elasticsearch`, `splunk`, and `http_endpoint`. | `string` | n/a | yes |
| <a name="input_elasticsearch_configuration"></a> [elasticsearch\_configuration](#input\_elasticsearch\_configuration) | Configuration for Elasticsearch destination. | <pre>object({<br/>    domain_arn     = string<br/>    role_arn       = string<br/>    index_name     = string<br/>    type_name      = optional(string)<br/>    s3_backup_mode = optional(string, "FailedEventsOnly")<br/>    retry_duration = optional(number, 300)<br/><br/>    s3_configuration = object({<br/>      role_arn            = string<br/>      bucket_arn          = string<br/>      prefix              = optional(string)<br/>      error_output_prefix = optional(string)<br/>      buffer_interval     = optional(number, 60)<br/>      buffer_size         = optional(number, 5)<br/>      compression_format  = optional(string, "UNCOMPRESSED")<br/>    })<br/><br/>    cloudwatch_logging_options = optional(object({<br/>      enabled         = bool<br/>      log_group_name  = string<br/>      log_stream_name = string<br/>    }))<br/><br/>    processing_configuration = optional(object({<br/>      enabled = bool<br/>      processors = list(object({<br/>        type = string<br/>        parameters = list(object({<br/>          parameter_name  = string<br/>          parameter_value = string<br/>        }))<br/>      }))<br/>    }))<br/><br/>    vpc_configuration = optional(object({<br/>      subnet_ids         = list(string)<br/>      security_group_ids = list(string)<br/>      role_arn           = string<br/>    }))<br/>  })</pre> | `null` | no |
| <a name="input_http_endpoint_configuration"></a> [http\_endpoint\_configuration](#input\_http\_endpoint\_configuration) | Configuration for HTTP endpoint destination. | <pre>object({<br/>    url            = string<br/>    name           = string<br/>    access_key     = optional(string)<br/>    secret_key     = optional(string)<br/>    role_arn       = string<br/>    s3_backup_mode = optional(string, "FailedEventsOnly")<br/>    retry_duration = optional(number, 3600)<br/><br/>    s3_configuration = object({<br/>      role_arn            = string<br/>      bucket_arn          = string<br/>      prefix              = optional(string)<br/>      error_output_prefix = optional(string)<br/>      buffer_interval     = optional(number, 60)<br/>      buffer_size         = optional(number, 5)<br/>      compression_format  = optional(string, "UNCOMPRESSED")<br/>    })<br/><br/>    cloudwatch_logging_options = optional(object({<br/>      enabled         = bool<br/>      log_group_name  = string<br/>      log_stream_name = string<br/>    }))<br/><br/>    processing_configuration = optional(object({<br/>      enabled = bool<br/>      processors = list(object({<br/>        type = string<br/>        parameters = list(object({<br/>          parameter_name  = string<br/>          parameter_value = string<br/>        }))<br/>      }))<br/>    }))<br/><br/>    request_configuration = optional(object({<br/>      content_encoding = optional(string, "GZIP")<br/>      common_attributes = optional(list(object({<br/>        name  = string<br/>        value = string<br/>      })), [])<br/>    }))<br/>  })</pre> | `null` | no |
| <a name="input_kinesis_source_configuration"></a> [kinesis\_source\_configuration](#input\_kinesis\_source\_configuration) | Configuration for Kinesis source. Required when destination is not `extended_s3`. | <pre>object({<br/>    kinesis_stream_arn = string<br/>    role_arn           = string<br/>  })</pre> | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | A name to identify the stream. This is unique to the AWS account and region the stream is created in. | `string` | n/a | yes |
| <a name="input_redshift_configuration"></a> [redshift\_configuration](#input\_redshift\_configuration) | Configuration for Redshift destination. | <pre>object({<br/>    role_arn           = string<br/>    cluster_jdbcurl    = string<br/>    username           = string<br/>    password           = string<br/>    retry_duration     = optional(number, 3600)<br/>    copy_options       = optional(string)<br/>    data_table_name    = string<br/>    data_table_columns = optional(string)<br/>    s3_backup_mode     = optional(string, "Disabled")<br/><br/>    s3_configuration = object({<br/>      role_arn            = string<br/>      bucket_arn          = string<br/>      prefix              = optional(string)<br/>      error_output_prefix = optional(string)<br/>      buffer_interval     = optional(number, 60)<br/>      buffer_size         = optional(number, 5)<br/>      compression_format  = optional(string, "UNCOMPRESSED")<br/>    })<br/><br/>    cloudwatch_logging_options = optional(object({<br/>      enabled         = bool<br/>      log_group_name  = string<br/>      log_stream_name = string<br/>    }))<br/><br/>    processing_configuration = optional(object({<br/>      enabled = bool<br/>      processors = list(object({<br/>        type = string<br/>        parameters = list(object({<br/>          parameter_name  = string<br/>          parameter_value = string<br/>        }))<br/>      }))<br/>    }))<br/>  })</pre> | `null` | no |
| <a name="input_s3_configuration"></a> [s3\_configuration](#input\_s3\_configuration) | Configuration for S3 destination. Required when destination is `extended_s3`. | <pre>object({<br/>    role_arn            = string<br/>    bucket_arn          = string<br/>    prefix              = optional(string)<br/>    error_output_prefix = optional(string)<br/>    buffer_interval     = optional(number, 60)<br/>    buffer_size         = optional(number, 5)<br/>    compression_format  = optional(string, "UNCOMPRESSED")<br/><br/>    server_side_encryption = optional(object({<br/>      enabled    = optional(bool, false)<br/>      kms_key_id = optional(string)<br/>    }))<br/><br/>    cloudwatch_logging_options = optional(object({<br/>      enabled         = bool<br/>      log_group_name  = string<br/>      log_stream_name = string<br/>    }))<br/><br/>    s3_backup_configuration = optional(object({<br/>      role_arn            = string<br/>      bucket_arn          = string<br/>      prefix              = optional(string)<br/>      error_output_prefix = optional(string)<br/>      buffer_interval     = optional(number, 60)<br/>      buffer_size         = optional(number, 5)<br/>      compression_format  = optional(string, "UNCOMPRESSED")<br/><br/>      cloudwatch_logging_options = optional(object({<br/>        enabled         = bool<br/>        log_group_name  = string<br/>        log_stream_name = string<br/>      }))<br/>    }))<br/><br/>    processing_configuration = optional(object({<br/>      enabled = bool<br/>      processors = list(object({<br/>        type = string<br/>        parameters = list(object({<br/>          parameter_name  = string<br/>          parameter_value = string<br/>        }))<br/>      }))<br/>    }))<br/><br/>    data_format_conversion_configuration = optional(object({<br/>      enabled = bool<br/><br/>      input_format_configuration = optional(object({<br/>        deserializer = object({<br/>          hive_json_ser_de = optional(object({<br/>            timestamp_formats = optional(list(string))<br/>          }))<br/>          open_x_json_ser_de = optional(object({<br/>            case_insensitive                         = optional(bool)<br/>            column_to_json_key_mappings              = optional(map(string))<br/>            convert_dots_in_json_keys_to_underscores = optional(bool)<br/>          }))<br/>        })<br/>      }))<br/><br/>      output_format_configuration = optional(object({<br/>        orc_ser_de = optional(object({<br/>          block_size_bytes                        = optional(number)<br/>          bloom_filter_columns                    = optional(list(string))<br/>          bloom_filter_false_positive_probability = optional(number)<br/>          compression                             = optional(string)<br/>          dictionary_key_threshold                = optional(number)<br/>          enable_padding                          = optional(bool)<br/>          format_version                          = optional(string)<br/>          padding_tolerance                       = optional(number)<br/>          row_index_stride                        = optional(number)<br/>          stripe_size_bytes                       = optional(number)<br/>        }))<br/>        parquet_ser_de = optional(object({<br/>          block_size_bytes              = optional(number)<br/>          compression                   = optional(string)<br/>          enable_dictionary_compression = optional(bool)<br/>          max_padding_bytes             = optional(number)<br/>          page_size_bytes               = optional(number)<br/>          writer_version                = optional(string)<br/>        }))<br/>      }))<br/><br/>      schema_configuration = optional(object({<br/>        catalog_id    = optional(string)<br/>        database_name = string<br/>        region        = optional(string)<br/>        role_arn      = string<br/>        table_name    = string<br/>        version_id    = optional(string)<br/>      }))<br/>    }))<br/>  })</pre> | `null` | no |
| <a name="input_splunk_configuration"></a> [splunk\_configuration](#input\_splunk\_configuration) | Configuration for Splunk destination. | <pre>object({<br/>    hec_endpoint               = string<br/>    hec_token                  = string<br/>    hec_acknowledgment_timeout = optional(number, 600)<br/>    hec_endpoint_type          = optional(string, "Event")<br/>    s3_backup_mode             = optional(string, "FailedEventsOnly")<br/>    retry_duration             = optional(number, 3600)<br/><br/>    s3_configuration = object({<br/>      role_arn            = string<br/>      bucket_arn          = string<br/>      prefix              = optional(string)<br/>      error_output_prefix = optional(string)<br/>      buffer_interval     = optional(number, 60)<br/>      buffer_size         = optional(number, 5)<br/>      compression_format  = optional(string, "UNCOMPRESSED")<br/>    })<br/><br/>    cloudwatch_logging_options = optional(object({<br/>      enabled         = bool<br/>      log_group_name  = string<br/>      log_stream_name = string<br/>    }))<br/><br/>    processing_configuration = optional(object({<br/>      enabled = bool<br/>      processors = list(object({<br/>        type = string<br/>        parameters = list(object({<br/>          parameter_name  = string<br/>          parameter_value = string<br/>        }))<br/>      }))<br/>    }))<br/>  })</pre> | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to assign to the resource. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_delivery_stream_arn"></a> [delivery\_stream\_arn](#output\_delivery\_stream\_arn) | The ARN of the Kinesis Firehose delivery stream |
| <a name="output_delivery_stream_destination"></a> [delivery\_stream\_destination](#output\_delivery\_stream\_destination) | The destination of the Kinesis Firehose delivery stream |
| <a name="output_delivery_stream_name"></a> [delivery\_stream\_name](#output\_delivery\_stream\_name) | The name of the Kinesis Firehose delivery stream |
| <a name="output_delivery_stream_tags_all"></a> [delivery\_stream\_tags\_all](#output\_delivery\_stream\_tags\_all) | A map of tags assigned to the resource, including those inherited from the provider default\_tags configuration block |
| <a name="output_delivery_stream_version_id"></a> [delivery\_stream\_version\_id](#output\_delivery\_stream\_version\_id) | The version ID of the Kinesis Firehose delivery stream |
<!-- END_TF_DOCS -->