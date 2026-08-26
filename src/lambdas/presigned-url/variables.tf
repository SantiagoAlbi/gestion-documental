variable "project_name" {
  description = "Nombre del proyecto, usado como prefijo en los recursos"
  type        = string
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
}

# --- Red (módulo network) ---
variable "private_subnet_ids" {
  description = "Subnets privadas donde corren las Lambdas en VPC"
  type        = list(string)
}

variable "lambda_security_group_id" {
  description = "Security Group base para Lambdas en VPC"
  type        = string
}

# --- Storage (módulo storage) ---
variable "documents_bucket_name" {
  type = string
}

variable "documents_bucket_arn" {
  type = string
}

# --- DynamoDB (módulo data-dynamodb) ---
variable "documents_metadata_table_name" {
  type = string
}

variable "documents_metadata_table_arn" {
  type = string
}

variable "audit_log_table_name" {
  type = string
}

variable "audit_log_table_arn" {
  type = string
}

variable "rbac_permissions_table_name" {
  type = string
}

variable "rbac_permissions_table_arn" {
  type = string
}

# --- Aurora (módulo data-aurora) ---
variable "aurora_cluster_endpoint" {
  type = string
}

variable "aurora_database_name" {
  type = string
}

variable "aurora_master_user_secret_arn" {
  type = string
}

# --- Queue (módulo queue) ---
variable "migration_queue_arn" {
  type = string
}

# --- Lambda runtime config ---
variable "lambda_runtime" {
  type    = string
  default = "python3.13"
}

variable "lambda_timeout_processing" {
  description = "Timeout de la Lambda de procesamiento (solo dispara Textract async / extrae texto nativo, no espera el resultado)"
  type        = number
  default     = 60
}

variable "lambda_timeout_presigned" {
  description = "Timeout de la Lambda de presigned URL — operación rápida, sin espera de red pesada"
  type        = number
  default     = 15
}

variable "presigned_url_expiration_seconds" {
  description = "Cuánto tiempo es válida la presigned URL antes de que el frontend tenga que pedir una nueva"
  type        = number
  default     = 300
}
