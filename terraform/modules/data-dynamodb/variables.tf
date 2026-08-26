variable "project_name" {
  description = "Nombre del proyecto, usado como prefijo en los recursos"
  type        = string
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
}

variable "billing_mode" {
  description = "Modo de facturación de las tablas DynamoDB"
  type        = string
  default     = "PAY_PER_REQUEST" # sin capacidad provisionada, escala con el tráfico real
}
