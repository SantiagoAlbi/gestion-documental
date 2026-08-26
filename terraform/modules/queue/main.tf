terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_sqs_queue" "migration_dlq" {
  name                      = "${var.project_name}-migration-dlq-${var.environment}"
  message_retention_seconds = 1209600 # 14 días — máximo permitido, tiempo de sobra para investigar fallos
  sqs_managed_sse_enabled   = true

  tags = {
    Name = "${var.project_name}-migration-dlq-${var.environment}"
  }
}

resource "aws_sqs_queue" "migration" {
  name                       = "${var.project_name}-migration-queue-${var.environment}"
  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.migration_dlq.arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = {
    Name = "${var.project_name}-migration-queue-${var.environment}"
  }
}

# Permite que el bucket S3 (y solo ese bucket) publique mensajes en la cola
# cuando se suben archivos vía el flujo de migración masiva.
resource "aws_sqs_queue_policy" "migration" {
  queue_url = aws_sqs_queue.migration.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowS3SendMessage"
        Effect    = "Allow"
        Principal = { Service = "s3.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.migration.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = var.bucket_arn
          }
        }
      }
    ]
  })
}
