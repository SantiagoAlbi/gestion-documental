terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# --- Errores en cualquier Lambda del proyecto ---

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = toset(var.lambda_function_names)

  alarm_name          = "${var.project_name}-${each.value}-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Error en la Lambda ${each.value}"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = each.value
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

# --- Mensajes acumulados en la DLQ de migración — indica fallos persistentes ---

resource "aws_cloudwatch_metric_alarm" "migration_dlq_messages" {
  alarm_name          = "${var.project_name}-migration-dlq-messages-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "Hay mensajes en la DLQ de migración — algo está fallando repetidamente en el procesamiento"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = var.migration_dlq_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

# --- 5xx en el API Gateway ---

resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "${var.project_name}-api-5xx-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "El API Gateway está devolviendo errores 5xx"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiName = var.api_gateway_name
    Stage   = var.api_gateway_stage
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

# --- Aurora cerca del máximo de ACU configurado — señal para subir max_capacity ---

resource "aws_cloudwatch_metric_alarm" "aurora_acu_high" {
  alarm_name          = "${var.project_name}-aurora-acu-high-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "ServerlessDatabaseCapacity"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 3.5 # ~87% del max_capacity default (4) — ajustar si cambia
  alarm_description   = "Aurora Serverless v2 cerca del ACU máximo configurado — considerar subir max_capacity"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBClusterIdentifier = var.aurora_cluster_id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}
