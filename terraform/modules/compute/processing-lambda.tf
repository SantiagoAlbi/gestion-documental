variable "lambda_source_dir" {
  description = "Carpeta con el código Python de las Lambdas — todavía no existe, crearla antes de terraform apply"
  type        = string
  default     = "../../src/lambdas"
}

# ---------------------------------------------------------------------------
# NOTA: el código Python real (extracción nativa / Textract / chunking /
# embeddings / RBAC / Bedrock) todavía no está escrito. Este bloque empaqueta
# lo que exista en lambda_source_dir/processing — por ahora es infraestructura
# lista para recibir el código de aplicación en el próximo paso.
# ---------------------------------------------------------------------------

data "archive_file" "processing" {
  type        = "zip"
  source_dir  = "${var.lambda_source_dir}/processing"
  output_path = "${path.module}/.build/processing.zip"
}

resource "aws_lambda_function" "processing" {
  function_name = "${var.project_name}-processing-${var.environment}"
  role          = aws_iam_role.lambda_processing.arn
  handler       = "handler.lambda_handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout_processing
  memory_size   = 512

  filename         = data.archive_file.processing.output_path
  source_code_hash = data.archive_file.processing.output_base64sha256

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
    Name = "${var.project_name}-processing-${var.environment}"
  }
}

resource "aws_lambda_permission" "allow_s3_invoke_processing" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processing.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.documents_bucket_arn
}

resource "aws_cloudwatch_log_group" "processing" {
  name              = "/aws/lambda/${aws_lambda_function.processing.function_name}"
  retention_in_days = 30
}
