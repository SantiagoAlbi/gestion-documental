# ---------------------------------------------------------------------------
# Textract corre async. Al terminar un job, publica en este topic SNS,
# que dispara la Lambda de callback (esta Lambda SÍ va en VPC, porque
# escribe en Aurora/pgvector).
# ---------------------------------------------------------------------------

resource "aws_sns_topic" "textract_completion" {
  name = "${var.project_name}-textract-completion-${var.environment}"
}

# Role que Textract asume para publicar en el topic al terminar el job
resource "aws_iam_role" "textract_service" {
  name = "${var.project_name}-textract-service-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "textract.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "textract_service_sns_publish" {
  name = "${var.project_name}-textract-sns-publish-${var.environment}"
  role = aws_iam_role.textract_service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sns:Publish"
      Resource = aws_sns_topic.textract_completion.arn
    }]
  })
}

# La Lambda de processing necesita pasarle este role a Textract al iniciar
# el job (iam:PassRole), y conocer el ARN del topic + del role.
resource "aws_iam_role_policy" "processing_pass_textract_role" {
  name = "${var.project_name}-processing-pass-textract-role-${var.environment}"
  role = aws_iam_role.lambda_processing.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "iam:PassRole"
      Resource = aws_iam_role.textract_service.arn
    }]
  })
}

data "archive_file" "textract_callback" {
  type        = "zip"
  source_dir  = "${var.lambda_source_dir}/textract-callback"
  output_path = "${path.module}/.build/textract-callback.zip"
}

resource "aws_lambda_function" "textract_callback" {
  function_name = "${var.project_name}-textract-callback-${var.environment}"
  role          = aws_iam_role.lambda_processing.arn # mismos permisos que processing (Aurora, DynamoDB, Bedrock)
  handler       = "handler.lambda_handler"
  runtime       = var.lambda_runtime
  timeout       = 120 # Textract puede devolver documentos largos, más chunking + embeddings
  memory_size   = 512

  filename         = data.archive_file.textract_callback.output_path
  source_code_hash = data.archive_file.textract_callback.output_base64sha256

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
    Name = "${var.project_name}-textract-callback-${var.environment}"
  }
}

resource "aws_sns_topic_subscription" "textract_callback" {
  topic_arn = aws_sns_topic.textract_completion.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.textract_callback.arn
}

resource "aws_lambda_permission" "allow_sns_invoke_textract_callback" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.textract_callback.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.textract_completion.arn
}

resource "aws_cloudwatch_log_group" "textract_callback" {
  name              = "/aws/lambda/${aws_lambda_function.textract_callback.function_name}"
  retention_in_days = 30
}
