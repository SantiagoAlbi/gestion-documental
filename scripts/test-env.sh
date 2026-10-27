#!/usr/bin/env bash
# Prepara la sesión de pruebas después de cada terraform apply.
# Uso:  source scripts/test-env.sh
# Re-ejecutar cuando venza el token (1 h). Es idempotente.

(return 0 2>/dev/null) || { echo "Usar: source scripts/test-env.sh (no bash)"; exit 1; }

_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
_TF_DIR="$_REPO_ROOT/terraform"
_CLUSTER_ID="gestion-documental-aurora-dev"

_tf_out() { terraform -chdir="$_TF_DIR" output -raw "$1" 2>/dev/null; }

_main() {
  echo "== Outputs de Terraform =="
  export POOL_ID=$(_tf_out cognito_user_pool_id)
  export CLIENT_ID=$(_tf_out cognito_app_client_id)
  export API=$(_tf_out api_invoke_url)
  export API_ID=$(echo "$API" | cut -d/ -f3 | cut -d. -f1)
  export META_TABLE=$(_tf_out documents_metadata_table_name)
  export SECRET_ARN=$(_tf_out aurora_master_user_secret_arn)
  export CLUSTER_ARN=$(aws rds describe-db-clusters --db-cluster-identifier "$_CLUSTER_ID" \
    --query 'DBClusters[0].DBClusterArn' --output text 2>/dev/null)
  export DB_NAME=$(aws rds describe-db-clusters --db-cluster-identifier "$_CLUSTER_ID" \
    --query 'DBClusters[0].DatabaseName' --output text 2>/dev/null)

  local missing=0
  for v in POOL_ID CLIENT_ID API API_ID META_TABLE SECRET_ARN CLUSTER_ARN DB_NAME; do
    if [ -z "${!v}" ] || [ "${!v}" = "None" ]; then echo "  $v VACÍA"; missing=1; else echo "  $v OK"; fi
  done
  [ "$missing" -eq 0 ] || { echo "Faltan variables: ¿la infra está desplegada?"; return 1; }

  echo "== Usuario de test =="
  export TEST_USER="${TEST_USER:-abogado.test@example.com}"
  export TEST_GROUP="${TEST_GROUP:-legal-abogado}"
  export TEST_PASS="$(python3 -c 'import secrets; print("Tst-" + secrets.token_urlsafe(16) + "9a!")')"

  local create_out
  if create_out=$(aws cognito-idp admin-create-user --user-pool-id "$POOL_ID" --username "$TEST_USER" \
      --user-attributes Name=email,Value="$TEST_USER" Name=email_verified,Value=true \
      --message-action SUPPRESS --query 'User.Username' --output text 2>&1); then
    echo "  usuario creado"
  elif echo "$create_out" | grep -q UsernameExistsException; then
    echo "  usuario ya existía"
  else
    echo "  ERROR creando usuario: $create_out"; return 1
  fi

  aws cognito-idp admin-set-user-password --user-pool-id "$POOL_ID" --username "$TEST_USER" \
    --password "$TEST_PASS" --permanent || { echo "  ERROR seteando password"; return 1; }

  aws cognito-idp admin-add-user-to-group --user-pool-id "$POOL_ID" --username "$TEST_USER" \
    --group-name "$TEST_GROUP" || { echo "  ERROR agregando al grupo $TEST_GROUP"; return 1; }
  echo "  grupo: $TEST_GROUP"

  echo "== Token =="
  export TOKEN=$(aws cognito-idp admin-initiate-auth --user-pool-id "$POOL_ID" --client-id "$CLIENT_ID" \
    --auth-flow ADMIN_USER_PASSWORD_AUTH \
    --auth-parameters USERNAME="$TEST_USER",PASSWORD="$TEST_PASS" \
    --query 'AuthenticationResult.IdToken' --output text 2>/dev/null)

  if [ -z "$TOKEN" ] || [ "$TOKEN" = "None" ]; then
    echo "  ERROR: no se obtuvo IdToken (¿MFA en ON? revisar mfa_configuration en terraform.tfvars)"
    return 1
  fi

  python3 - "$TOKEN" <<'PY'
import sys, json, base64, datetime
payload = sys.argv[1].split(".")[1]
payload += "=" * (-len(payload) % 4)
c = json.loads(base64.urlsafe_b64decode(payload))
exp = datetime.datetime.fromtimestamp(c["exp"]).strftime("%H:%M")
print(f"  email: {c.get('email')}  grupos: {c.get('cognito:groups')}  vence: {exp}")
PY
}

_main
unset -f _main _tf_out
unset _REPO_ROOT _TF_DIR _CLUSTER_ID
