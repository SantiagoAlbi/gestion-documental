variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

# --- Cognito ---
variable "cognito_user_pool_arn" {
  type = string
}

# --- Compute (Lambdas) ---
variable "presigned_lambda_invoke_arn" {
  type = string
}

variable "presigned_lambda_function_name" {
  type = string
}

variable "query_lambda_invoke_arn" {
  type = string
}

variable "query_lambda_function_name" {
  type = string
}

# --- Network ---
variable "execute_api_vpc_endpoint_id" {
  description = "ID del Interface Endpoint de execute-api — output del módulo network"
  type        = string
}

variable "allowed_office_ips" {
  description = "CIDRs de las oficinas autorizadas — acceso público restringido por IP"
  type        = list(string)
  default     = [] # completar con las IPs reales de las oficinas
}
