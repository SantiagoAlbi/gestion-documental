"""
Lambda: textract-callback
Trigger: SNS (Textract publica acá cuando termina un StartDocumentTextDetection)

Responsabilidad:
  1. Leer el mensaje SNS (JobId, DocumentLocation, Status).
  2. Si Status == SUCCEEDED: traer el texto con GetDocumentTextDetection
     (paginado si el doc es largo).
  3. Chunking del texto.
  4. Generar embeddings (Bedrock Titan Embeddings V2).
  5. Escribir en document_chunks (Aurora/pgvector).
  6. Actualizar documents-metadata: status=indexed.
  7. Si Status == FAILED: status=error + audit event.

Estado actual: esqueleto que parsea el mensaje SNS y deja los TODOs de la
lógica de negocio (Textract paginado, chunking, embeddings, escritura Aurora).
"""

import json
import logging
import os

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource("dynamodb")
textract_client = boto3.client("textract")

DOCUMENTS_METADATA_TABLE = os.environ["DOCUMENTS_METADATA_TABLE"]
AUDIT_LOG_TABLE = os.environ["AUDIT_LOG_TABLE"]


def update_status(document_id: str, status: str) -> None:
    table = dynamodb.Table(DOCUMENTS_METADATA_TABLE)
    table.update_item(
        Key={"document_id": document_id},
        UpdateExpression="SET #s = :st",
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues={":st": status},
    )


def lambda_handler(event, context):
    logger.info("Evento SNS recibido: %s", json.dumps(event))

    for record in event.get("Records", []):
        message = json.loads(record["Sns"]["Message"])

        job_id = message.get("JobId")
        status = message.get("Status")
        # JobTag se setea al llamar StartDocumentTextDetection — se usa
        # document_id como JobTag para poder correlacionar acá (TODO: setearlo
        # en processing/handler.py cuando se implemente el StartDocumentTextDetection real).
        document_id = message.get("JobTag")

        logger.info("Textract job_id=%s status=%s document_id=%s", job_id, status, document_id)

        if status != "SUCCEEDED":
            update_status(document_id, status="error")
            continue

        # TODO: textract_client.get_document_text_detection(JobId=job_id), paginar con NextToken
        # TODO: unir el texto de todos los bloques tipo LINE
        # TODO: chunking
        # TODO: generar embeddings con Bedrock (Titan Embeddings V2)
        # TODO: conectar a Aurora (usando AURORA_SECRET_ARN) e insertar en document_chunks
        update_status(document_id, status="indexed")

    return {"statusCode": 200}
