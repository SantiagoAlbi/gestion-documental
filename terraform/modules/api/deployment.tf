resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  # Fuerza un redeploy cuando cambia cualquier método/integración/policy
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.documents.id,
      aws_api_gateway_method.documents_post.id,
      aws_api_gateway_integration.documents_post.id,
      aws_api_gateway_resource.query.id,
      aws_api_gateway_method.query_post.id,
      aws_api_gateway_integration.query_post.id,
      aws_api_gateway_rest_api_policy.main.policy,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.documents_post,
    aws_api_gateway_integration.query_post,
    aws_api_gateway_rest_api_policy.main,
  ]
}

resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.environment
}
