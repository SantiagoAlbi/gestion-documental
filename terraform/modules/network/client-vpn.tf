resource "aws_security_group" "client_vpn" {
  name        = "${var.project_name}-client-vpn-sg-${var.environment}"
  description = "Security Group para clientes conectados via Client VPN"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Acceso a la VPC (VPC Endpoints, Aurora)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name = "${var.project_name}-client-vpn-sg-${var.environment}"
  }
}

resource "aws_ec2_client_vpn_endpoint" "main" {
  description            = "${var.project_name}-client-vpn-${var.environment}"
  server_certificate_arn = aws_acm_certificate.server.arn
  client_cidr_block      = var.client_vpn_cidr
  split_tunnel           = true # solo tráfico hacia la VPC pasa por el túnel, no todo internet
  vpc_id                 = aws_vpc.main.id
  security_group_ids     = [aws_security_group.client_vpn.id]

  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = aws_acm_certificate.client_root.arn
  }

  connection_log_options {
    enabled = false # portfolio/demo — en un caso real, activar con CloudWatch Log Group
  }

  tags = {
    Name = "${var.project_name}-client-vpn-${var.environment}"
  }
}

# La asociación a subnets NO se maneja acá — es dinámica por Lights-Off
# scheduling (módulo compute): la Lambda asocia las subnets a la mañana y
# las desasocia a la noche. Si Terraform la manejara como recurso fijo,
# pelearía contra ese estado cada vez que la Lambda la desasocia.
# Ver: compute/lights-off.tf

resource "aws_ec2_client_vpn_authorization_rule" "vpc_access" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  target_network_cidr    = var.vpc_cidr
  authorize_all_groups   = true
  description             = "Autoriza a todo cliente autenticado (posee certificado propio, firmado por la CA) a llegar a la VPC"
}
