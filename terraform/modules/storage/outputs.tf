output "bucket_id" {
  description = "Nombre del bucket — usar en la notificación S3 -> Lambda (definida en el módulo compute)"
  value       = aws_s3_bucket.documents.id
}

output "bucket_arn" {
  description = "ARN del bucket — para IAM policies de las Lambdas (presigned URL, procesamiento)"
  value       = aws_s3_bucket.documents.arn
}

output "bucket_regional_domain_name" {
  description = "Domain name regional del bucket"
  value       = aws_s3_bucket.documents.bucket_regional_domain_name
}
