run "s3_destination_test" {
  command = plan

  variables {
    name        = "test-s3-firehose"
    destination = "extended_s3"

    s3_configuration = {
      role_arn            = "arn:aws:iam::123456789012:role/firehose-role"
      bucket_arn          = "arn:aws:s3:::test-bucket"
      prefix              = "firehose/"
      error_output_prefix = "errors/"
      buffer_interval     = 60
      buffer_size         = 5
      compression_format  = "GZIP"

      server_side_encryption = {
        enabled    = true
        kms_key_id = "arn:aws:kms:ap-southeast-2:123456789012:key/12345678-1234-1234-1234-123456789012"
      }

      cloudwatch_logging_options = {
        enabled         = true
        log_group_name  = "/aws/kinesisfirehose/test-stream"
        log_stream_name = "S3Delivery"
      }

      processing_configuration = {
        enabled = true
        processors = [
          {
            type = "Lambda"
            parameters = [
              {
                parameter_name  = "LambdaArn"
                parameter_value = "arn:aws:lambda:ap-southeast-2:123456789012:function:test-processor"
              }
            ]
          }
        ]
      }

      data_format_conversion_configuration = {
        enabled = true

        input_format_configuration = {
          deserializer = {
            hive_json_ser_de = {
              timestamp_formats = ["yyyy-MM-dd HH:mm:ss"]
            }
          }
        }

        output_format_configuration = {
          orc_ser_de = {
            block_size_bytes                        = 268435456
            bloom_filter_columns                    = ["id", "timestamp"]
            bloom_filter_false_positive_probability = 0.05
            compression                             = "SNAPPY"
            dictionary_key_threshold                = 0.8
            enable_padding                          = true
            format_version                          = "V0_12"
            padding_tolerance                       = 0.05
            row_index_stride                        = 10000
            stripe_size_bytes                       = 67108864
          }
        }

        schema_configuration = {
          catalog_id    = "123456789012"
          database_name = "test_database"
          region        = "ap-southeast-2"
          role_arn      = "arn:aws:iam::123456789012:role/glue-role"
          table_name    = "test_table"
          version_id    = "LATEST"
        }
      }
    }

    tags = {
      Environment = "test"
      Project     = "kinesis-firehose"
    }
  }

  # Test basic configuration
  assert {
    condition     = var.name == "test-s3-firehose"
    error_message = "Stream name should match expected value"
  }

  assert {
    condition     = var.destination == "extended_s3"
    error_message = "Destination should be extended_s3"
  }

  # Test S3 configuration
  assert {
    condition     = var.s3_configuration.role_arn == "arn:aws:iam::123456789012:role/firehose-role"
    error_message = "S3 role ARN should match expected value"
  }

  assert {
    condition     = var.s3_configuration.bucket_arn == "arn:aws:s3:::test-bucket"
    error_message = "S3 bucket ARN should match expected value"
  }

  assert {
    condition     = var.s3_configuration.prefix == "firehose/"
    error_message = "S3 prefix should match expected value"
  }

  assert {
    condition     = var.s3_configuration.buffer_interval == 60
    error_message = "Buffer interval should be 60 seconds"
  }

  assert {
    condition     = var.s3_configuration.buffer_size == 5
    error_message = "Buffer size should be 5 MB"
  }

  assert {
    condition     = var.s3_configuration.compression_format == "GZIP"
    error_message = "Compression format should be GZIP"
  }

  # Test server-side encryption
  assert {
    condition     = var.s3_configuration.server_side_encryption.enabled == true
    error_message = "Server-side encryption should be enabled"
  }

  assert {
    condition     = var.s3_configuration.server_side_encryption.kms_key_id == "arn:aws:kms:ap-southeast-2:123456789012:key/12345678-1234-1234-1234-123456789012"
    error_message = "KMS key ID should match expected value"
  }

  # Test CloudWatch logging
  assert {
    condition     = var.s3_configuration.cloudwatch_logging_options.enabled == true
    error_message = "CloudWatch logging should be enabled"
  }

  # Test processing configuration
  assert {
    condition     = var.s3_configuration.processing_configuration.enabled == true
    error_message = "Processing configuration should be enabled"
  }

  assert {
    condition     = length(var.s3_configuration.processing_configuration.processors) == 1
    error_message = "Should have 1 processor"
  }

  assert {
    condition     = var.s3_configuration.processing_configuration.processors[0].type == "Lambda"
    error_message = "Processor type should be Lambda"
  }

  # Test data format conversion
  assert {
    condition     = var.s3_configuration.data_format_conversion_configuration.enabled == true
    error_message = "Data format conversion should be enabled"
  }

  # Test tags
  assert {
    condition     = var.tags.Environment == "test"
    error_message = "Environment tag should be test"
  }

  assert {
    condition     = var.tags.Project == "kinesis-firehose"
    error_message = "Project tag should be kinesis-firehose"
  }
}

run "http_endpoint_destination_test" {
  command = plan

  variables {
    name        = "test-http-firehose"
    destination = "http_endpoint"

    http_endpoint_configuration = {
      url            = "https://api.example.com/events"
      name           = "test-endpoint"
      access_key     = "test-access-key"
      role_arn       = "arn:aws:iam::123456789012:role/firehose-role"
      s3_backup_mode = "FailedDataOnly"
      retry_duration = 7200

      s3_configuration = {
        role_arn            = "arn:aws:iam::123456789012:role/firehose-role"
        bucket_arn          = "arn:aws:s3:::test-backup-bucket"
        prefix              = "backup/"
        error_output_prefix = "errors/"
        compression_format  = "GZIP"
      }

      cloudwatch_logging_options = {
        enabled         = true
        log_group_name  = "/aws/kinesisfirehose/test-http-stream"
        log_stream_name = "HttpDelivery"
      }

      processing_configuration = {
        enabled = true
        processors = [
          {
            type = "Lambda"
            parameters = [
              {
                parameter_name  = "LambdaArn"
                parameter_value = "arn:aws:lambda:ap-southeast-2:123456789012:function:http-processor"
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
          }
        ]
      }
    }

    tags = {
      Environment = "test"
      Service     = "http-endpoint"
    }
  }

  # Test HTTP endpoint configuration
  assert {
    condition     = var.http_endpoint_configuration.url == "https://api.example.com/events"
    error_message = "HTTP endpoint URL should match expected value"
  }

  assert {
    condition     = var.http_endpoint_configuration.name == "test-endpoint"
    error_message = "HTTP endpoint name should match expected value"
  }

  assert {
    condition     = var.http_endpoint_configuration.retry_duration == 7200
    error_message = "Retry duration should be 7200 seconds"
  }

  assert {
    condition     = var.http_endpoint_configuration.s3_backup_mode == "FailedDataOnly"
    error_message = "S3 backup mode should be FailedDataOnly"
  }

  # Test S3 backup configuration
  assert {
    condition     = var.http_endpoint_configuration.s3_configuration.bucket_arn == "arn:aws:s3:::test-backup-bucket"
    error_message = "S3 backup bucket ARN should match expected value"
  }

  # Test request configuration
  assert {
    condition     = var.http_endpoint_configuration.request_configuration.content_encoding == "GZIP"
    error_message = "Content encoding should be GZIP"
  }

  assert {
    condition     = length(var.http_endpoint_configuration.request_configuration.common_attributes) == 1
    error_message = "Should have 1 common attribute"
  }
}

run "redshift_destination_test" {
  command = plan

  variables {
    name        = "test-redshift-firehose"
    destination = "redshift"

    redshift_configuration = {
      role_arn           = "arn:aws:iam::123456789012:role/firehose-role"
      cluster_jdbcurl    = "jdbc:redshift://test-cluster.abc123.ap-southeast-2.redshift.amazonaws.com:5439/testdb"
      username           = "testuser"
      password           = "testpassword"
      retry_duration     = 3600
      copy_options       = "JSON 'auto'"
      data_table_name    = "test_table"
      data_table_columns = "id, name, timestamp"
      s3_backup_mode     = "Disabled"

      s3_configuration = {
        role_arn            = "arn:aws:iam::123456789012:role/firehose-role"
        bucket_arn          = "arn:aws:s3:::test-redshift-bucket"
        prefix              = "redshift/"
        error_output_prefix = "errors/"
        compression_format  = "GZIP"
      }

      cloudwatch_logging_options = {
        enabled         = true
        log_group_name  = "/aws/kinesisfirehose/test-redshift-stream"
        log_stream_name = "RedshiftDelivery"
      }
    }

    tags = {
      Environment = "test"
      Service     = "redshift"
    }
  }

  # Test Redshift configuration
  assert {
    condition     = var.redshift_configuration.cluster_jdbcurl == "jdbc:redshift://test-cluster.abc123.ap-southeast-2.redshift.amazonaws.com:5439/testdb"
    error_message = "Redshift JDBC URL should match expected value"
  }

  assert {
    condition     = var.redshift_configuration.username == "testuser"
    error_message = "Redshift username should match expected value"
  }

  assert {
    condition     = var.redshift_configuration.data_table_name == "test_table"
    error_message = "Data table name should match expected value"
  }

  assert {
    condition     = var.redshift_configuration.s3_backup_mode == "Disabled"
    error_message = "S3 backup mode should be Disabled"
  }
}

run "elasticsearch_destination_test" {
  command = plan

  variables {
    name        = "test-elasticsearch-firehose"
    destination = "elasticsearch"

    elasticsearch_configuration = {
      domain_arn     = "arn:aws:es:ap-southeast-2:123456789012:domain/test-domain"
      role_arn       = "arn:aws:iam::123456789012:role/firehose-role"
      index_name     = "test-index"
      type_name      = "test-type"
      s3_backup_mode = "FailedDocumentsOnly"
      retry_duration = 300

      s3_configuration = {
        role_arn            = "arn:aws:iam::123456789012:role/firehose-role"
        bucket_arn          = "arn:aws:s3:::test-elasticsearch-bucket"
        prefix              = "elasticsearch/"
        error_output_prefix = "errors/"
        compression_format  = "GZIP"
      }

      cloudwatch_logging_options = {
        enabled         = true
        log_group_name  = "/aws/kinesisfirehose/test-elasticsearch-stream"
        log_stream_name = "ElasticsearchDelivery"
      }

      vpc_configuration = {
        subnet_ids         = ["subnet-12345", "subnet-67890"]
        security_group_ids = ["sg-12345", "sg-67890"]
        role_arn           = "arn:aws:iam::123456789012:role/vpc-role"
      }
    }

    tags = {
      Environment = "test"
      Service     = "elasticsearch"
    }
  }

  # Test Elasticsearch configuration
  assert {
    condition     = var.elasticsearch_configuration.domain_arn == "arn:aws:es:ap-southeast-2:123456789012:domain/test-domain"
    error_message = "Elasticsearch domain ARN should match expected value"
  }

  assert {
    condition     = var.elasticsearch_configuration.index_name == "test-index"
    error_message = "Elasticsearch index name should match expected value"
  }

  assert {
    condition     = var.elasticsearch_configuration.retry_duration == 300
    error_message = "Retry duration should be 300 seconds"
  }

  # Test VPC configuration
  assert {
    condition     = length(var.elasticsearch_configuration.vpc_configuration.subnet_ids) == 2
    error_message = "Should have 2 subnet IDs"
  }

  assert {
    condition     = length(var.elasticsearch_configuration.vpc_configuration.security_group_ids) == 2
    error_message = "Should have 2 security group IDs"
  }
}

run "splunk_destination_test" {
  command = plan

  variables {
    name        = "test-splunk-firehose"
    destination = "splunk"

    splunk_configuration = {
      hec_endpoint               = "https://splunk.example.com:8088/services/collector"
      hec_token                  = "test-hec-token"
      hec_acknowledgment_timeout = 600
      hec_endpoint_type          = "Event"
      s3_backup_mode             = "FailedEventsOnly"
      retry_duration             = 3600

      s3_configuration = {
        role_arn            = "arn:aws:iam::123456789012:role/firehose-role"
        bucket_arn          = "arn:aws:s3:::test-splunk-bucket"
        prefix              = "splunk/"
        error_output_prefix = "errors/"
        compression_format  = "GZIP"
      }

      cloudwatch_logging_options = {
        enabled         = true
        log_group_name  = "/aws/kinesisfirehose/test-splunk-stream"
        log_stream_name = "SplunkDelivery"
      }
    }

    tags = {
      Environment = "test"
      Service     = "splunk"
    }
  }

  # Test Splunk configuration
  assert {
    condition     = var.splunk_configuration.hec_endpoint == "https://splunk.example.com:8088/services/collector"
    error_message = "Splunk HEC endpoint should match expected value"
  }

  assert {
    condition     = var.splunk_configuration.hec_token == "test-hec-token"
    error_message = "Splunk HEC token should match expected value"
  }

  assert {
    condition     = var.splunk_configuration.hec_endpoint_type == "Event"
    error_message = "HEC endpoint type should be Event"
  }

  assert {
    condition     = var.splunk_configuration.retry_duration == 3600
    error_message = "Retry duration should be 3600 seconds"
  }
}
