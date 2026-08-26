variable "project_name" {
  description = "Nombre del proyecto, usado como prefijo en los recursos"
  type        = string
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block de la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Cantidad de Availability Zones a usar (mínimo 2 por el subnet group de Aurora)"
  type        = number
  default     = 2
}

variable "client_vpn_cidr" {
  description = "CIDR block para las IPs que se asignan a los clientes VPN — no puede solaparse con vpc_cidr"
  type        = string
  default     = "10.100.0.0/22"
}

variable "aws_region" {
  description = "Región AWS de despliegue"
  type        = string
  default     = "us-east-1"
}
