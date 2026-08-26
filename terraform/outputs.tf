/*
output "api_invoke_url" {
  description = "URL del API (accesible solo desde IPs de oficina o vía el VPC Endpoint)"
  value       = module.api.invoke_url
}
*/
output "cognito_user_pool_id" {
  value = module.cognito.user_pool_id
}

output "cognito_app_client_id" {
  value = module.cognito.app_client_id
}

output "documents_bucket_id" {
  value = module.storage.bucket_id
}

output "aurora_cluster_endpoint" {
  value = module.data_aurora.cluster_endpoint
}

output "aurora_master_user_secret_arn" {
  description = "ARN del secret con las credenciales de Aurora — usarlo para correr el script de migración de schema"
  value       = module.data_aurora.master_user_secret_arn
}

output "client_vpn_endpoint_dns_name" {
  value = module.network.client_vpn_endpoint_dns_name
}
/*
output "github_actions_role_arn" {
  description = "ARN a usar en el workflow de GitHub Actions"
  value       = module.cicd.github_actions_role_arn
}

output "cloudwatch_dashboard_name" {
  value = module.monitoring.dashboard_name
}
*/

output "documents_metadata_table_name" {
  #value = aws_dynamodb_table.documents_metadata.name
  value = module.data_dynamodb.documents_metadata_table_name
}

output "documents_metadata_table_arn" {
  #value = aws_dynamodb_table.documents_metadata.arn
  value = module.data_dynamodb.documents_metadata_table_arn
}

output "audit_log_table_name" {
  #value = aws_dynamodb_table.audit_log.name
  value = module.data_dynamodb.audit_log_table_name
}

output "rbac_permissions_table_name" {
  #value = aws_dynamodb_table.rbac_permissions.name
  value = module.data_dynamodb.rbac_permissions_table_name
}
