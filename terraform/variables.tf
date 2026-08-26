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
