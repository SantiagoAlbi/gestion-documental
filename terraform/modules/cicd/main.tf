terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# El OIDC provider de GitHub es único por cuenta AWS, no por proyecto — ya
# debería existir de tus otros repos (task-manager, e-commerce, finops).
# Si esta fuera la primera vez en la cuenta, create_oidc_provider = true.

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

locals {
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-github-actions-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
        }
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

# Permisos amplios a propósito: este role corre `terraform apply` completo
# (crea/modifica IAM roles, Cognito, RDS, VPC, etc.), no solo deploya
# código. Restringirlo a acciones puntuales rompería el pipeline cada vez
# que se agregue un recurso nuevo. Lo que sí queda scopeado por el trust
# policy de arriba: solo este repo puede asumir el role, sin credenciales
# estáticas guardadas en ningún lado.
resource "aws_iam_role_policy" "github_actions" {
  name = "${var.project_name}-github-actions-policy-${var.environment}"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["*"]
      Resource = "*"
    }]
  })
}
