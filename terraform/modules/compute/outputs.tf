output "presigned_lambda_arn" {
  description = "ARN de la Lambda de presigned URL — usar en la integración de API Gateway"
  value       = aws_lambda_function.presigned.arn
}

output "presigned_lambda_invoke_arn" {
  description = "Invoke ARN de la Lambda de presigned URL — formato que pide aws_apigatewayv2_integration"
  value       = aws_lambda_function.presigned.invoke_arn
}

output "presigned_lambda_function_name" {
  value = aws_lambda_function.presigned.function_name
}

output "query_lambda_arn" {
  description = "ARN de la Lambda de consulta — usar en la integración de API Gateway"
  value       = aws_lambda_function.query.arn
}

output "query_lambda_invoke_arn" {
  value = aws_lambda_function.query.invoke_arn
}

output "query_lambda_function_name" {
  value = aws_lambda_function.query.function_name
}

output "processing_lambda_function_name" {
  description = "Para alarms de CloudWatch (módulo monitoring)"
  value       = aws_lambda_function.processing.function_name
}

output "migration_consumer_function_name" {
  value = aws_lambda_function.migration_consumer.function_name
}

output "textract_callback_function_name" {
  value = aws_lambda_function.textract_callback.function_name
}

output "lights_off_function_name" {
  value = aws_lambda_function.lights_off.function_name
}
