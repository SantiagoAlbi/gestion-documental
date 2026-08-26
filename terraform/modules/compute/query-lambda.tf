data "archive_file" "query" {
  type        = "zip"
  source_dir  = "${var.lambda_source_dir}/query"
  output_path = "${path.module}/.build/query.zip"
}

resource "aws_lambda_function" "query" {
  function_name = "${var.project_name}-query-${var.environment}"
  role          = aws_iam_role.lambda_processing.arn # mismo role: Aurora, RBAC, Bedrock
  handler       = "handler.lambda_handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout_query
  memory_size   = 512

  filename         = data.archive_file.query.output_path
  source_code_hash = data.archive_file.query.output_base64sha256

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      RBAC_PERMISSIONS_TABLE = var.rbac_permissions_table_name
      AUDIT_LOG_TABLE        = var.audit_log_table_name
      AURORA_ENDPOINT        = var.aurora_cluster_endpoint
      AURORA_DATABASE        = var.aurora_database_name
      AURORA_SECRET_ARN      = var.aurora_master_user_secret_arn
      BEDROCK_TEXT_MODEL_ID  = var.bedrock_text_model_id
      GUARDRAIL_ID           = aws_bedrock_guardrail.main.guardrail_id
      GUARDRAIL_VERSION      = aws_bedrock_guardrail_version.main.version
      ENVIRONMENT            = var.environment
    }
  }

  tags = {
    Name = "${var.project_name}-query-${var.environment}"
  }
}

resource "aws_cloudwatch_log_group" "query" {
  name              = "/aws/lambda/${aws_lambda_function.query.function_name}"
  retention_in_days = 30
}

# aws_lambda_permission para que API Gateway la invoque se agrega en el
# módulo api, igual que con presigned.
