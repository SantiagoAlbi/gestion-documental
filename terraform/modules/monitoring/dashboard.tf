resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Lambda — Invocations & Errors"
          view   = "timeSeries"
          region = "us-east-1"
          metrics = flatten([
            for fn in var.lambda_function_names : [
              ["AWS/Lambda", "Invocations", "FunctionName", fn],
              ["AWS/Lambda", "Errors", "FunctionName", fn]
            ]
          ])
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "API Gateway — Requests & 5xx"
          view   = "timeSeries"
          region = "us-east-1"
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", var.api_gateway_name, "Stage", var.api_gateway_stage],
            ["AWS/ApiGateway", "5XXError", "ApiName", var.api_gateway_name, "Stage", var.api_gateway_stage]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "SQS — Cola de migración"
          view   = "timeSeries"
          region = "us-east-1"
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", var.migration_dlq_name]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Aurora — Capacidad Serverless (ACU)"
          view   = "timeSeries"
          region = "us-east-1"
          metrics = [
            ["AWS/RDS", "ServerlessDatabaseCapacity", "DBClusterIdentifier", var.aurora_cluster_id]
          ]
        }
      }
    ]
  })
}
