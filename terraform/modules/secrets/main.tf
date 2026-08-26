terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Módulo intencionalmente vacío por ahora.
#
# Las credenciales de Aurora NO viven acá: se gestionan solas vía
# `manage_master_user_password = true` en el módulo data-aurora (RDS crea,
# guarda y rota el secret en Secrets Manager sin código adicional).
#
# Este módulo queda reservado para secrets que puedan aparecer más adelante
# y que no tengan gestión nativa de AWS, por ejemplo:
#   - Credenciales de un servicio de terceros (si se integra alguno)
#   - API keys que no sean IAM-based
#
# Si el proyecto termina sin necesitar ninguno de estos, el módulo se puede
# quitar de terraform/main.tf sin impacto en el resto — no tiene dependencias
# entrantes de otros módulos.
# ---------------------------------------------------------------------------

# Ejemplo de cómo se vería un secret acá, para referencia futura:
#
# resource "aws_secretsmanager_secret" "example" {
#   name = "${var.project_name}-example-${var.environment}"
# }
#
# resource "aws_secretsmanager_secret_version" "example" {
#   secret_id     = aws_secretsmanager_secret.example.id
#   secret_string = jsonencode({ key = "value" })
# }
