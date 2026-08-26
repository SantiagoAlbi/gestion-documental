output "rest_api_id" {
  value = aws_api_gateway_rest_api.main.id
}

output "rest_api_name" {
  description = "Nombre plano del API — dimension ApiName que pide aws_cloudwatch_metric_alarm"
  value       = aws_api_gateway_rest_api.main.name
}

output "invoke_url" {
  description = "URL pública del API (accesible solo desde IPs de oficina o vía el VPC Endpoint, por la resource policy)"
  value       = aws_api_gateway_stage.main.invoke_url
}

output "execution_arn" {
  value = aws_api_gateway_rest_api.main.execution_arn
}
