variable "project_name" {
  description = "Nombre del proyecto, usado como prefijo en los recursos"
  type        = string
}

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC — output del módulo network"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs de las subnets privadas — output del módulo network"
  type        = list(string)
}

variable "lambda_security_group_id" {
  description = "Security Group de las Lambdas — se les da acceso al puerto 5432"
  type        = string
}

variable "database_name" {
  description = "Nombre de la base de datos inicial"
  type        = string
  default     = "gestion_documental"
}

variable "master_username" {
  description = "Usuario master de Aurora"
  type        = string
  default     = "dbadmin"
}

variable "engine_version" {
  description = "Versión de Aurora PostgreSQL — 15.17+ soporta pgvector nativamente"
  type        = string
  default     = "15.17"
}

variable "min_capacity" {
  description = "ACU mínimo del Aurora Serverless v2 (0.5 = mínimo posible)"
  type        = number
  default     = 0.5
}

variable "max_capacity" {
  description = "ACU máximo del Aurora Serverless v2"
  type        = number
  default     = 4
}

variable "instance_count" {
  description = "Cantidad de instancias del cluster (1 para portfolio/dev, 2+ para Multi-AZ real)"
  type        = number
  default     = 1
}
