"""
Lambda: textract-callback
Trigger: SNS (Textract publica al terminar un job de StartDocumentTextDetection)

Responsabilidad:
  1. Leer el mensaje SNS: JobId, Status y JobTag (= document_id).
  2. Si falló: marcar el documento como `error`.
  3. Si terminó bien:
     a. Traer el texto de Textract (paginado) y unir las líneas.
     b. Cortarlo en chunks con solapamiento.
     c. Generar un embedding por chunk con Titan Embeddings V2 (1024 dim).
     d. Guardar en Aurora (document_chunks) vía RDS Data API, con la
        categoría del documento para el filtro RBAC.
     e. Marcar el documento como `indexed`.

Idempotente: borra los chunks previos del documento antes de insertar,
por si SNS entrega el mismo mensaje dos veces.
"""

import json
import logging
import os

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource("dynamodb")
textract = boto3.client("textract")
bedrock = boto3.client("bedrock-runtime")
rds_data = boto3.client("rds-data")

DOCUMENTS_METADATA_TABLE = os.environ["DOCUMENTS_METADATA_TABLE"]
AURORA_CLUSTER_ARN = os.environ["AURORA_CLUSTER_ARN"]
AURORA_DATABASE = os.environ["AURORA_DATABASE"]
AURORA_SECRET_ARN = os.environ["AURORA_SECRET_ARN"]

EMBEDDING_MODEL_ID = "amazon.titan-embed-text-v2:0"
EMBEDDING_DIMENSIONS = 1024

CHUNK_SIZE = 1500      # caracteres por chunk
CHUNK_OVERLAP = 200    # caracteres compartidos entre chunks consecutivos
INSERT_BATCH_SIZE = 20 # filas por llamada a la Data API


# --- DynamoDB --------------------------------------------------------------

def get_document(document_id: str) -> dict:
    response = dynamodb.Table(DOCUMENTS_METADATA_TABLE).get_item(Key={"document_id": document_id})
    return response.get("Item", {})


def update_document(document_id: str, **fields) -> None:
    names = {f"#{k}": k for k in fields}
    values = {f":{k}": v for k, v in fields.items()}
    expression = "SET " + ", ".join(f"#{k} = :{k}" for k in fields)

    dynamodb.Table(DOCUMENTS_METADATA_TABLE).update_item(
        Key={"document_id": document_id},
        UpdateExpression=expression,
        ExpressionAttributeNames=names,
        ExpressionAttributeValues=values,
    )


# --- Textract --------------------------------------------------------------

def get_text(job_id: str) -> str:
    """Trae todas las páginas del resultado y une los bloques LINE."""
    lines = []
    kwargs = {"JobId": job_id}

    while True:
        response = textract.get_document_text_detection(**kwargs)
        lines.extend(b["Text"] for b in response["Blocks"] if b["BlockType"] == "LINE")
        next_token = response.get("NextToken")
        if not next_token:
            break
        kwargs["NextToken"] = next_token

    return "\n".join(lines)


# --- Chunking --------------------------------------------------------------

def chunk_text(text: str) -> list:
    """Corta en bloques de ~CHUNK_SIZE caracteres sin partir palabras, con solapamiento."""
    chunks = []
    start = 0

    while start < len(text):
        end = min(start + CHUNK_SIZE, len(text))
        if end < len(text):
            last_space = text.rfind(" ", start, end)
            if last_space > start:
                end = last_space
        chunk = text[start:end].strip()
        if chunk:
            chunks.append(chunk)
        if end >= len(text):
            break
        start = max(end - CHUNK_OVERLAP, start + 1)

    return chunks


# --- Bedrock ---------------------------------------------------------------

def embed(text: str) -> list:
    response = bedrock.invoke_model(
        modelId=EMBEDDING_MODEL_ID,
        body=json.dumps({"inputText": text, "dimensions": EMBEDDING_DIMENSIONS, "normalize": True}),
    )
    return json.loads(response["body"].read())["embedding"]


# --- Aurora (RDS Data API) -------------------------------------------------

def sql(statement: str, parameters: list = None) -> None:
    rds_data.execute_statement(
        resourceArn=AURORA_CLUSTER_ARN,
        secretArn=AURORA_SECRET_ARN,
        database=AURORA_DATABASE,
        sql=statement,
        parameters=parameters or [],
    )


def save_chunks(document_id: str, category: str, department: str, chunks: list) -> None:
    sql("DELETE FROM document_chunks WHERE document_id = :doc",
        [{"name": "doc", "value": {"stringValue": document_id}}])

    insert = (
        "INSERT INTO document_chunks "
        "(document_id, chunk_index, chunk_text, embedding, category, department) "
        "VALUES (:doc, :idx, :txt, CAST(:emb AS vector), :cat, :dep)"
    )
    department_value = {"stringValue": department} if department else {"isNull": True}

    parameter_sets = []
    for index, chunk in enumerate(chunks):
        vector = "[" + ",".join(str(x) for x in embed(chunk)) + "]"
        parameter_sets.append([
            {"name": "doc", "value": {"stringValue": document_id}},
            {"name": "idx", "value": {"longValue": index}},
            {"name": "txt", "value": {"stringValue": chunk}},
            {"name": "emb", "value": {"stringValue": vector}},
            {"name": "cat", "value": {"stringValue": category}},
            {"name": "dep", "value": department_value},
        ])

        if len(parameter_sets) == INSERT_BATCH_SIZE:
            rds_data.batch_execute_statement(
                resourceArn=AURORA_CLUSTER_ARN, secretArn=AURORA_SECRET_ARN,
                database=AURORA_DATABASE, sql=insert, parameterSets=parameter_sets,
            )
            parameter_sets = []

    if parameter_sets:
        rds_data.batch_execute_statement(
            resourceArn=AURORA_CLUSTER_ARN, secretArn=AURORA_SECRET_ARN,
            database=AURORA_DATABASE, sql=insert, parameterSets=parameter_sets,
        )


# --- Handler ---------------------------------------------------------------

def handle_job(message: dict) -> None:
    job_id = message["JobId"]
    status = message["Status"]
    document_id = message["JobTag"]

    logger.info("Textract job_id=%s status=%s document_id=%s", job_id, status, document_id)

    if status != "SUCCEEDED":
        update_document(document_id, status="error", error_reason=f"Textract status: {status}")
        return

    document = get_document(document_id)
    category = document.get("category")
    if not category:
        update_document(document_id, status="error", error_reason="Documento sin categoría en metadata")
        return

    text = get_text(job_id)
    if not text.strip():
        update_document(document_id, status="error", error_reason="Textract no detectó texto")
        return

    chunks = chunk_text(text)
    save_chunks(document_id, category, document.get("department"), chunks)

    update_document(document_id, status="indexed", chunk_count=len(chunks))
    logger.info("Indexado document_id=%s chunks=%d", document_id, len(chunks))


def lambda_handler(event, context):
    for record in event.get("Records", []):
        message = json.loads(record["Sns"]["Message"])
        try:
            handle_job(message)
        except Exception as exc:
            logger.exception("Error procesando document_id=%s", message.get("JobTag"))
            update_document(message["JobTag"], status="error", error_reason=str(exc)[:500])
            raise

    return {"statusCode": 200}
