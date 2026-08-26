terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_s3_bucket" "documents" {
  bucket = "${var.project_name}-documents-${var.environment}"
   
  tags = {
    Name = "${var.project_name}-documents-${var.environment}"
  }
}

resource "aws_s3_bucket_versioning" "documents" {
  bucket = aws_s3_bucket.documents.id

  versioning_configuration {
    status = "Enabled" # protege contra sobrescritura/borrado accidental de un documento legal
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "documents" {
  bucket = aws_s3_bucket.documents.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CORS — necesario porque el frontend sube directo a S3 con presigned URL
# (PUT desde el browser), no a través de un Lambda/API Gateway.
resource "aws_s3_bucket_cors_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id
  depends_on = [aws_s3_bucket_public_access_block.documents]


  cors_rule {
    allowed_methods = ["PUT", "GET"]
    allowed_origins = var.cors_allowed_origins
    allowed_headers = ["*"]
    max_age_seconds = 3000
  }
}

# Fuerza TLS en cada request al bucket — rechaza HTTP plano.
resource "aws_s3_bucket_policy" "documents" {
  bucket = aws_s3_bucket.documents.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.documents.arn,
          "${aws_s3_bucket.documents.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# Lifecycle: limpia versiones viejas y multipart uploads incompletos.
# No archiva a Glacier — para un ente gubernamental los documentos legales
# suelen necesitar acceso rápido, no archivado frío.
resource "aws_s3_bucket_lifecycle_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id

  rule {
    id     = "cleanup-noncurrent-versions"
    status = "Enabled"

    filter {}   # <- agregar esta línea

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
