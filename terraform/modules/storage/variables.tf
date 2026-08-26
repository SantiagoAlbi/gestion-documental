variable "project_name" {
  description = "Nombre del proyecto, usado como prefijo en los recursos"
  type        = string
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
}

variable "cors_allowed_origins" {
  description = "Orígenes permitidos para las subidas vía presigned URL desde el frontend"
  type        = list(string)
  default     = ["*"] # ajustar al dominio real del frontend cuando exista
}
