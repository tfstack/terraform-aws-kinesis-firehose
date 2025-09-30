# Data sources removed for testing - they require AWS API calls

# Kinesis Firehose Delivery Stream
resource "aws_kinesis_firehose_delivery_stream" "this" {
  name        = var.name
  destination = var.destination

  # Kinesis source configuration
  dynamic "kinesis_source_configuration" {
    for_each = var.kinesis_source_configuration != null ? [var.kinesis_source_configuration] : []
    content {
      kinesis_stream_arn = kinesis_source_configuration.value.kinesis_stream_arn
      role_arn           = kinesis_source_configuration.value.role_arn
    }
  }

  # S3 destination configuration
  dynamic "extended_s3_configuration" {
    for_each = var.s3_configuration != null ? [var.s3_configuration] : []
    content {
      role_arn            = extended_s3_configuration.value.role_arn
      bucket_arn          = extended_s3_configuration.value.bucket_arn
      prefix              = extended_s3_configuration.value.prefix
      error_output_prefix = extended_s3_configuration.value.error_output_prefix
      compression_format  = extended_s3_configuration.value.compression_format

      # Buffering configuration
      buffering_interval = extended_s3_configuration.value.buffer_interval
      buffering_size     = extended_s3_configuration.value.buffer_size


      # CloudWatch logging
      dynamic "cloudwatch_logging_options" {
        for_each = extended_s3_configuration.value.cloudwatch_logging_options != null ? [extended_s3_configuration.value.cloudwatch_logging_options] : []
        content {
          enabled         = cloudwatch_logging_options.value.enabled
          log_group_name  = cloudwatch_logging_options.value.log_group_name
          log_stream_name = cloudwatch_logging_options.value.log_stream_name
        }
      }

      # S3 backup configuration
      dynamic "s3_backup_configuration" {
        for_each = extended_s3_configuration.value.s3_backup_configuration != null ? [extended_s3_configuration.value.s3_backup_configuration] : []
        content {
          role_arn            = s3_backup_configuration.value.role_arn
          bucket_arn          = s3_backup_configuration.value.bucket_arn
          prefix              = s3_backup_configuration.value.prefix
          error_output_prefix = s3_backup_configuration.value.error_output_prefix
          compression_format  = s3_backup_configuration.value.compression_format

          dynamic "cloudwatch_logging_options" {
            for_each = s3_backup_configuration.value.cloudwatch_logging_options != null ? [s3_backup_configuration.value.cloudwatch_logging_options] : []
            content {
              enabled         = cloudwatch_logging_options.value.enabled
              log_group_name  = cloudwatch_logging_options.value.log_group_name
              log_stream_name = cloudwatch_logging_options.value.log_stream_name
            }
          }
        }
      }

      # Processing configuration
      dynamic "processing_configuration" {
        for_each = extended_s3_configuration.value.processing_configuration != null ? [extended_s3_configuration.value.processing_configuration] : []
        content {
          enabled = processing_configuration.value.enabled

          dynamic "processors" {
            for_each = processing_configuration.value.processors
            content {
              type = processors.value.type

              dynamic "parameters" {
                for_each = processors.value.parameters
                content {
                  parameter_name  = parameters.value.parameter_name
                  parameter_value = parameters.value.parameter_value
                }
              }
            }
          }
        }
      }

      # Data format conversion
      dynamic "data_format_conversion_configuration" {
        for_each = extended_s3_configuration.value.data_format_conversion_configuration != null ? [extended_s3_configuration.value.data_format_conversion_configuration] : []
        content {
          enabled = data_format_conversion_configuration.value.enabled

          dynamic "input_format_configuration" {
            for_each = data_format_conversion_configuration.value.input_format_configuration != null ? [data_format_conversion_configuration.value.input_format_configuration] : []
            content {
              deserializer {
                dynamic "hive_json_ser_de" {
                  for_each = input_format_configuration.value.deserializer.hive_json_ser_de != null ? [input_format_configuration.value.deserializer.hive_json_ser_de] : []
                  content {
                    timestamp_formats = hive_json_ser_de.value.timestamp_formats
                  }
                }

                dynamic "open_x_json_ser_de" {
                  for_each = input_format_configuration.value.deserializer.open_x_json_ser_de != null ? [input_format_configuration.value.deserializer.open_x_json_ser_de] : []
                  content {
                    case_insensitive                         = open_x_json_ser_de.value.case_insensitive
                    column_to_json_key_mappings              = open_x_json_ser_de.value.column_to_json_key_mappings
                    convert_dots_in_json_keys_to_underscores = open_x_json_ser_de.value.convert_dots_in_json_keys_to_underscores
                  }
                }
              }
            }
          }

          dynamic "output_format_configuration" {
            for_each = data_format_conversion_configuration.value.output_format_configuration != null ? [data_format_conversion_configuration.value.output_format_configuration] : []
            content {
              serializer {
                dynamic "orc_ser_de" {
                  for_each = output_format_configuration.value.orc_ser_de != null ? [output_format_configuration.value.orc_ser_de] : []
                  content {
                    block_size_bytes                        = orc_ser_de.value.block_size_bytes
                    bloom_filter_columns                    = orc_ser_de.value.bloom_filter_columns
                    bloom_filter_false_positive_probability = orc_ser_de.value.bloom_filter_false_positive_probability
                    compression                             = orc_ser_de.value.compression
                    dictionary_key_threshold                = orc_ser_de.value.dictionary_key_threshold
                    enable_padding                          = orc_ser_de.value.enable_padding
                    format_version                          = orc_ser_de.value.format_version
                    padding_tolerance                       = orc_ser_de.value.padding_tolerance
                    row_index_stride                        = orc_ser_de.value.row_index_stride
                    stripe_size_bytes                       = orc_ser_de.value.stripe_size_bytes
                  }
                }

                dynamic "parquet_ser_de" {
                  for_each = output_format_configuration.value.parquet_ser_de != null ? [output_format_configuration.value.parquet_ser_de] : []
                  content {
                    block_size_bytes              = parquet_ser_de.value.block_size_bytes
                    compression                   = parquet_ser_de.value.compression
                    enable_dictionary_compression = parquet_ser_de.value.enable_dictionary_compression
                    max_padding_bytes             = parquet_ser_de.value.max_padding_bytes
                    page_size_bytes               = parquet_ser_de.value.page_size_bytes
                    writer_version                = parquet_ser_de.value.writer_version
                  }
                }
              }
            }
          }

          dynamic "schema_configuration" {
            for_each = data_format_conversion_configuration.value.schema_configuration != null ? [data_format_conversion_configuration.value.schema_configuration] : []
            content {
              catalog_id    = schema_configuration.value.catalog_id
              database_name = schema_configuration.value.database_name
              region        = schema_configuration.value.region
              role_arn      = schema_configuration.value.role_arn
              table_name    = schema_configuration.value.table_name
              version_id    = schema_configuration.value.version_id
            }
          }
        }
      }
    }
  }

  # HTTP endpoint destination configuration
  dynamic "http_endpoint_configuration" {
    for_each = var.http_endpoint_configuration != null ? [var.http_endpoint_configuration] : []
    content {
      url            = http_endpoint_configuration.value.url
      name           = http_endpoint_configuration.value.name
      access_key     = http_endpoint_configuration.value.access_key
      role_arn       = http_endpoint_configuration.value.role_arn
      s3_backup_mode = http_endpoint_configuration.value.s3_backup_mode
      retry_duration = http_endpoint_configuration.value.retry_duration
      s3_configuration {
        role_arn            = http_endpoint_configuration.value.s3_configuration.role_arn
        bucket_arn          = http_endpoint_configuration.value.s3_configuration.bucket_arn
        prefix              = http_endpoint_configuration.value.s3_configuration.prefix
        error_output_prefix = http_endpoint_configuration.value.s3_configuration.error_output_prefix
        compression_format  = http_endpoint_configuration.value.s3_configuration.compression_format
      }

      dynamic "cloudwatch_logging_options" {
        for_each = http_endpoint_configuration.value.cloudwatch_logging_options != null ? [http_endpoint_configuration.value.cloudwatch_logging_options] : []
        content {
          enabled         = cloudwatch_logging_options.value.enabled
          log_group_name  = cloudwatch_logging_options.value.log_group_name
          log_stream_name = cloudwatch_logging_options.value.log_stream_name
        }
      }

      dynamic "processing_configuration" {
        for_each = http_endpoint_configuration.value.processing_configuration != null ? [http_endpoint_configuration.value.processing_configuration] : []
        content {
          enabled = processing_configuration.value.enabled

          dynamic "processors" {
            for_each = processing_configuration.value.processors
            content {
              type = processors.value.type

              dynamic "parameters" {
                for_each = processors.value.parameters
                content {
                  parameter_name  = parameters.value.parameter_name
                  parameter_value = parameters.value.parameter_value
                }
              }
            }
          }
        }
      }

      dynamic "request_configuration" {
        for_each = http_endpoint_configuration.value.request_configuration != null ? [http_endpoint_configuration.value.request_configuration] : []
        content {
          content_encoding = request_configuration.value.content_encoding

          dynamic "common_attributes" {
            for_each = request_configuration.value.common_attributes
            content {
              name  = common_attributes.value.name
              value = common_attributes.value.value
            }
          }
        }
      }
    }
  }

  # Redshift destination configuration
  dynamic "redshift_configuration" {
    for_each = var.redshift_configuration != null ? [var.redshift_configuration] : []
    content {
      role_arn           = redshift_configuration.value.role_arn
      cluster_jdbcurl    = redshift_configuration.value.cluster_jdbcurl
      username           = redshift_configuration.value.username
      password           = redshift_configuration.value.password
      retry_duration     = redshift_configuration.value.retry_duration
      copy_options       = redshift_configuration.value.copy_options
      data_table_name    = redshift_configuration.value.data_table_name
      data_table_columns = redshift_configuration.value.data_table_columns
      s3_backup_mode     = redshift_configuration.value.s3_backup_mode

      s3_configuration {
        role_arn            = redshift_configuration.value.s3_configuration.role_arn
        bucket_arn          = redshift_configuration.value.s3_configuration.bucket_arn
        prefix              = redshift_configuration.value.s3_configuration.prefix
        error_output_prefix = redshift_configuration.value.s3_configuration.error_output_prefix
        compression_format  = redshift_configuration.value.s3_configuration.compression_format
      }

      dynamic "cloudwatch_logging_options" {
        for_each = redshift_configuration.value.cloudwatch_logging_options != null ? [redshift_configuration.value.cloudwatch_logging_options] : []
        content {
          enabled         = cloudwatch_logging_options.value.enabled
          log_group_name  = cloudwatch_logging_options.value.log_group_name
          log_stream_name = cloudwatch_logging_options.value.log_stream_name
        }
      }

      dynamic "processing_configuration" {
        for_each = redshift_configuration.value.processing_configuration != null ? [redshift_configuration.value.processing_configuration] : []
        content {
          enabled = processing_configuration.value.enabled

          dynamic "processors" {
            for_each = processing_configuration.value.processors
            content {
              type = processors.value.type

              dynamic "parameters" {
                for_each = processors.value.parameters
                content {
                  parameter_name  = parameters.value.parameter_name
                  parameter_value = parameters.value.parameter_value
                }
              }
            }
          }
        }
      }
    }
  }

  # Elasticsearch destination configuration
  dynamic "elasticsearch_configuration" {
    for_each = var.elasticsearch_configuration != null ? [var.elasticsearch_configuration] : []
    content {
      domain_arn     = elasticsearch_configuration.value.domain_arn
      role_arn       = elasticsearch_configuration.value.role_arn
      index_name     = elasticsearch_configuration.value.index_name
      type_name      = elasticsearch_configuration.value.type_name
      s3_backup_mode = elasticsearch_configuration.value.s3_backup_mode
      retry_duration = elasticsearch_configuration.value.retry_duration

      s3_configuration {
        role_arn            = elasticsearch_configuration.value.s3_configuration.role_arn
        bucket_arn          = elasticsearch_configuration.value.s3_configuration.bucket_arn
        prefix              = elasticsearch_configuration.value.s3_configuration.prefix
        error_output_prefix = elasticsearch_configuration.value.s3_configuration.error_output_prefix
        compression_format  = elasticsearch_configuration.value.s3_configuration.compression_format
      }

      dynamic "cloudwatch_logging_options" {
        for_each = elasticsearch_configuration.value.cloudwatch_logging_options != null ? [elasticsearch_configuration.value.cloudwatch_logging_options] : []
        content {
          enabled         = cloudwatch_logging_options.value.enabled
          log_group_name  = cloudwatch_logging_options.value.log_group_name
          log_stream_name = cloudwatch_logging_options.value.log_stream_name
        }
      }

      dynamic "processing_configuration" {
        for_each = elasticsearch_configuration.value.processing_configuration != null ? [elasticsearch_configuration.value.processing_configuration] : []
        content {
          enabled = processing_configuration.value.enabled

          dynamic "processors" {
            for_each = processing_configuration.value.processors
            content {
              type = processors.value.type

              dynamic "parameters" {
                for_each = processors.value.parameters
                content {
                  parameter_name  = parameters.value.parameter_name
                  parameter_value = parameters.value.parameter_value
                }
              }
            }
          }
        }
      }

      dynamic "vpc_config" {
        for_each = elasticsearch_configuration.value.vpc_configuration != null ? [elasticsearch_configuration.value.vpc_configuration] : []
        content {
          subnet_ids         = vpc_config.value.subnet_ids
          security_group_ids = vpc_config.value.security_group_ids
          role_arn           = vpc_config.value.role_arn
        }
      }
    }
  }

  # Splunk destination configuration
  dynamic "splunk_configuration" {
    for_each = var.splunk_configuration != null ? [var.splunk_configuration] : []
    content {
      hec_endpoint               = splunk_configuration.value.hec_endpoint
      hec_token                  = splunk_configuration.value.hec_token
      hec_acknowledgment_timeout = splunk_configuration.value.hec_acknowledgment_timeout
      hec_endpoint_type          = splunk_configuration.value.hec_endpoint_type
      s3_backup_mode             = splunk_configuration.value.s3_backup_mode
      retry_duration             = splunk_configuration.value.retry_duration

      s3_configuration {
        role_arn            = splunk_configuration.value.s3_configuration.role_arn
        bucket_arn          = splunk_configuration.value.s3_configuration.bucket_arn
        prefix              = splunk_configuration.value.s3_configuration.prefix
        error_output_prefix = splunk_configuration.value.s3_configuration.error_output_prefix
        compression_format  = splunk_configuration.value.s3_configuration.compression_format
      }

      dynamic "cloudwatch_logging_options" {
        for_each = splunk_configuration.value.cloudwatch_logging_options != null ? [splunk_configuration.value.cloudwatch_logging_options] : []
        content {
          enabled         = cloudwatch_logging_options.value.enabled
          log_group_name  = cloudwatch_logging_options.value.log_group_name
          log_stream_name = cloudwatch_logging_options.value.log_stream_name
        }
      }

      dynamic "processing_configuration" {
        for_each = splunk_configuration.value.processing_configuration != null ? [splunk_configuration.value.processing_configuration] : []
        content {
          enabled = processing_configuration.value.enabled

          dynamic "processors" {
            for_each = processing_configuration.value.processors
            content {
              type = processors.value.type

              dynamic "parameters" {
                for_each = processors.value.parameters
                content {
                  parameter_name  = parameters.value.parameter_name
                  parameter_value = parameters.value.parameter_value
                }
              }
            }
          }
        }
      }
    }
  }

  # Server-side encryption (only for S3 destinations)
  dynamic "server_side_encryption" {
    for_each = var.destination == "extended_s3" && var.s3_configuration != null && try(var.s3_configuration.server_side_encryption, null) != null ? [var.s3_configuration.server_side_encryption] : []
    content {
      enabled  = server_side_encryption.value.enabled
      key_type = "CUSTOMER_MANAGED_CMK"
      key_arn  = server_side_encryption.value.kms_key_id
    }
  }

  # Tags
  tags = var.tags
}
