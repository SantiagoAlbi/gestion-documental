variable "project_name" {
  description = "Nombre del proyecto, usado como prefijo en los recursos"
  type        = string
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
}

variable "bucket_arn" {
  description = "ARN del bucket de documentos — output del módulo storage, para la queue policy"
  type        = string
}

variable "visibility_timeout_seconds" {
  description = "Debe ser >= timeout de la Lambda consumidora, para evitar reprocesar un mensaje en vuelo"
  type        = number
  default     = 300
}

variable "message_retention_seconds" {
  description = "Cuánto tiempo se retiene un mensaje antes de descartarse (default 4 días)"
  type        = number
  default     = 345600
}

variable "max_receive_count" {
  description = "Intentos de procesamiento antes de mandar el mensaje a la DLQ"
  type        = number
  default     = 5
}
