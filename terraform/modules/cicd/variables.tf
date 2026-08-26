variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "github_repo" {
  description = "Repo de GitHub en formato owner/repo-name"
  type        = string
}

variable "create_oidc_provider" {
  description = "false si el OIDC provider de GitHub ya existe en la cuenta (compartido entre proyectos, como en tus otros repos) — true solo si esta es la primera vez que se crea en la cuenta"
  type        = bool
  default     = false
}
