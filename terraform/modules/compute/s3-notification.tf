resource "aws_s3_bucket_notification" "documents" {
  bucket = var.documents_bucket_name

  # Subida individual (frontend, vía presigned URL) — Lambda directa
  lambda_function {
    lambda_function_arn = aws_lambda_function.processing.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "uploads/"
  }

  # Migración masiva inicial — vía cola SQS con concurrencia reservada
  queue {
    queue_arn     = var.migration_queue_arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "batch-uploads/"
  }

  depends_on = [
    aws_lambda_permission.allow_s3_invoke_processing
  ]
}
