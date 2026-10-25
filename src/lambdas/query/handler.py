"""
Lambda: query
Trigger: API Gateway REST API (POST /query) con Cognito User Pool Authorizer

Responsabilidad (Módulo 1 y 2) — patrón RAG con RBAC:
  1. Leer la pregunta del body y el grupo de Cognito del JWT.
  2. Guardrail capa 1 (regex): bloquear consultas de compensación individual
     antes de gastar en Bedrock.
  3. RBAC: categorías permitidas para el rol (tabla rbac-permissions).
  4. Embedding de la pregunta (Titan Embeddings V2).
  5. Búsqueda en pgvector filtrada por categoría DENTRO de la misma query
     (filtrar después podría llenar el top-K con chunks prohibidos).
  6. Claude (inference profile) vía Converse API con Bedrock Guardrails
     aplicado = capa 2.
  7. Registrar la consulta en audit-log (action=query).
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
bedrock = boto3.client("bedrock-runtime")
rds_data = boto3.client("rds-data")

RBAC_PERMISSIONS_TABLE = os.environ["RBAC_PERMISSIONS_TABLE"]
AUDIT_LOG_TABLE = os.environ["AUDIT_LOG_TABLE"]
AURORA_CLUSTER_ARN = os.environ["AURORA_CLUSTER_ARN"]
AURORA_DATABASE = os.environ["AURORA_DATABASE"]
AURORA_SECRET_ARN = os.environ["AURORA_SECRET_ARN"]
BEDROCK_TEXT_MODEL_ID = os.environ["BEDROCK_TEXT_MODEL_ID"]
GUARDRAIL_ID = os.environ["GUARDRAIL_ID"]
GUARDRAIL_VERSION = os.environ["GUARDRAIL_VERSION"]

EMBEDDING_MODEL_ID = "amazon.titan-embed-text-v2:0"
TOP_K = 5  # chunks que se le pasan a Claude como contexto

# Guardrail capa 1. Heurística simple a propósito: la capa 2 (Bedrock
# Guardrails) es la red de contención para lo que esto no capture.
COMPENSATION_PATTERN = re.compile(r"(salario|sueldo|remuneraci[oó]n)", re.IGNORECASE)

BLOCKED_COMPENSATION = ("No puedo compartir montos individuales de compensación. "
                        "Puedo indicarte la banda salarial estimada del puesto si lo necesitás.")
BLOCKED_GUARDRAIL = "No puedo responder esa consulta por las políticas de uso del sistema."
NO_CONTEXT = "No encontré información sobre eso en los documentos a los que tenés acceso."

SYSTEM_PROMPT = (
    "Sos un asistente interno de un ente gubernamental. Respondé en español, "
    "de forma breve y precisa, usando SOLO la información de los fragmentos de "
    "documentos provistos. Si la respuesta no está en los fragmentos, decilo. "
    "No inventes datos ni cites información externa."
)


def _response(status_code: int, body: dict):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"},
        "body": json.dumps(body, ensure_ascii=False),
    }


# --- Identidad -------------------------------------------------------------

def get_claims(event: dict) -> dict:
    """REST API: authorizer.claims · HTTP API: authorizer.jwt.claims."""
    authorizer = event.get("requestContext", {}).get("authorizer", {}) or {}
    return authorizer.get("claims") or authorizer.get("jwt", {}).get("claims") or {}


def get_role(claims: dict):
    """cognito:groups puede llegar como 'a,b', '[a b]' o lista. Toma el primero."""
    groups = claims.get("cognito:groups", "")
    if isinstance(groups, list):
        names = groups
    else:
        names = [g for g in re.split(r"[,\s]+", groups.strip("[]")) if g]
    return names[0] if names else None


# --- DynamoDB --------------------------------------------------------------

def get_allowed_categories(role: str) -> list:
    item = dynamodb.Table(RBAC_PERMISSIONS_TABLE).get_item(Key={"role": role}).get("Item")
    return list(item["allowed_categories"]) if item else []


def write_audit_event(actor_id: str, actor_role: str, outcome: str) -> None:
    now = datetime.now(timezone.utc)
    timestamp = now.isoformat()

    dynamodb.Table(AUDIT_LOG_TABLE).put_item(
        Item={
            "document_id": "N/A",  # una consulta no apunta a un documento puntual
            "sk": f"{timestamp}#query#{actor_id}",
            "actor_id": actor_id,
            "actor_role": actor_role,
            "action": "query",
            "outcome": outcome,  # answered | no_context | blocked_regex | blocked_guardrail
            "timestamp": timestamp,
            "date": now.strftime("%Y-%m-%d"),
        }
    )


# --- RAG -------------------------------------------------------------------

def embed(text: str) -> list:
    response = bedrock.invoke_model(
        modelId=EMBEDDING_MODEL_ID,
        body=json.dumps({"inputText": text, "dimensions": 1024, "normalize": True}),
    )
    return json.loads(response["body"].read())["embedding"]


def search_chunks(question_vector: list, categories: list) -> list:
    """Similitud coseno + filtro RBAC en la misma query."""
    vector = "[" + ",".join(str(x) for x in question_vector) + "]"
    # La Data API no acepta arrays como parámetro: se pasa como literal de array
    # de Postgres. Las categorías vienen de nuestra tabla RBAC, no del usuario.
    categories_literal = "{" + ",".join(categories) + "}"

    response = rds_data.execute_statement(
        resourceArn=AURORA_CLUSTER_ARN,
        secretArn=AURORA_SECRET_ARN,
        database=AURORA_DATABASE,
        sql=(
            "SELECT document_id, category, chunk_text, "
            "1 - (embedding <=> CAST(:emb AS vector)) AS score "
            "FROM document_chunks "
            "WHERE category = ANY(CAST(:cats AS text[])) "
            "ORDER BY embedding <=> CAST(:emb AS vector) "
            f"LIMIT {TOP_K}"
        ),
        parameters=[
            {"name": "emb", "value": {"stringValue": vector}},
            {"name": "cats", "value": {"stringValue": categories_literal}},
        ],
    )

    return [
        {
            "document_id": r[0]["stringValue"],
            "category": r[1]["stringValue"],
            "text": r[2]["stringValue"],
            "score": round(r[3]["doubleValue"], 3),
        }
        for r in response.get("records", [])
    ]


def ask_claude(question: str, chunks: list):
    """Devuelve (respuesta, bloqueado_por_guardrail)."""
    context = "\n\n".join(f"[Fragmento {i + 1}]\n{c['text']}" for i, c in enumerate(chunks))

    response = bedrock.converse(
        modelId=BEDROCK_TEXT_MODEL_ID,
        system=[{"text": SYSTEM_PROMPT}],
        messages=[{
            "role": "user",
            "content": [{"text": f"Fragmentos de documentos:\n\n{context}\n\nPregunta: {question}"}],
        }],
        inferenceConfig={"maxTokens": 800, "temperature": 0.2},
        guardrailConfig={
            "guardrailIdentifier": GUARDRAIL_ID,
            "guardrailVersion": GUARDRAIL_VERSION,
        },
    )

    if response.get("stopReason") == "guardrail_intervened":
        return BLOCKED_GUARDRAIL, True

    answer = "".join(part.get("text", "") for part in response["output"]["message"]["content"])
    return answer, False


# --- Handler ---------------------------------------------------------------

def lambda_handler(event, context):
    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _response(400, {"error": "Body inválido, se esperaba JSON"})

    question = (body.get("question") or "").strip()
    if not question:
        return _response(400, {"error": "Falta el campo 'question'"})

    claims = get_claims(event)
    actor_id = claims.get("sub")
    if not actor_id:
        return _response(401, {"error": "No autenticado"})

    role = get_role(claims)
    if not role:
        return _response(403, {"error": "Usuario sin rol asignado"})

    # Capa 1: regex, sin costo de Bedrock
    if COMPENSATION_PATTERN.search(question):
        logger.warning("Guardrail regex activado actor_id=%s", actor_id)
        write_audit_event(actor_id, role, "blocked_regex")
        return _response(200, {"answer": BLOCKED_COMPENSATION, "blocked": True})

    allowed_categories = get_allowed_categories(role)
    if not allowed_categories:
        return _response(403, {"error": "El rol no tiene categorías asignadas"})

    chunks = search_chunks(embed(question), allowed_categories)
    if not chunks:
        write_audit_event(actor_id, role, "no_context")
        return _response(200, {"answer": NO_CONTEXT, "sources": []})

    # Capa 2: Bedrock Guardrails dentro de la llamada a Claude
    answer, blocked = ask_claude(question, chunks)
    write_audit_event(actor_id, role, "blocked_guardrail" if blocked else "answered")

    sources = sorted({(c["document_id"], c["category"]) for c in chunks})
    return _response(200, {
        "answer": answer,
        "blocked": blocked,
        "sources": [{"document_id": d, "category": c} for d, c in sources],
    })
