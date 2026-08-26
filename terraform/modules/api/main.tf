terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_caller_identity" "current" {}

resource "aws_api_gateway_rest_api" "main" {
  name = "${var.project_name}-api-${var.environment}"

  # REGIONAL, no PRIVATE: necesitamos que las oficinas lleguen por internet
  # público (filtrado por IP) Y que el Client VPN llegue de forma privada
  # vía el Interface Endpoint. PRIVATE bloquearía el acceso público entero.
  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name = "${var.project_name}-api-${var.environment}"
  }
}

# Resource policy separada (no inline en aws_api_gateway_rest_api) para
# evitar la referencia circular al ARN de ejecución del propio API.
resource "aws_api_gateway_rest_api_policy" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowFromOfficeIPs"
        Effect    = "Allow"
        Principal = "*"
        Action    = "execute-api:Invoke"
        Resource  = "${aws_api_gateway_rest_api.main.execution_arn}/*"
        Condition = {
          IpAddress = { "aws:SourceIp" = var.allowed_office_ips }
        }
      },
      {
        Sid       = "AllowFromClientVPNviaVPCEndpoint"
        Effect    = "Allow"
        Principal = "*"
        Action    = "execute-api:Invoke"
        Resource  = "${aws_api_gateway_rest_api.main.execution_arn}/*"
        Condition = {
          StringEquals = { "aws:SourceVpce" = var.execute_api_vpc_endpoint_id }
        }
      }
    ]
  })
}

resource "aws_api_gateway_authorizer" "cognito" {
  name          = "${var.project_name}-cognito-authorizer-${var.environment}"
  rest_api_id   = aws_api_gateway_rest_api.main.id
  type          = "COGNITO_USER_POOLS"
  provider_arns = [var.cognito_user_pool_arn]
}
