variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "alert_email" {
  description = "Email que recibe las notificaciones de las alarms"
  type        = string
}

# --- Compute (nombres de función, para las alarms de errores) ---
variable "lambda_function_names" {
  description = "Nombres de todas las funciones Lambda del proyecto — una alarm de errores por cada una"
  type        = list(string)
}

# --- Queue ---
variable "migration_dlq_name" {
  type = string
}

# --- API ---
variable "api_gateway_name" {
  type = string
}

variable "api_gateway_stage" {
  type = string
}

# --- Aurora ---
variable "aurora_cluster_id" {
  type = string
}
