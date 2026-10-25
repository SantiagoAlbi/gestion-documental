"""
Lambda: processing
Trigger: evento S3 (subida individual vía presigned URL) o SQS (migración masiva)

Responsabilidad:
  1. Leer el evento (S3 directo o S3 envuelto en SQS) y obtener bucket/key.
  2. Validar la extensión: todo pasa por Textract (PDF nativo, PDF escaneado,
     PNG, JPEG, TIFF). DOCX/XLSX quedan fuera de la V1 (roadmap).
  3. Marcar el documento como `processing` en documents-metadata.
  4. Registrar el evento `upload` en audit-log.
  5. Iniciar Textract async (StartDocumentTextDetection) con JobTag=document_id.
     Cuando termina, Textract publica en SNS y la Lambda textract-callback
     continúa el pipeline (chunking, embeddings, Aurora).
"""

import json
import logging
import os
from datetime import datetime, timezone
from urllib.parse import unquote_plus
import uuid 

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource("dynamodb")
textract = boto3.client("textract")

DOCUMENTS_METADATA_TABLE = os.environ["DOCUMENTS_METADATA_TABLE"]
AUDIT_LOG_TABLE = os.environ["AUDIT_LOG_TABLE"]
TEXTRACT_SNS_TOPIC_ARN = os.environ["TEXTRACT_SNS_TOPIC_ARN"]
TEXTRACT_ROLE_ARN = os.environ["TEXTRACT_ROLE_ARN"]

# Formatos que Textract async acepta
SUPPORTED_EXTENSIONS = {"pdf", "png", "jpeg", "jpg", "tiff", "tif"}


def update_document(document_id: str, **fields) -> None:
    """Actualiza campos arbitrarios del documento en documents-metadata."""
    names = {f"#{k}": k for k in fields}
    values = {f":{k}": v for k, v in fields.items()}
    expression = "SET " + ", ".join(f"#{k} = :{k}" for k in fields)

    dynamodb.Table(DOCUMENTS_METADATA_TABLE).update_item(
        Key={"document_id": document_id},
        UpdateExpression=expression,
        ExpressionAttributeNames=names,
        ExpressionAttributeValues=values,
    )


def get_uploaded_by(document_id: str) -> str:
    response = dynamodb.Table(DOCUMENTS_METADATA_TABLE).get_item(
        Key={"document_id": document_id}, ProjectionExpression="uploaded_by"
    )
    item = response.get("Item")
    return item["uploaded_by"] if item and "uploaded_by" in item else "unknown"


def write_audit_event(document_id: str, action: str, actor_id: str) -> None:
    now = datetime.now(timezone.utc)
    timestamp = now.isoformat()

    dynamodb.Table(AUDIT_LOG_TABLE).put_item(
        Item={
            "document_id": document_id,
            "sk": f"{timestamp}#{action}#{actor_id}",
            "actor_id": actor_id,
            "actor_role": "unknown",  # TODO V2: guardar cognito:groups al emitir la presigned URL
            "action": action,
            "timestamp": timestamp,
            "date": now.strftime("%Y-%m-%d"),
        }
    )


def start_textract(bucket: str, key: str, document_id: str) -> str:
    """Inicia OCR async. Textract avisa por SNS al terminar; JobTag lleva el document_id."""
    response = textract.start_document_text_detection(
        DocumentLocation={"S3Object": {"Bucket": bucket, "Name": key}},
        JobTag=document_id,
        NotificationChannel={
            "SNSTopicArn": TEXTRACT_SNS_TOPIC_ARN,
            "RoleArn": TEXTRACT_ROLE_ARN,
        },
    )
    return response["JobId"]


def extract_s3_records(event: dict) -> list:
    """
    Normaliza dos formas de evento:
      - S3 directo: event["Records"][i]["s3"]
      - SQS (migración masiva): event["Records"][i]["body"] trae el evento S3 como string.
    """
    records = event.get("Records", [])

    if records and "body" in records[0]:
        s3_records = []
        for sqs_record in records:
            inner_event = json.loads(sqs_record["body"])
            s3_records.extend(inner_event.get("Records", []))
        return s3_records

    return records

def register_batch_document(key: str, file_type: str) -> str:
    """
    Migración masiva: el archivo no pasó por presigned-url, así que no tiene
    fila en documents-metadata. La carpeta define la categoría:
        batch-uploads/<categoría>/<archivo>
    El document_id se deriva de la key (uuid5): un reintento de SQS genera
    el mismo ID y no duplica el documento.
    """
    parts = key.split("/")
    document_id = str(uuid.uuid5(uuid.NAMESPACE_URL, key))
    category = parts[1] if len(parts) >= 3 else None

    item = {
        "document_id": document_id,
        "title": parts[-1],
        "s3_key": key,
        "file_type": file_type,
        "uploaded_by": "migration",
        "uploaded_at": datetime.now(timezone.utc).isoformat(),
        "status": "pending",
    }
    if category:
        item["category"] = category

    table = dynamodb.Table(DOCUMENTS_METADATA_TABLE)
    try:
        table.put_item(Item=item, ConditionExpression="attribute_not_exists(document_id)")
    except table.meta.client.exceptions.ConditionalCheckFailedException:
        pass  # ya registrado por un intento anterior

    if not category:
        raise ValueError(f"Migración sin carpeta de categoría: {key}")
    return document_id

def process_record(record: dict) -> None:
    bucket = record["s3"]["bucket"]["name"]
    key = unquote_plus(record["s3"]["object"]["key"])

    # La key termina en <document_id>.<extensión> (la genera presigned-url)
    #document_id = key.rsplit("/", 1)[-1].rsplit(".", 1)[0]
    file_type = key.rsplit(".", 1)[-1].lower()
    
    if key.startswith("batch-uploads/"):                            #new mod
        document_id = register_batch_document(key, file_type)
    else:
        document_id = key.rsplit("/", 1)[-1].rsplit(".", 1)[0]    
   

    logger.info("Procesando document_id=%s key=%s", document_id, key)

    if file_type not in SUPPORTED_EXTENSIONS:
        # No se reintenta: un formato no soportado no se arregla solo
        logger.warning("Formato no soportado: %s (document_id=%s)", file_type, document_id)
        update_document(document_id, file_type=file_type, status="error",
                        error_reason=f"Formato no soportado en V1: {file_type}")
        return

    update_document(document_id, file_type=file_type, processing_path="ocr", status="processing")
    write_audit_event(document_id, action="upload", actor_id=get_uploaded_by(document_id))

    try:
        job_id = start_textract(bucket, key, document_id)
    except Exception as exc:
        update_document(document_id, status="error", error_reason=f"Textract: {exc}")
        raise  # S3 reintenta / SQS devuelve el mensaje y termina en la DLQ

    update_document(document_id, textract_job_id=job_id)
    logger.info("Textract iniciado: job_id=%s document_id=%s", job_id, document_id)


def lambda_handler(event, context):
    logger.info("Evento recibido: %s", json.dumps(event))

    records = extract_s3_records(event)
    for record in records:
        process_record(record)

    return {"statusCode": 200, "body": json.dumps({"processed": len(records)})}
