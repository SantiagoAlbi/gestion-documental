terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ---------------------------------------------------------------------------
# 1. documents-metadata
# ---------------------------------------------------------------------------

resource "aws_dynamodb_table" "documents_metadata" {
  name         = "${var.project_name}-documents-metadata-${var.environment}"
  billing_mode = var.billing_mode
  hash_key     = "document_id"

  attribute {
    name = "document_id"
    type = "S"
  }

  attribute {
    name = "category"
    type = "S"
  }

  attribute {
    name = "uploaded_by"
    type = "S"
  }

  attribute {
    name = "uploaded_at"
    type = "S"
  }

  # GSI1: listar documentos por categoría, más recientes primero
  global_secondary_index {
    name            = "category-uploaded_at-index"
    hash_key        = "category"
    range_key       = "uploaded_at"
    projection_type = "ALL"
  }

  # GSI2: listar documentos subidos por un usuario puntual
  global_secondary_index {
    name            = "uploaded_by-uploaded_at-index"
    hash_key        = "uploaded_by"
    range_key       = "uploaded_at"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name = "${var.project_name}-documents-metadata-${var.environment}"
  }
}

# ---------------------------------------------------------------------------
# 2. audit-log — append-only, nivel A obligatorio (compliance)
# ---------------------------------------------------------------------------

resource "aws_dynamodb_table" "audit_log" {
  name         = "${var.project_name}-audit-log-${var.environment}"
  billing_mode = var.billing_mode
  hash_key     = "document_id"
  range_key    = "sk"

  attribute {
    name = "document_id"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  attribute {
    name = "actor_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  attribute {
    name = "date"
    type = "S"
  }

  # GSI1: qué hizo un usuario puntual (auditoría por persona)
  global_secondary_index {
    name            = "actor_id-timestamp-index"
    hash_key        = "actor_id"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  # GSI2: reporte de actividad de un día/rango sin hacer scan
  global_secondary_index {
    name            = "date-timestamp-index"
    hash_key        = "date"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  # Sin TTL a propósito — retención de auditoría sujeta a requisitos legales
  # del organismo, no a una política de borrado automático.

  tags = {
    Name = "${var.project_name}-audit-log-${var.environment}"
  }
}

# ---------------------------------------------------------------------------
# 3. rbac-permissions — rol -> categorías permitidas
# ---------------------------------------------------------------------------

resource "aws_dynamodb_table" "rbac_permissions" {
  name         = "${var.project_name}-rbac-permissions-${var.environment}"
  billing_mode = var.billing_mode
  hash_key     = "role"

  attribute {
    name = "role"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name = "${var.project_name}-rbac-permissions-${var.environment}"
  }
}
