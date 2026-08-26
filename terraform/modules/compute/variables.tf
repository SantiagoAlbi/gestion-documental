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

# --- Client VPN (módulo network) — para Lights-Off scheduling ---
variable "client_vpn_endpoint_id" {
  type = string
}

variable "vpn_private_subnet_ids" {
  description = "Mismo valor que private_subnet_ids — separado para que quede explícito qué usa Lights-Off"
  type        = list(string)
}

variable "lights_off_timezone" {
  description = "Timezone para el horario de asociación/desasociación del Client VPN"
  type        = string
  default     = "America/Argentina/Buenos_Aires"
}

variable "lights_off_associate_cron" {
  description = "Cron de EventBridge Scheduler para asociar el VPN (inicio de horario laboral)"
  type        = string
  default     = "cron(0 8 ? * MON-FRI *)" # 8:00 AM, lunes a viernes
}

variable "lights_off_disassociate_cron" {
  description = "Cron de EventBridge Scheduler para desasociar el VPN (fin de horario laboral)"
  type        = string
  default     = "cron(0 19 ? * MON-FRI *)" # 7:00 PM, lunes a viernes
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

variable "bedrock_text_model_id" {
  description = "Modelo de Bedrock usado para generar la respuesta a partir del contexto recuperado"
  type        = string
  default     = "anthropic.claude-3-5-sonnet-20241022-v2:0"
}

variable "lambda_timeout_query" {
  description = "Timeout de la Lambda de consulta — incluye embedding + pgvector + invocación a Bedrock"
  type        = number
  default     = 30
}
