data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ---------------------------------------------------------------------------
# IAM Role compartido por las Lambdas de procesamiento/consulta.
# Permisos least-privilege, uno por servicio que efectivamente usan.
# ---------------------------------------------------------------------------

resource "aws_iam_role" "lambda_processing" {
  name = "${var.project_name}-lambda-processing-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Acceso a la VPC (ENIs) — requerido porque la Lambda vive dentro de la VPC para llegar a Aurora
resource "aws_iam_role_policy_attachment" "vpc_access" {
  role       = aws_iam_role.lambda_processing.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda_processing_permissions" {
  name = "${var.project_name}-lambda-processing-permissions-${var.environment}"
  role = aws_iam_role.lambda_processing.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ReadDocuments"
        Effect = "Allow"
        Action = ["s3:GetObject"]
        Resource = "${var.documents_bucket_arn}/*"
      },
      {
        Sid    = "DynamoDBDocumentsMetadata"
        Effect = "Allow"
        Action = ["dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:GetItem"]
        Resource = [
          var.documents_metadata_table_arn,
          "${var.documents_metadata_table_arn}/index/*"
        ]
      },
      {
        Sid      = "DynamoDBAuditLog"
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem"]
        Resource = var.audit_log_table_arn
      },
      {
        Sid      = "SecretsManagerAuroraCreds"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = var.aurora_master_user_secret_arn
      },
      {
        Sid    = "Textract"
        Effect = "Allow"
        Action = [
          "textract:StartDocumentTextDetection",
          "textract:GetDocumentTextDetection"
        ]
        Resource = "*" # Textract no soporta scoping por ARN de recurso
      },
      {
        Sid      = "BedrockEmbeddings"
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/amazon.titan-embed-text-v2:0"
      },
      {
        Sid      = "BedrockTextGeneration"
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/${var.bedrock_text_model_id}"
      },
      {
        Sid      = "BedrockGuardrail"
        Effect   = "Allow"
        Action   = ["bedrock:ApplyGuardrail"]
        Resource = aws_bedrock_guardrail.main.guardrail_arn
      },
      {
        Sid      = "DynamoDBRbacPermissions"
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem"]
        Resource = var.rbac_permissions_table_arn
      },
      {
        Sid      = "SQSConsumeMigration"
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = var.migration_queue_arn
      }
    ]
  })
}
