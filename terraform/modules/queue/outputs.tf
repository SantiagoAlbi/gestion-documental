output "queue_arn" {
  description = "ARN de la cola de migración — usar en la notificación S3 (módulo compute) y como event source de la Lambda consumidora"
  value       = aws_sqs_queue.migration.arn
}

output "queue_url" {
  description = "URL de la cola de migración"
  value       = aws_sqs_queue.migration.id
}

output "dlq_arn" {
  description = "ARN de la Dead Letter Queue — para alarmas de CloudWatch (módulo monitoring)"
  value       = aws_sqs_queue.migration_dlq.arn
}

output "dlq_name" {
  description = "Nombre plano de la DLQ — dimension QueueName que pide aws_cloudwatch_metric_alarm"
  value       = aws_sqs_queue.migration_dlq.name
}

output "dlq_url" {
  description = "URL de la Dead Letter Queue"
  value       = aws_sqs_queue.migration_dlq.id
}
