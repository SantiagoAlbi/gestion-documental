output "user_pool_id" {
  description = "ID del User Pool"
  value       = aws_cognito_user_pool.main.id
}

output "user_pool_arn" {
  description = "ARN del User Pool — usado por el Cognito Authorizer de API Gateway"
  value       = aws_cognito_user_pool.main.arn
}

output "user_pool_endpoint" {
  description = "Endpoint del User Pool — para construir el issuer del JWT (https://<endpoint>)"
  value       = aws_cognito_user_pool.main.endpoint
}

output "app_client_id" {
  description = "ID del App Client — lo usa el frontend para autenticar"
  value       = aws_cognito_user_pool_client.app.id
}

output "group_names" {
  description = "Nombres de los grupos creados — deben coincidir con las filas de rbac-permissions"
  value       = [for g in var.groups : g.name]
}
