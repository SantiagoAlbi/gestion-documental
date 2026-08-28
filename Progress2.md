# ==============================================================================
# SESIÓN: Aplicación por capas — Capa 1 y Capa 2 validadas end-to-end
# ==============================================================================
#
# --- QUÉ HICIMOS ---
#
# 1. Aplicación incremental por capas (no los 11 módulos de una), para aislar
#    fallas y no repetir el tiempo de espera de Aurora por un error en otro módulo:
#      Capa 1: network + data-dynamodb + data-aurora
#      Capa 2: storage + queue + cognito
#    (Capa 3: compute + api, y Capa 4: monitoring + cicd quedan para la próxima sesión)
#
# 2. Bugs encontrados y resueltos, todos con fix en Terraform/código (nunca CLI):
#    a. Security Group de Aurora: GroupDescription con em dash (—) no-ASCII,
#       rechazado por la API de EC2. Fix: reemplazado por guión simple en
#       modules/data-aurora/main.tf.
#    b. Client VPN Endpoint: certificado ACM sin dominio (DomainName vacío).
#       Root cause: tls_cert_request.server en modules/network/certs.tf no
#       definía dns_names (solo common_name), y ACM deriva DomainName del SAN,
#       no del CN. Fix: agregado dns_names al cert request. NOTA: el proyecto
#       genera certs 100% vía provider `tls` de Terraform — el plan de usar
#       easy-rsa manual quedó descartado, no hizo falta.
#    c. Aurora: engine_version = "15.4" ya no disponible en us-east-1 (versión
#       deprecada). Fix: actualizado a 15.17 (confirmado disponible, release
#       abril 2026) en modules/data-aurora/main.tf.
#    d. S3 storage: aws_s3_bucket_cors_configuration falló con "couldn't find
#       resource" — race condition de consistencia eventual de S3 justo después
#       de crear el bucket. Fix: agregado depends_on explícito apuntando a
#       aws_s3_bucket_public_access_block.documents en modules/storage/main.tf.
#
# 3. terraform.tfvars creado (no versionado, confirmado en .gitignore):
#    - allowed_office_ips con IP pública real (dinámica — revisar si falla el
#      acceso a futuro, correr `curl https://checkip.amazonaws.com` de nuevo)
#    - alert_email pendiente de completar con email real (placeholder actual)
#    - cors_allowed_origins se deja en default ["*"] hasta que exista dominio
#      real de frontend
#
# 4. Verificación de seguridad: se sospechó por un momento que una private key
#    de easy-rsa había quedado commiteada y pusheada a GitHub. Se verificó con
#    `git log --all --diff-filter=A --name-only` y GitHub secret scanning:
#    NUNCA llegó a estar en un commit real (quedó solo en staging/editor).
#    No hubo key comprometida, no hizo falta purgar historial.
#
# --- DÓNDE ESTAMOS ---
#
# Capas 1 y 2 (7 módulos: network, secrets, data_dynamodb, data_aurora, storage,
# queue, cognito — 52 recursos) aplicadas, verificadas con `terraform state list`
# + AWS CLI, y DESTRUIDAS (para controlar costo, criterio ya establecido: no
# dejar Aurora ni Client VPN corriendo entre sesiones).
#
# Commit local hecho con los 4 fixes de arriba (pendiente de `git push`).
#
# --- QUÉ FALTA (orden sugerido, sin cambios respecto al plan original) ---
#
# 1. Capa 3: compute (6 Lambdas + Bedrock Guardrail) + api (REST API v1,
#    Cognito Authorizer, IP allowlist ya en tfvars) — la más compleja y
#    menos predecible, dejar tiempo/margen de sesión para debugging.
# 2. Capa 4: monitoring + cicd.
# 3. TODOs de código Python (sin cambios: processing, textract-callback, query).
# 4. Fuera de Terraform: schema Aurora, seed rbac-permissions, GitHub Actions
#    workflow YAML, frontend.
#
# --- LECCIÓN PARA PRÓXIMAS SESIONES ---
#   - Aplicar por capas funcionó bien: cada bug se aisló rápido porque el error
#     apuntaba a un solo módulo nuevo, no a una interacción entre 11.
#   - Antes de un `apply` grande, chequear versiones de motor/engine (RDS, etc.)
#     contra la documentación actual — no asumir que un valor de hace meses
#     sigue siendo válido, AWS deprecia versiones con el tiempo.
#   - S3 + CORS/policy en el mismo apply: agregar depends_on por default a
#     futuro, no solo cuando falla.
# ==============================================================================
