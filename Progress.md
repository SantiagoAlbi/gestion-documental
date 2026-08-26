# Progreso — Sistema de Gestión Documental (Ente Gubernamental)

Portfolio Cloud Engineer | Santi | AWS `975049900198` | `us-east-1`

## Qué hicimos

**1. `architecture.md` cerrado** (en Project Knowledge)
- Módulo 1 (acceso total) + Módulo 2 (acotado por rol/puesto)
- Acceso: oficinas por IP allowlist + personal remoto por Client VPN
- 100% VPC Endpoints, sin NAT Gateway, sin Internet Gateway
- Guardrail de doble capa: regex determinístico + Bedrock Guardrails

**2. `data-model.md` cerrado**
- DynamoDB (multi-table): `documents-metadata`, `audit-log`, `rbac-permissions`
- Aurora Serverless v2 + pgvector: `document_chunks`, `tramite_types`, `tramites`
- Titan Embeddings V2 (1024 dim)
- Dos caminos de procesamiento: OCR (Textract) vs. native (docx/xlsx/pdf nativo)

**3. Terraform — 11 módulos completos y validados** (`terraform validate` = Success)

```
terraform/modules/
  network        VPC sin IGW, VPC Endpoints, Client VPN (asociación DINÁMICA vía Lights-Off)
  secrets        placeholder vacío, documentado
  data-dynamodb  las 3 tablas
  data-aurora    Aurora Serverless v2, manage_master_user_password=true
  storage        bucket S3, CORS, TLS-only, lifecycle
  queue          SQS migración masiva + DLQ
  cognito        User Pool, MFA TOTP, grupos departamento-puesto
  compute        6 Lambdas + Bedrock Guardrail + SNS Textract + EventBridge Scheduler
  api            REST API v1, resource policy IP allowlist + VPC Endpoint, Cognito Authorizer
  monitoring     SNS alerts, alarms, dashboard
  cicd           IAM role OIDC para GitHub Actions
terraform/main.tf   los 11 módulos conectados
```

**4. Código Python** (esqueletos funcionales, no producción)

```
src/lambdas/
  presigned-url/handler.py       completo y funcional
  processing/handler.py           funcional, TODOs: extracción nativa + Textract real
  textract-callback/handler.py    funcional, TODOs: paginado + chunking + embeddings + Aurora
  query/handler.py                funcional, TODOs: embedding + pgvector + Bedrock real
  lights-off/handler.py           completo y funcional
```

## Dónde estamos

Terraform validado y aplicable de punta a punta. Debugging de sesión resuelto:
carpeta mal nombrada (`data-dynamo` → `data-dynamodb`), variables faltantes en
`compute`, archivo `presigned-lambda.tf` faltante, warning de
`aws_s3_bucket_lifecycle_configuration` (faltaba `filter {}`).

**Pendiente inmediato antes de aplicar en real:**
- Completar `allowed_office_ips` (módulo `api`) y `alert_email` (módulo `monitoring`) — sin default.
- Definir departamentos/puestos reales (hoy hay ejemplo: legal, rrhh, compras, atención-ciudadano).

## Qué falta (orden sugerido)

**1. TODOs de código de aplicación**
- `processing/handler.py`: extracción nativa (pdfplumber/python-docx/openpyxl) + llamado real a `start_document_text_detection` (`JobTag=document_id`, `NotificationChannel` con el role/topic de `textract-sns.tf`).
- `textract-callback/handler.py`: `get_document_text_detection` paginado + chunking + Bedrock embeddings + conexión Aurora (psycopg2) + insert en `document_chunks`.
- `query/handler.py`: embedding de la pregunta + query pgvector con `WHERE category = ANY(allowed_categories)` + invoke Bedrock con `GUARDRAIL_ID`/`GUARDRAIL_VERSION` (ya vienen como env vars).
- Gap menor: `actor_role` queda `"unknown"` en audit-log — falta guardar `cognito:groups` en `documents-metadata` al momento de la presigned URL.

**2. Fuera de Terraform, manual/una vez**
- Script de migración de schema en Aurora (`CREATE EXTENSION vector` + tablas).
- Seed inicial de `rbac-permissions` (8 filas rol → categorías).
- Script de firma de certificados de cliente por usuario (easy-rsa) para el Client VPN.

**3. Sin empezar**
- Workflow real de GitHub Actions (`.github/workflows/*.yml`) — el role OIDC ya existe (módulo `cicd`), falta el pipeline.
- Frontend (sobrio y funcional).

## Estilo de trabajo (para quien continúe)

- Un paso a la vez, verificar antes de avanzar.
- Diagnóstico antes de solución, marcar gaps de diseño cuando aparecen.
- Rutas de archivo siempre explícitas debajo de cada bloque de código.
- Fix root cause en Terraform/código, nunca parches manuales por CLI.
