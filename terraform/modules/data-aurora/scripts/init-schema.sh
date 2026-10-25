#!/usr/bin/env bash
# Crea el esquema de pgvector en Aurora vía RDS Data API.
# Idempotente: todo usa IF NOT EXISTS, se puede correr N veces.
# Lo invoca Terraform (terraform_data) — no correr a mano salvo debugging.
set -euo pipefail
: "${CLUSTER_ARN:?falta CLUSTER_ARN}" "${SECRET_ARN:?falta SECRET_ARN}" "${DATABASE:?falta DATABASE}"

run_sql() {
  local sql="$1"
  for attempt in {1..10}; do
    if aws rds-data execute-statement \
        --resource-arn "$CLUSTER_ARN" --secret-arn "$SECRET_ARN" \
        --database "$DATABASE" --sql "$sql" > /dev/null 2>/tmp/init-schema.err; then
      echo "OK: ${sql:0:70}"
      return 0
    fi
    echo "Intento $attempt falló, reintento en 15s: $(head -c 200 /tmp/init-schema.err)"
    sleep 15
  done
  echo "ERROR definitivo: $sql" >&2
  return 1
}

run_sql "CREATE EXTENSION IF NOT EXISTS vector"

run_sql "CREATE TABLE IF NOT EXISTS document_chunks (
  id          BIGSERIAL PRIMARY KEY,
  document_id TEXT NOT NULL,
  chunk_index INT NOT NULL,
  chunk_text  TEXT NOT NULL,
  embedding   VECTOR(1024) NOT NULL,
  category    TEXT NOT NULL,
  department  TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
)"

run_sql "CREATE INDEX IF NOT EXISTS idx_chunks_category ON document_chunks (category)"

run_sql "CREATE INDEX IF NOT EXISTS idx_chunks_embedding ON document_chunks USING hnsw (embedding vector_cosine_ops)"
