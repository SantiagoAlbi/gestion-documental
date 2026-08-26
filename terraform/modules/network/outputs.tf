output "vpc_id" {
  description = "ID de la VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block de la VPC"
  value       = var.vpc_cidr
}

output "private_subnet_ids" {
  description = "IDs de las subnets privadas — usar en Aurora, Lambda y Client VPN"
  value       = aws_subnet.private[*].id
}

output "private_route_table_id" {
  description = "ID de la route table privada"
  value       = aws_route_table.private.id
}

output "lambda_security_group_id" {
  description = "Security Group base para Lambdas en VPC — módulo compute lo referencia"
  value       = aws_security_group.lambda.id
}

output "vpc_endpoints_security_group_id" {
  description = "Security Group de los Interface Endpoints"
  value       = aws_security_group.vpc_endpoints.id
}

output "client_vpn_endpoint_id" {
  description = "ID del Client VPN endpoint — usado por el módulo de Lights-Off scheduling"
  value       = aws_ec2_client_vpn_endpoint.main.id
}

output "execute_api_vpc_endpoint_id" {
  description = "ID del Interface Endpoint de execute-api — usado por el módulo api para el REST API privado"
  value       = aws_vpc_endpoint.interface["execute_api"].id
}

output "client_vpn_endpoint_dns_name" {
  description = "DNS name del Client VPN endpoint, para el archivo .ovpn de conexión"
  value       = aws_ec2_client_vpn_endpoint.main.dns_name
}

output "client_vpn_ca_private_key_pem" {
  description = "Clave privada de la CA — necesaria para firmar certificados de cliente individuales por usuario"
  value       = tls_private_key.ca.private_key_pem
  sensitive   = true
}

output "client_vpn_ca_cert_pem" {
  description = "Certificado de la CA — necesario para firmar certificados de cliente individuales por usuario"
  value       = tls_self_signed_cert.ca.cert_pem
  sensitive   = true
}
