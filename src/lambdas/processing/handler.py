"""
Lambda: processing
Trigger: evento S3 (subida individual, vía presigned URL)

Responsabilidad:
  1. Leer el evento S3, identificar bucket/key del documento subido.
  2. Determinar el `processing_path` (ocr | native) según la extensión.
  3. Actualizar `documents-metadata` con status=processing.
  4. Disparar el camino correspondiente:
     - native: extraer texto directo (PyPDF2/pdfplumber, python-docx, openpyxl)
     - ocr: iniciar Textract StartDocumentTextDetection (async)
  5. Registrar el evento en `audit-log`.

Estado actual: esqueleto funcional que resuelve el file_type y deja marcado
el TODO de cada rama. Sin lógica de Textract/Bedrock/Aurora todavía —
se completa en el próximo paso.
"""

import json
import logging
import os
from datetime import datetime, timezone
from urllib.parse import unquote_plus

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource("dynamodb")

DOCUMENTS_METADATA_TABLE = os.environ["DOCUMENTS_METADATA_TABLE"]
AUDIT_LOG_TABLE = os.environ["AUDIT_LOG_TABLE"]

OCR_EXTENSIONS = {"pdf", "png", "jpeg", "jpg", "tiff"}
NATIVE_EXTENSIONS = {"docx", "xlsx"}


def determine_processing_path(file_key: str) -> str:
    """
    pdf puede ir por cualquiera de los dos caminos según si es escaneado o
    nativo — acá solo se resuelve la extensión; la distinción real
    (texto seleccionable o no) se hace al abrir el archivo, en el paso
    de extracción nativa (TODO).
    """
    extension = file_key.rsplit(".", 1)[-1].lower()

    if extension in NATIVE_EXTENSIONS:
        return "native"
    if extension in OCR_EXTENSIONS:
        return "ocr"

    raise ValueError(f"Extensión no soportada: {extension}")


def update_document_status(document_id: str, file_type: str, processing_path: str, status: str) -> None:
    table = dynamodb.Table(DOCUMENTS_METADATA_TABLE)
    table.update_item(
        Key={"document_id": document_id},
        UpdateExpression="SET file_type = :ft, processing_path = :pp, #s = :st",
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues={
            ":ft": file_type,
            ":pp": processing_path,
            ":st": status,
        },
    )


def get_uploaded_by(document_id: str) -> str:
    table = dynamodb.Table(DOCUMENTS_METADATA_TABLE)
    response = table.get_item(Key={"document_id": document_id}, ProjectionExpression="uploaded_by")
    item = response.get("Item")
    return item["uploaded_by"] if item and "uploaded_by" in item else "unknown"


def write_audit_event(document_id: str, action: str, actor_id: str) -> None:
    table = dynamodb.Table(AUDIT_LOG_TABLE)
    now = datetime.now(timezone.utc)
    timestamp = now.isoformat()

    table.put_item(
        Item={
            "document_id": document_id,
            "sk": f"{timestamp}#{action}#{actor_id}",
            "actor_id": actor_id,
            "actor_role": "unknown",  # TODO: no tenemos el rol acá — requiere guardar cognito:groups
                                       # en documents-metadata al momento de la presigned URL, o resolverlo
                                       # consultando Cognito directamente. Pendiente de definir.
            "action": action,
            "timestamp": timestamp,
            "date": now.strftime("%Y-%m-%d"),
        }
    )


def extract_s3_records(event: dict) -> list:
    """
    Normaliza dos formas de evento posibles:
      - S3 directo: event["Records"][i]["s3"]
      - SQS (migración masiva): event["Records"][i]["body"] contiene el JSON
        del evento S3 original como string, con su propio "Records".
    """
    records = event.get("Records", [])

    if records and "body" in records[0]:
        s3_records = []
        for sqs_record in records:
            inner_event = json.loads(sqs_record["body"])
            s3_records.extend(inner_event.get("Records", []))
        return s3_records

    return records


def lambda_handler(event, context):
    logger.info("Evento recibido: %s", json.dumps(event))

    for record in extract_s3_records(event):
        bucket_name = record["s3"]["bucket"]["name"]
        object_key = unquote_plus(record["s3"]["object"]["key"])

        # document_id se asume igual al nombre del archivo en S3 (sin extensión)
        # — a definir con precisión cuando se arme la Lambda de presigned URL,
        # que es quien genera el document_id real al momento de la subida.
        document_id = object_key.rsplit("/", 1)[-1].rsplit(".", 1)[0]
        file_type = object_key.rsplit(".", 1)[-1].lower()

        logger.info("Procesando document_id=%s bucket=%s key=%s", document_id, bucket_name, object_key)

        processing_path = determine_processing_path(object_key)
        update_document_status(document_id, file_type, processing_path, status="processing")
        actor_id = get_uploaded_by(document_id)
        write_audit_event(document_id, action="upload", actor_id=actor_id)

        if processing_path == "native":
            # TODO: extraer texto con pdfplumber (PDF nativo) / python-docx / openpyxl
            # TODO: chunking del texto extraído
            # TODO: generar embeddings con Bedrock (Titan Embeddings V2)
            # TODO: escribir en document_chunks (Aurora/pgvector)
            # TODO: update_document_status(..., status="indexed")
            logger.info("Camino NATIVE — pendiente de implementar extracción directa")

        else:  # ocr
            # TODO: boto3 textract.start_document_text_detection(...)
            # TODO: la Lambda de callback (SNS) retoma el resultado cuando Textract termina
            logger.info("Camino OCR — pendiente de implementar StartDocumentTextDetection")

    return {"statusCode": 200, "body": json.dumps({"processed": len(extract_s3_records(event))})}
