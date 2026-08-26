variable "project_name" {
  description = "Nombre del proyecto, usado como prefijo en los recursos"
  type        = string
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
}

variable "mfa_configuration" {
  description = "ON obliga MFA a todos los usuarios — correcto para un ente gubernamental"
  type        = string
  default     = "ON"
}

variable "groups" {
  description = <<-EOT
    Grupos de Cognito = roles de RBAC. Cada nombre acá debe tener su fila
    correspondiente en la tabla rbac-permissions (módulo data-dynamodb) con
    las categorías permitidas para ese grupo.

    "administradores" (precedence baja = prioridad alta) representa el
    Módulo 1 (acceso total). El resto de los grupos deberían ser uno por
    puesto/departamento real del ente para el Módulo 2 — reemplazar el
    ejemplo genérico por la lista real antes de aplicar en un entorno real.
  EOT
  type = list(object({
    name        = string
    description = string
    precedence  = number
  }))
  default = [
    {
      name        = "administradores"
      description = "Módulo 1 — acceso a toda la documentación, sin restricción de categoría"
      precedence  = 1
    },
    {
      name        = "legal-abogado"
      description = "Módulo 2 — documentos de la categoría Legal"
      precedence  = 10
    },
    {
      name        = "legal-asistente"
      description = "Módulo 2 — documentos de la categoría Legal (acceso acotado)"
      precedence  = 11
    },
    {
      name        = "rrhh-analista"
      description = "Módulo 2 — documentos de la categoría RRHH (legajos, descripciones de puesto)"
      precedence  = 10
    },
    {
      name        = "rrhh-jefe"
      description = "Módulo 2 — documentos de la categoría RRHH, incluye reportes agregados"
      precedence  = 9
    },
    {
      name        = "compras-comprador"
      description = "Módulo 2 — documentos de la categoría Compras/Contratos"
      precedence  = 10
    },
    {
      name        = "compras-asistente"
      description = "Módulo 2 — documentos de la categoría Compras/Contratos (acceso acotado)"
      precedence  = 11
    },
    {
      name        = "atencion-agente"
      description = "Módulo 2 — documentos de trámites y Agenda (carnet, DNI, certificados)"
      precedence  = 10
    }
  ]
}
