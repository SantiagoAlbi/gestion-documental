output "state_bucket_name" {
  description = "Nombre del bucket S3 para remote state — usar en terraform/main.tf backend block"
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  description = "ARN del bucket S3 de state"
  value       = aws_s3_bucket.terraform_state.arn
}

output "aws_account_id" {
  description = "Account ID donde se creó el bucket"
  value       = data.aws_caller_identity.current.account_id
}
