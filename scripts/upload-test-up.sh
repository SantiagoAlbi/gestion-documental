#!/usr/bin/env bash
# Sube un documento de prueba (POST /documents + PUT a S3) y espera a que quede indexado.
# Requiere haber corrido antes: source scripts/test-env.sh
# Uso:  source scripts/upload-test-doc.sh [archivo] [categoria] [titulo]
# Ej.:  source scripts/upload-test-doc.sh
#       source scripts/upload-test-doc.sh test-data/resolucion-legal-test.pdf rrhh "Prueba RBAC"
# Deja exportado DOC_ID para las pruebas siguientes.

(return 0 2>/dev/null) || { echo "Usar: source scripts/upload-test-doc.sh (no bash)"; exit 1; }

_main() {
  local repo_root file category title ext file_type resp upload_url ct put_code
  repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

  file="${1:-$repo_root/test-data/resolucion-legal-test.pdf}"
  category="${2:-legal}"
  ext="${file##*.}"; file_type="$(echo "$ext" | tr '[:upper:]' '[:lower:]')"
  title="${3:-$(basename "$file" ."$ext")}"

  for v in API TOKEN META_TABLE; do
    [ -n "${!v}" ] || { echo "Falta $v: correr antes 'source scripts/test-env.sh'"; return 1; }
  done
  [ -f "$file" ] || { echo "No existe el archivo: $file"; return 1; }

  echo "== POST /documents (categoría: $category) =="
  resp=$(curl -s -w '\n%{http_code}' -X POST "$API/documents" \
    -H "Authorization: $TOKEN" -H "Content-Type: application/json" \
    -d "$(python3 -c 'import json,sys; print(json.dumps({"category":sys.argv[1],"title":sys.argv[2],"file_type":sys.argv[3],"department":sys.argv[1]}))' \
          "$category" "$title" "$file_type")")

  local code="${resp##*$'\n'}" body="${resp%$'\n'*}"
  echo "  HTTP: $code"
  if [ "$code" != "200" ]; then
    echo "  respuesta: $body" | sed 's/x-amz-security-token=[^&"]*/x-amz-security-token=REDACTED/g'
    return 1
  fi

  export DOC_ID=$(echo "$body" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("document_id",""))')
  upload_url=$(echo "$body" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("upload_url",""))')
  ct=$(echo "$body" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("content_type",""))')
  echo "  DOC_ID: $DOC_ID | content_type: $ct"

  echo "== PUT a S3 =="
  put_code=$(curl -s -o /tmp/put-resp.xml -w '%{http_code}' -X PUT "$upload_url" \
    -H "Content-Type: $ct" --upload-file "$file")
  unset upload_url
  echo "  HTTP: $put_code"
  if [ "$put_code" != "200" ]; then
    grep -oE '<Code>[^<]+</Code>|<Message>[^<]+</Message>' /tmp/put-resp.xml
    rm -f /tmp/put-resp.xml; return 1
  fi
  rm -f /tmp/put-resp.xml

  echo "== Procesamiento (polling DynamoDB, máx. 3 min) =="
  local i status item
  for i in $(seq 1 18); do
    item=$(aws dynamodb get-item --table-name "$META_TABLE" \
      --key "{\"document_id\":{\"S\":\"$DOC_ID\"}}" --output json 2>&1)
    status=$(echo "$item" | python3 -c '
import sys,json
try:
    it = json.load(sys.stdin).get("Item", {})
    v = lambda k: next(iter(it.get(k, {"S": "-"}).values()))
    print(v("status"), "| chunks:", v("chunk_count"))
except Exception:
    print("ERROR")')
    echo "  [$((i*10))s] $status"
    case "$status" in
      indexed*) echo "  OK: documento indexado"; return 0 ;;
      failed*|error*|ERROR) echo "  Falló el procesamiento. Ver logs de processing / textract-callback."; return 1 ;;
    esac
    sleep 10
  done
  echo "  Timeout: no llegó a 'indexed' en 3 min"; return 1
}

_main "$@"
unset -f _main
