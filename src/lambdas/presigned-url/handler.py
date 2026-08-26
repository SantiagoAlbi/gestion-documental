"""
Lambda: presigned-url
Trigger: API Gateway (HTTP API, ruta POST /documents, con Cognito JWT Authorizer)

Responsabilidad:
  1. Leer el body del request: category, file_type, title.
  2. Leer el usuario autenticado desde el JWT que ya validó API Gateway
     (sub, cognito:groups) — llega en requestContext.authorizer.jwt.claims.
  3. Generar document_id (UUID) y armar la key de S3.
  4. Crear el registro inicial en documents-metadata (status=pending_upload,
     uploaded_by=sub real, no "system" — cierra el gap de auditoría que
     tenía la Lambda de processing).
  5. Generar la presigned URL de PUT y devolverla junto con el document_id.

El evento S3 disparado por esta subida lo procesa la Lambda `processing`
(status pending_upload -> processing -> indexed).
"""

import json
import logging
import os
import uuid
from datetime import datetime, timezone

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3_client = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")

DOCUMENTS_BUCKET = os.environ["DOCUMENTS_BUCKET"]
DOCUMENTS_METADATA_TABLE = os.environ["DOCUMENTS_METADATA_TABLE"]
URL_EXPIRATION_SECONDS = int(os.environ["URL_EXPIRATION_SECONDS"])

ALLOWED_EXTENSIONS = {"pdf", "png", "jpeg", "jpg", "tiff", "docx", "xlsx"}


def _response(status_code: int, body: dict):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


def lambda_handler(event, context):
    logger.info("Evento recibido: %s", json.dumps(event))

    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _response(400, {"error": "Body inválido, se esperaba JSON"})

    category = body.get("category")
    title = body.get("title")
    file_type = (body.get("file_type") or "").lower().lstrip(".")
    department = body.get("department")

    if not category or not title or not file_type:
        return _response(400, {"error": "Faltan campos: category, title, file_type son requeridos"})

    if file_type not in ALLOWED_EXTENSIONS:
        return _response(400, {"error": f"file_type no soportado: {file_type}"})

    # Claims del JWT ya validado por el Cognito Authorizer de API Gateway
    try:
        claims = event["requestContext"]["authorizer"]["jwt"]["claims"]
        uploaded_by = claims["sub"]
    except KeyError:
        logger.error("No se encontraron claims de Cognito en el request")
        return _response(401, {"error": "No autenticado"})

    document_id = str(uuid.uuid4())
    object_key = f"uploads/{document_id}.{file_type}"
    uploaded_at = datetime.now(timezone.utc).isoformat()

    # Registro inicial — la Lambda `processing` lo actualiza después
    # (file_type, processing_path, status) cuando el evento S3 la dispare.
    table = dynamodb.Table(DOCUMENTS_METADATA_TABLE)
    table.put_item(
        Item={
            "document_id": document_id,
            "category": category,
            "title": title,
            "department": department or "sin-asignar",
            "s3_key": object_key,
            "uploaded_by": uploaded_by,
            "uploaded_at": uploaded_at,
            "status": "pending_upload",
        }
    )

    presigned_url = s3_client.generate_presigned_url(
        ClientMethod="put_object",
        Params={"Bucket": DOCUMENTS_BUCKET, "Key": object_key},
        ExpiresIn=URL_EXPIRATION_SECONDS,
    )

    return _response(
        200,
        {
            "document_id": document_id,
            "upload_url": presigned_url,
            "expires_in": URL_EXPIRATION_SECONDS,
        },
    )
