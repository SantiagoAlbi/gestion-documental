output "cluster_endpoint" {
  description = "Endpoint de escritura del cluster — usar en la connection string de las Lambdas"
  value       = aws_rds_cluster.main.endpoint
}

output "cluster_reader_endpoint" {
  description = "Endpoint de solo lectura del cluster"
  value       = aws_rds_cluster.main.reader_endpoint
}

output "database_name" {
  description = "Nombre de la base de datos"
  value       = aws_rds_cluster.main.database_name
}

output "master_user_secret_arn" {
  description = "ARN del secret en Secrets Manager (gestionado por RDS) con las credenciales — dar permiso de lectura a las Lambdas sobre este ARN"
  value       = aws_rds_cluster.main.master_user_secret[0].secret_arn
}

output "security_group_id" {
  description = "Security Group de Aurora"
  value       = aws_security_group.aurora.id
}

output "cluster_id" {
  description = "ID del cluster — útil para el script de migración de schema (CREATE EXTENSION vector, tablas)"
  value       = aws_rds_cluster.main.cluster_identifier
}
