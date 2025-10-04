variable "name" {
  description = "A name to identify the stream. This is unique to the AWS account and region the stream is created in. For WAF logging, must start with 'aws-waf-logs-' prefix."
  type        = string

  validation {
    condition     = can(regex("^aws-waf-logs-", var.name))
    error_message = "For WAF logging to Kinesis Data Firehose, the delivery stream name must start with 'aws-waf-logs-' prefix. Example: 'aws-waf-logs-${var.name}'"
  }
}

variable "destination" {
  description = "The destination for the delivery stream. Valid values are `extended_s3`, `redshift`, `elasticsearch`, `splunk`, and `http_endpoint`."
  type        = string
  validation {
    condition = contains([
      "extended_s3",
      "redshift",
      "elasticsearch",
      "splunk",
      "http_endpoint"
    ], var.destination)
    error_message = "Destination must be one of: extended_s3, redshift, elasticsearch, splunk, http_endpoint."
  }
}

variable "kinesis_source_configuration" {
  description = "Configuration for Kinesis source. Required when destination is not `extended_s3`."
  type = object({
    kinesis_stream_arn = string
    role_arn           = string
  })
  default = null
}

variable "s3_configuration" {
  description = "Configuration for S3 destination. Required when destination is `extended_s3`."
  type = object({
    role_arn            = string
    bucket_arn          = string
    prefix              = optional(string)
    error_output_prefix = optional(string)
    buffer_interval     = optional(number, 60)
    buffer_size         = optional(number, 5)
    compression_format  = optional(string, "UNCOMPRESSED")

    server_side_encryption = optional(object({
      enabled    = optional(bool, false)
      kms_key_id = optional(string)
    }))

    cloudwatch_logging_options = optional(object({
      enabled         = bool
      log_group_name  = string
      log_stream_name = string
    }))

    s3_backup_configuration = optional(object({
      role_arn            = string
      bucket_arn          = string
      prefix              = optional(string)
      error_output_prefix = optional(string)
      buffer_interval     = optional(number, 60)
      buffer_size         = optional(number, 5)
      compression_format  = optional(string, "UNCOMPRESSED")

      cloudwatch_logging_options = optional(object({
        enabled         = bool
        log_group_name  = string
        log_stream_name = string
      }))
    }))

    processing_configuration = optional(object({
      enabled = bool
      processors = list(object({
        type = string
        parameters = list(object({
          parameter_name  = string
          parameter_value = string
        }))
      }))
    }))

    data_format_conversion_configuration = optional(object({
      enabled = bool

      input_format_configuration = optional(object({
        deserializer = object({
          hive_json_ser_de = optional(object({
            timestamp_formats = optional(list(string))
          }))
          open_x_json_ser_de = optional(object({
            case_insensitive                         = optional(bool)
            column_to_json_key_mappings              = optional(map(string))
            convert_dots_in_json_keys_to_underscores = optional(bool)
          }))
        })
      }))

      output_format_configuration = optional(object({
        orc_ser_de = optional(object({
          block_size_bytes                        = optional(number)
          bloom_filter_columns                    = optional(list(string))
          bloom_filter_false_positive_probability = optional(number)
          compression                             = optional(string)
          dictionary_key_threshold                = optional(number)
          enable_padding                          = optional(bool)
          format_version                          = optional(string)
          padding_tolerance                       = optional(number)
          row_index_stride                        = optional(number)
          stripe_size_bytes                       = optional(number)
        }))
        parquet_ser_de = optional(object({
          block_size_bytes              = optional(number)
          compression                   = optional(string)
          enable_dictionary_compression = optional(bool)
          max_padding_bytes             = optional(number)
          page_size_bytes               = optional(number)
          writer_version                = optional(string)
        }))
      }))

      schema_configuration = optional(object({
        catalog_id    = optional(string)
        database_name = string
        region        = optional(string)
        role_arn      = string
        table_name    = string
        version_id    = optional(string)
      }))
    }))
  })
  default = null
}

variable "http_endpoint_configuration" {
  description = "Configuration for HTTP endpoint destination."
  type = object({
    url            = string
    name           = string
    access_key     = optional(string)
    secret_key     = optional(string)
    role_arn       = string
    s3_backup_mode = optional(string, "FailedEventsOnly")
    retry_duration = optional(number, 3600)

    s3_configuration = object({
      role_arn            = string
      bucket_arn          = string
      prefix              = optional(string)
      error_output_prefix = optional(string)
      buffer_interval     = optional(number, 60)
      buffer_size         = optional(number, 5)
      compression_format  = optional(string, "UNCOMPRESSED")
    })

    cloudwatch_logging_options = optional(object({
      enabled         = bool
      log_group_name  = string
      log_stream_name = string
    }))

    processing_configuration = optional(object({
      enabled = bool
      processors = list(object({
        type = string
        parameters = list(object({
          parameter_name  = string
          parameter_value = string
        }))
      }))
    }))

    request_configuration = optional(object({
      content_encoding = optional(string, "GZIP")
      common_attributes = optional(list(object({
        name  = string
        value = string
      })), [])
    }))
  })
  default = null
}

variable "redshift_configuration" {
  description = "Configuration for Redshift destination."
  type = object({
    role_arn           = string
    cluster_jdbcurl    = string
    username           = string
    password           = string
    retry_duration     = optional(number, 3600)
    copy_options       = optional(string)
    data_table_name    = string
    data_table_columns = optional(string)
    s3_backup_mode     = optional(string, "Disabled")

    s3_configuration = object({
      role_arn            = string
      bucket_arn          = string
      prefix              = optional(string)
      error_output_prefix = optional(string)
      buffer_interval     = optional(number, 60)
      buffer_size         = optional(number, 5)
      compression_format  = optional(string, "UNCOMPRESSED")
    })

    cloudwatch_logging_options = optional(object({
      enabled         = bool
      log_group_name  = string
      log_stream_name = string
    }))

    processing_configuration = optional(object({
      enabled = bool
      processors = list(object({
        type = string
        parameters = list(object({
          parameter_name  = string
          parameter_value = string
        }))
      }))
    }))
  })
  default = null
}

variable "elasticsearch_configuration" {
  description = "Configuration for Elasticsearch destination."
  type = object({
    domain_arn     = string
    role_arn       = string
    index_name     = string
    type_name      = optional(string)
    s3_backup_mode = optional(string, "FailedEventsOnly")
    retry_duration = optional(number, 300)

    s3_configuration = object({
      role_arn            = string
      bucket_arn          = string
      prefix              = optional(string)
      error_output_prefix = optional(string)
      buffer_interval     = optional(number, 60)
      buffer_size         = optional(number, 5)
      compression_format  = optional(string, "UNCOMPRESSED")
    })

    cloudwatch_logging_options = optional(object({
      enabled         = bool
      log_group_name  = string
      log_stream_name = string
    }))

    processing_configuration = optional(object({
      enabled = bool
      processors = list(object({
        type = string
        parameters = list(object({
          parameter_name  = string
          parameter_value = string
        }))
      }))
    }))

    vpc_configuration = optional(object({
      subnet_ids         = list(string)
      security_group_ids = list(string)
      role_arn           = string
    }))
  })
  default = null
}

variable "splunk_configuration" {
  description = "Configuration for Splunk destination."
  type = object({
    hec_endpoint               = string
    hec_token                  = string
    hec_acknowledgment_timeout = optional(number, 600)
    hec_endpoint_type          = optional(string, "Event")
    s3_backup_mode             = optional(string, "FailedEventsOnly")
    retry_duration             = optional(number, 3600)

    s3_configuration = object({
      role_arn            = string
      bucket_arn          = string
      prefix              = optional(string)
      error_output_prefix = optional(string)
      buffer_interval     = optional(number, 60)
      buffer_size         = optional(number, 5)
      compression_format  = optional(string, "UNCOMPRESSED")
    })

    cloudwatch_logging_options = optional(object({
      enabled         = bool
      log_group_name  = string
      log_stream_name = string
    }))

    processing_configuration = optional(object({
      enabled = bool
      processors = list(object({
        type = string
        parameters = list(object({
          parameter_name  = string
          parameter_value = string
        }))
      }))
    }))
  })
  default = null
}

variable "tags" {
  description = "A map of tags to assign to the resource."
  type        = map(string)
  default     = {}
}
