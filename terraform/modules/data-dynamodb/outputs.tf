output "documents_metadata_table_name" {
  description = "Nombre de la tabla documents-metadata"
  value       = aws_dynamodb_table.documents_metadata.name
}

output "documents_metadata_table_arn" {
  description = "ARN de la tabla documents-metadata — para IAM policies de las Lambdas"
  value       = aws_dynamodb_table.documents_metadata.arn
}

output "audit_log_table_name" {
  description = "Nombre de la tabla audit-log"
  value       = aws_dynamodb_table.audit_log.name
}

output "audit_log_table_arn" {
  description = "ARN de la tabla audit-log — para IAM policies de las Lambdas"
  value       = aws_dynamodb_table.audit_log.arn
}

output "rbac_permissions_table_name" {
  description = "Nombre de la tabla rbac-permissions"
  value       = aws_dynamodb_table.rbac_permissions.name
}

output "rbac_permissions_table_arn" {
  description = "ARN de la tabla rbac-permissions — para IAM policies de las Lambdas"
  value       = aws_dynamodb_table.rbac_permissions.arn
}
