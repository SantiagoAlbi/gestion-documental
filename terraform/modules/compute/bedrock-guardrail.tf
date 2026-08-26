resource "aws_bedrock_guardrail" "main" {
  name                      = "${var.project_name}-guardrail-${var.environment}"
  blocked_input_messaging   = "No puedo procesar esa consulta."
  blocked_outputs_messaging = "No puedo compartir esa información por políticas de privacidad."

  # Capa 2 de defensa — la capa 1 es el patrón determinístico en query/handler.py.
  # Esta capa cubre lo que el regex no detecta: paráfrasis, otros idiomas,
  # preguntas indirectas sobre compensación individual.
  sensitive_information_policy_config {
    pii_entities_config {
      type   = "US_SOCIAL_SECURITY_NUMBER"
      action = "BLOCK"
    }
    pii_entities_config {
      type   = "US_BANK_ACCOUNT_NUMBER"
      action = "BLOCK"
    }
    pii_entities_config {
      type   = "CREDIT_DEBIT_CARD_NUMBER"
      action = "BLOCK"
    }
  }

  topic_policy_config {
    topics_config {
      name       = "CompensacionIndividual"
      type       = "DENY"
      definition = "Preguntas sobre el salario, sueldo o remuneración específica de un empleado individual identificado por nombre."
      examples = [
        "¿Cuánto gana Juan Pérez?",
        "¿Cuál es el sueldo de la jefa de RRHH?",
      ]
    }
  }

  content_policy_config {
    filters_config {
      type            = "SEXUAL"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "VIOLENCE"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "HATE"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "INSULTS"
      input_strength  = "MEDIUM"
      output_strength = "MEDIUM"
    }
    filters_config {
      type            = "MISCONDUCT"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
  }

  tags = {
    Name = "${var.project_name}-guardrail-${var.environment}"
  }
}

resource "aws_bedrock_guardrail_version" "main" {
  guardrail_arn = aws_bedrock_guardrail.main.guardrail_arn
  description   = "Versión publicada — el alias 'production' apunta acá"
}
