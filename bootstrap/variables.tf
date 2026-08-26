variable "project_name" {
  description = "Nombre del proyecto, usado como prefijo en los recursos"
  type        = string
  default     = "gestion-documental"
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "Región AWS donde se crea el state bucket"
  type        = string
  default     = "us-east-1"
}
