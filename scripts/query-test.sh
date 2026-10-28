#!/usr/bin/env bash
# Envía una pregunta a POST /query y muestra código HTTP, latencia y respuesta.
# Requiere haber corrido antes: source scripts/test-env.sh
# Uso:  bash scripts/query-test.sh "pregunta"

set -euo pipefail

QUESTION="${1:-}"
[ -n "$QUESTION" ] || { echo 'Uso: bash scripts/query-test.sh "pregunta"'; exit 1; }

for v in API TOKEN; do
  [ -n "${!v:-}" ] || { echo "Falta $v: correr antes 'source scripts/test-env.sh'"; exit 1; }
done

PAYLOAD=$(python3 -c 'import json,sys; print(json.dumps({"question": sys.argv[1]}))' "$QUESTION")

RESP=$(curl -s -w '\n%{http_code} %{time_total}' -X POST "$API/query" \
  -H "Authorization: $TOKEN" -H "Content-Type: application/json" \
  -d "$PAYLOAD")

META="${RESP##*$'\n'}"
BODY="${RESP%$'\n'*}"
CODE="${META% *}"
TIME="${META#* }"

echo "== POST /query =="
echo "  pregunta: $QUESTION"
echo "  HTTP: $CODE | tiempo: ${TIME}s"
echo "== Respuesta =="
echo "$BODY" | python3 -c '
import sys, json
raw = sys.stdin.read()
try:
    print(json.dumps(json.loads(raw), indent=2, ensure_ascii=False))
except json.JSONDecodeError:
    print(raw)'
