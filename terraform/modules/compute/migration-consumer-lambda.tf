variable "migration_reserved_concurrency" {
  description = "Concurrencia máxima de la Lambda consumidora — evita saturar Textract/Bedrock con miles de invocaciones simultáneas durante una migración masiva"
  type        = number
  default     = 5
}

# Reutiliza el mismo código que `processing` — la lógica de negocio es
# idéntica (determinar processing_path, disparar OCR o extracción nativa).
# Lo único que cambia es el trigger (SQS en vez de S3 directo) y el límite
# de concurrencia.
resource "aws_lambda_function" "migration_consumer" {
  function_name = "${var.project_name}-migration-consumer-${var.environment}"
  role          = aws_iam_role.lambda_processing.arn
  handler       = "handler.lambda_handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout_processing
  memory_size   = 512

  filename         = data.archive_file.processing.output_path
  source_code_hash = data.archive_file.processing.output_base64sha256

  reserved_concurrent_executions = var.migration_reserved_concurrency

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      DOCUMENTS_METADATA_TABLE = var.documents_metadata_table_name
      AUDIT_LOG_TABLE          = var.audit_log_table_name
      AURORA_ENDPOINT          = var.aurora_cluster_endpoint
      AURORA_DATABASE          = var.aurora_database_name
      AURORA_SECRET_ARN        = var.aurora_master_user_secret_arn
      ENVIRONMENT              = var.environment
    }
  }

  tags = {
    Name = "${var.project_name}-migration-consumer-${var.environment}"
  }
}

resource "aws_lambda_event_source_mapping" "migration_queue" {
  event_source_arn                  = var.migration_queue_arn
  function_name                     = aws_lambda_function.migration_consumer.arn
  batch_size                        = 1 # un documento por invocación, más fácil de trackear/reintentar
  maximum_batching_window_in_seconds = 0
}

resource "aws_cloudwatch_log_group" "migration_consumer" {
  name              = "/aws/lambda/${aws_lambda_function.migration_consumer.function_name}"
  retention_in_days = 30
}
