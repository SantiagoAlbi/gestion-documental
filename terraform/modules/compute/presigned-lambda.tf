resource "aws_iam_role" "lambda_presigned" {
  name = "${var.project_name}-lambda-presigned-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "presigned_basic_logs" {
  role       = aws_iam_role.lambda_presigned.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_presigned_permissions" {
  name = "${var.project_name}-lambda-presigned-permissions-${var.environment}"
  role = aws_iam_role.lambda_presigned.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "S3PresignPut"
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${var.documents_bucket_arn}/*"
      },
      {
        Sid      = "DynamoDBInitialMetadata"
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem"]
        Resource = var.documents_metadata_table_arn
      }
    ]
  })
}

data "archive_file" "presigned" {
  type        = "zip"
  source_dir  = "${var.lambda_source_dir}/presigned-url"
  output_path = "${path.module}/.build/presigned.zip"
}

resource "aws_lambda_function" "presigned" {
  function_name = "${var.project_name}-presigned-url-${var.environment}"
  role          = aws_iam_role.lambda_presigned.arn
  handler       = "handler.lambda_handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout_presigned
  memory_size   = 256

  filename         = data.archive_file.presigned.output_path
  source_code_hash = data.archive_file.presigned.output_base64sha256

  # Sin vpc_config a propósito — no necesita Aurora, solo S3 y DynamoDB.

  environment {
    variables = {
      DOCUMENTS_BUCKET         = var.documents_bucket_name
      DOCUMENTS_METADATA_TABLE = var.documents_metadata_table_name
      URL_EXPIRATION_SECONDS   = tostring(var.presigned_url_expiration_seconds)
      ENVIRONMENT              = var.environment
    }
  }

  tags = {
    Name = "${var.project_name}-presigned-url-${var.environment}"
  }
}

resource "aws_cloudwatch_log_group" "presigned" {
  name              = "/aws/lambda/${aws_lambda_function.presigned.function_name}"
  retention_in_days = 30
}

# El aws_lambda_permission para que API Gateway invoque esta función se
# agrega en el módulo api (necesita el ARN del API Gateway, que todavía
# no existe acá).
