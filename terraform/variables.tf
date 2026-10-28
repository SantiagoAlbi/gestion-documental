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
  description = "Región AWS de despliegue"
  type        = string
  default     = "us-east-1"
}

variable "github_repo" {
  description = "Repo de GitHub en formato owner/repo-name, usado en el módulo cicd (OIDC)"
  type        = string
  default     = "SantiagoAlbi/gestion-documental" # ajustar cuando se cree el repo
}

variable "allowed_office_ips" {
  description = "CIDRs de las oficinas autorizadas — completar antes de aplicar, sin esto el acceso público queda bloqueado por completo (el VPN sigue funcionando)"
  type        = list(string)
  default     = []
}

variable "alert_email" {
  description = "Email que recibe las alarms de CloudWatch"
  type        = string
}

variable "migration_reserved_concurrency" {
  description = "Concurrencia reservada para la Lambda de migración — null si la cuenta no tiene margen (ver límite de la cuenta con aws lambda get-account-settings)"
  type        = number
  default     = 5
  nullable    = true
}

#fase2

variable "roles" {
  description = <<-EOT
    Fuente única de verdad del RBAC. Cada clave es un grupo de Cognito y una
    fila en rbac-permissions. Agregar o quitar un rol acá actualiza ambos.
  EOT
  type = map(object({
    description        = string
    precedence         = number
    allowed_categories = list(string)
  }))
  default = {
    administradores = {
      description        = "Módulo 1 — acceso a toda la documentación"
      precedence         = 1
      allowed_categories = ["legal", "rrhh", "compras", "tramites"]
    }
    legal-abogado = {
      description        = "Módulo 2 — categoría Legal"
      precedence         = 10
      allowed_categories = ["legal"]
    }
    legal-asistente = {
      description        = "Módulo 2 — categoría Legal (acceso acotado)"
      precedence         = 11
      allowed_categories = ["legal"]
    }
    rrhh-jefe = {
      description        = "Módulo 2 — categoría RRHH, incluye reportes agregados"
      precedence         = 9
      allowed_categories = ["rrhh"]
    }
    rrhh-analista = {
      description        = "Módulo 2 — categoría RRHH (legajos, descripciones de puesto)"
      precedence         = 10
      allowed_categories = ["rrhh"]
    }
    compras-comprador = {
      description        = "Módulo 2 — categoría Compras/Contratos"
      precedence         = 10
      allowed_categories = ["compras"]
    }
    compras-asistente = {
      description        = "Módulo 2 — categoría Compras/Contratos (acceso acotado)"
      precedence         = 11
      allowed_categories = ["compras"]
    }
    atencion-agente = {
      description        = "Módulo 2 — trámites y Agenda (carnet, DNI, certificados)"
      precedence         = 10
      allowed_categories = ["tramites"]
    }
  }
}

variable "mfa_configuration" {
  description = "MFA del user pool: ON (producción) u OPTIONAL (pruebas)"
  type        = string
  default     = "ON"

  validation {
    condition     = contains(["ON", "OPTIONAL", "OFF"], var.mfa_configuration)
    error_message = "mfa_configuration debe ser ON, OPTIONAL u OFF."
  }
}

variable "force_destroy_buckets" {
  description = "Permite destruir buckets con objetos (solo dev; en producción false para no perder documentos)."
  type        = bool
  default     = false
}
