resource "aws_iam_role" "lights_off" {
  name = "${var.project_name}-lights-off-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lights_off_basic_logs" {
  role       = aws_iam_role.lights_off.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lights_off_permissions" {
  name = "${var.project_name}-lights-off-permissions-${var.environment}"
  role = aws_iam_role.lights_off.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:AssociateClientVpnTargetNetwork",
        "ec2:DisassociateClientVpnTargetNetwork",
        "ec2:DescribeClientVpnTargetNetworks",
        "ec2:DescribeClientVpnEndpoints"
      ]
      # Estas acciones de Client VPN no soportan scoping por ARN de recurso
      # específico en IAM — Resource "*" es lo que exige la API de EC2 acá.
      Resource = "*"
    }]
  })
}

data "archive_file" "lights_off" {
  type        = "zip"
  source_dir  = "${var.lambda_source_dir}/lights-off"
  output_path = "${path.module}/.build/lights-off.zip"
}

resource "aws_lambda_function" "lights_off" {
  function_name = "${var.project_name}-lights-off-${var.environment}"
  role          = aws_iam_role.lights_off.arn
  handler       = "handler.lambda_handler"
  runtime       = var.lambda_runtime
  timeout       = 30
  memory_size   = 128

  filename         = data.archive_file.lights_off.output_path
  source_code_hash = data.archive_file.lights_off.output_base64sha256

  # Sin vpc_config — solo llama a la API de EC2, no necesita estar en la VPC.

  environment {
    variables = {
      CLIENT_VPN_ENDPOINT_ID = var.client_vpn_endpoint_id
      SUBNET_IDS              = join(",", var.vpn_private_subnet_ids)
    }
  }

  tags = {
    Name = "${var.project_name}-lights-off-${var.environment}"
  }
}

resource "aws_cloudwatch_log_group" "lights_off" {
  name              = "/aws/lambda/${aws_lambda_function.lights_off.function_name}"
  retention_in_days = 30
}

# ---------------------------------------------------------------------------
# EventBridge Scheduler — dos schedules, uno por acción, con el input
# indicando qué acción tomar. Más simple que una sola Lambda "adivinando"
# la hora actual.
# ---------------------------------------------------------------------------

resource "aws_scheduler_schedule_group" "lights_off" {
  name = "${var.project_name}-lights-off-${var.environment}"
}

resource "aws_iam_role" "scheduler_invoke_lights_off" {
  name = "${var.project_name}-scheduler-lights-off-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "scheduler_invoke_lights_off" {
  name = "${var.project_name}-scheduler-invoke-lights-off-${var.environment}"
  role = aws_iam_role.scheduler_invoke_lights_off.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = aws_lambda_function.lights_off.arn
    }]
  })
}

resource "aws_scheduler_schedule" "vpn_associate" {
  name       = "${var.project_name}-vpn-associate-${var.environment}"
  group_name = aws_scheduler_schedule_group.lights_off.name

  schedule_expression          = var.lights_off_associate_cron
  schedule_expression_timezone = var.lights_off_timezone

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.lights_off.arn
    role_arn = aws_iam_role.scheduler_invoke_lights_off.arn
    input    = jsonencode({ action = "associate" })
  }
}

resource "aws_scheduler_schedule" "vpn_disassociate" {
  name       = "${var.project_name}-vpn-disassociate-${var.environment}"
  group_name = aws_scheduler_schedule_group.lights_off.name

  schedule_expression          = var.lights_off_disassociate_cron
  schedule_expression_timezone = var.lights_off_timezone

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.lights_off.arn
    role_arn = aws_iam_role.scheduler_invoke_lights_off.arn
    input    = jsonencode({ action = "disassociate" })
  }
}
