"""
Lambda: query
Trigger: API Gateway (HTTP API, ruta POST /query, con Cognito JWT Authorizer)

Responsabilidad (Módulo 1 y 2):
  1. Leer la pregunta del body + el/los grupo(s) de Cognito del JWT.
  2. Guardrail determinístico: detectar combinaciones tipo nombre+salario/sueldo
     antes de tocar Bedrock (capa 1 del guardrail de doble capa).
  3. Consultar rbac-permissions: qué categorías puede ver este rol.
  4. Generar embedding de la pregunta (Bedrock Titan Embeddings V2).
  5. Query a Aurora/pgvector: similitud vectorial + WHERE category = ANY(allowed_categories).
  6. Armar el contexto con los chunks resultantes, invocar Bedrock (con Guardrails)
     para la respuesta final.
  7. Registrar el evento en audit-log (action=query).

Estado actual: esqueleto que resuelve el RBAC lookup y el guardrail
determinístico básico. TODOs marcados para embedding/pgvector/Bedrock.
"""

import json
import logging
import os
import re
from datetime import datetime, timezone

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource("dynamodb")

RBAC_PERMISSIONS_TABLE = os.environ["RBAC_PERMISSIONS_TABLE"]
AUDIT_LOG_TABLE = os.environ["AUDIT_LOG_TABLE"]

# Guardrail determinístico — capa 1. Detecta combinaciones nombre+salario/sueldo.
# Heurística simple a propósito: la capa 2 (Bedrock Guardrails) es la red de
# contención real para casos que esto no capture.
COMPENSATION_PATTERN = re.compile(r"(salario|sueldo|remuneraci[oó]n)", re.IGNORECASE)


def _response(status_code: int, body: dict):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


def get_allowed_categories(role: str) -> list:
    table = dynamodb.Table(RBAC_PERMISSIONS_TABLE)
    response = table.get_item(Key={"role": role})
    item = response.get("Item")
    return list(item["allowed_categories"]) if item else []


def write_audit_event(actor_id: str, actor_role: str) -> None:
    table = dynamodb.Table(AUDIT_LOG_TABLE)
    now = datetime.now(timezone.utc)
    timestamp = now.isoformat()

    table.put_item(
        Item={
            "document_id": "N/A",  # una consulta no apunta a un documento puntual
            "sk": f"{timestamp}#query#{actor_id}",
            "actor_id": actor_id,
            "actor_role": actor_role,
            "action": "query",
            "timestamp": timestamp,
            "date": now.strftime("%Y-%m-%d"),
        }
    )


def lambda_handler(event, context):
    logger.info("Evento recibido: %s", json.dumps(event))

    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _response(400, {"error": "Body inválido, se esperaba JSON"})

    question = body.get("question")
    if not question:
        return _response(400, {"error": "Falta el campo 'question'"})

    try:
        claims = event["requestContext"]["authorizer"]["jwt"]["claims"]
        actor_id = claims["sub"]
        groups = claims.get("cognito:groups", "")
        role = groups.split(",")[0] if groups else None
    except KeyError:
        return _response(401, {"error": "No autenticado"})

    if not role:
        return _response(403, {"error": "Usuario sin rol asignado"})

    if COMPENSATION_PATTERN.search(question):
        logger.warning("Guardrail determinístico activado para actor_id=%s", actor_id)
        write_audit_event(actor_id, role)
        return _response(
            200,
            {"answer": "No puedo compartir montos individuales de compensación. Puedo indicarte la banda salarial estimada del puesto si lo necesitás."},
        )

    allowed_categories = get_allowed_categories(role)
    if not allowed_categories:
        return _response(403, {"error": "El rol no tiene categorías asignadas"})

    # TODO: generar embedding de `question` con Bedrock (Titan Embeddings V2)
    # TODO: conectar a Aurora (AURORA_SECRET_ARN) y hacer la query de pgvector
    #       con WHERE category = ANY(allowed_categories)
    # TODO: armar el contexto con los chunks resultantes
    # TODO: invocar BEDROCK_TEXT_MODEL_ID con Guardrails aplicado, generar la respuesta

    write_audit_event(actor_id, role)

    return _response(
        200,
        {"answer": "TODO: respuesta generada por Bedrock, pendiente de implementar", "allowed_categories": allowed_categories},
    )
