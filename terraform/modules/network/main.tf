data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_region" "current" {}

# ---------------------------------------------------------------------------
# VPC — sin Internet Gateway. No hay ruta a internet en ningún sentido.
# ---------------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc-${var.environment}"
  }
}

# ---------------------------------------------------------------------------
# Subnets privadas — únicas en esta VPC. Aurora + Lambdas viven acá.
# ---------------------------------------------------------------------------

resource "aws_subnet" "private" {
  count             = var.az_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.project_name}-private-${count.index + 1}-${var.environment}"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  # Sin ruta 0.0.0.0/0 — a propósito. Todo el tráfico a AWS sale por VPC Endpoints.

  tags = {
    Name = "${var.project_name}-private-rt-${var.environment}"
  }
}

resource "aws_route_table_association" "private" {
  count          = var.az_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ---------------------------------------------------------------------------
# Security Group para los VPC Endpoints de tipo Interface (ENIs)
# ---------------------------------------------------------------------------

resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.project_name}-vpce-sg-${var.environment}"
  description = "Permite HTTPS desde dentro de la VPC hacia los VPC Endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS desde la VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-vpce-sg-${var.environment}"
  }
}

# ---------------------------------------------------------------------------
# Gateway Endpoints — gratis, se asocian a la route table, no consumen ENI
# ---------------------------------------------------------------------------

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = {
    Name = "${var.project_name}-vpce-s3-${var.environment}"
  }
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = {
    Name = "${var.project_name}-vpce-dynamodb-${var.environment}"
  }
}

# ---------------------------------------------------------------------------
# Interface Endpoints — con costo, uno por servicio, ENI en cada subnet privada
# ---------------------------------------------------------------------------

locals {
  interface_endpoint_services = {
    secretsmanager = "secretsmanager"
    bedrock        = "bedrock-runtime"
    textract       = "textract"
    logs           = "logs"
    execute_api    = "execute-api"
  }
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoint_services

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.value}"
  vpc_endpoint_type    = "Interface"
  subnet_ids           = aws_subnet.private[*].id
  security_group_ids   = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled  = true

  tags = {
    Name = "${var.project_name}-vpce-${each.key}-${var.environment}"
  }
}

# ---------------------------------------------------------------------------
# Security Group base para las Lambdas en VPC (Aurora + resto de módulos
# amplían esto con sus propias reglas de ingress/egress específicas)
# ---------------------------------------------------------------------------

resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-lambda-sg-${var.environment}"
  description = "Security Group base para Lambdas dentro de la VPC"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Salida HTTPS hacia VPC Endpoints y Aurora"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name = "${var.project_name}-lambda-sg-${var.environment}"
  }
}
