# Gestión Documental — Secure RAG on AWS

> 🚧 **Work in progress** — core infrastructure and document pipeline are deployed and tested end to end. Querying, guardrails and the frontend are under active development.

**[English](#english) · [Español](#español)**

---

## English

A document management system for a government agency: scanned documents are uploaded, digitized with OCR, indexed as vector embeddings, and queried in natural language. Every answer is restricted to the documents the user's role is allowed to see.

Built 100% with **Terraform** on **AWS**, fully serverless, inside a private VPC with **no internet access** (no NAT Gateway, no Internet Gateway).

### Architecture

| Layer | Services |
|---|---|
| Network | Private VPC, no NAT/IGW. VPC endpoints: Gateway (S3, DynamoDB) and Interface (Bedrock, Textract, Secrets Manager, RDS Data API, CloudWatch Logs, API Gateway). Client VPN for remote access |
| Identity | Cognito User Pool with TOTP MFA and 8 department/role groups |
| API | API Gateway REST with Cognito Authorizer and an IP allowlist resource policy |
| Processing | S3 → Lambda → Textract (async) → SNS → Lambda → Titan Embeddings V2 |
| Data | Aurora Serverless v2 + pgvector (HNSW index) via RDS Data API; DynamoDB for metadata, audit log and RBAC permissions |
| AI | Amazon Bedrock (Claude Haiku 5.5) with two-layer guardrails: regex pre-filter + Bedrock Guardrails |
| Migration | Batch uploads → SQS → Lambda, with a DLQ |

### Security highlights

- **Defense in depth**: identity (Cognito + MFA) → network (IP allowlist / VPN) → authorization (RBAC per document category) → content (guardrails).
- **Single source of truth for RBAC**: one Terraform variable generates both the Cognito groups and the DynamoDB permission table, so they cannot drift apart.
- **Zero internet egress**: all AWS traffic flows through VPC endpoints. Security groups open gateway endpoints by prefix list, never with `0.0.0.0/0`.
- **Signed uploads**: SigV4 presigned URLs that sign the `Content-Type`.
- **Audit trail** for uploads and queries.

### Status

| | Component | Status |
|---|---|---|
| ✅ | Infrastructure (network, data, storage, identity, compute, API) | Deployed via Terraform |
| ✅ | Login with Cognito groups | Tested |
| ✅ | API: 401 without token, 403 from a non-allowed IP | Tested |
| ✅ | Presigned upload to S3 | Tested |
| ✅ | OCR → chunking → embeddings → pgvector | Tested |
| 🔄 | RAG query with RBAC filtering | In progress |
| 🔄 | Guardrails (regex + Bedrock) | In progress |
| ⏳ | Batch migration with DLQ | Pending |
| ⏳ | Monitoring (CloudWatch) and CI/CD (GitHub Actions + OIDC) | Pending |
| ⏳ | React + Vite frontend with Amplify Auth | Pending |

### Stack

Terraform · AWS · Python 3.13 · PostgreSQL/pgvector · GitHub Actions

---

## Español

Sistema de gestión documental para un ente gubernamental. Los documentos escaneados se suben, se digitalizan con OCR, se indexan como embeddings vectoriales y se consultan en lenguaje natural. Cada respuesta se limita a los documentos que el rol del usuario tiene permitido ver.

Construido 100% con **Terraform** sobre **AWS**, totalmente serverless, dentro de una VPC privada **sin salida a internet** (sin NAT Gateway ni Internet Gateway).

### Arquitectura

| Capa | Servicios |
|---|---|
| Red | VPC privada sin NAT/IGW. VPC endpoints: Gateway (S3, DynamoDB) e Interface (Bedrock, Textract, Secrets Manager, RDS Data API, CloudWatch Logs, API Gateway). Client VPN para acceso remoto |
| Identidad | Cognito User Pool con MFA TOTP y 8 grupos departamento/puesto |
| API | API Gateway REST con Cognito Authorizer y resource policy de IPs permitidas |
| Procesamiento | S3 → Lambda → Textract (async) → SNS → Lambda → Titan Embeddings V2 |
| Datos | Aurora Serverless v2 + pgvector (índice HNSW) vía RDS Data API; DynamoDB para metadata, auditoría y permisos RBAC |
| IA | Amazon Bedrock (Claude Haiku 5.5) con guardrail de doble capa: prefiltro regex + Bedrock Guardrails |
| Migración | Cargas masivas → SQS → Lambda, con DLQ |

### Seguridad

- **Defensa en profundidad**: identidad (Cognito + MFA) → red (allowlist de IPs / VPN) → autorización (RBAC por categoría de documento) → contenido (guardrails).
- **RBAC con fuente única**: una sola variable de Terraform genera los grupos de Cognito y la tabla de permisos en DynamoDB, así que no pueden desalinearse.
- **Cero salida a internet**: todo el tráfico hacia AWS pasa por VPC endpoints. Los security groups habilitan los gateway endpoints por prefix list, nunca con `0.0.0.0/0`.
- **Subidas firmadas**: presigned URLs SigV4 que firman el `Content-Type`.
- **Auditoría** de subidas y consultas.

### Estado

| | Componente | Estado |
|---|---|---|
| ✅ | Infraestructura (red, datos, storage, identidad, cómputo, API) | Desplegada con Terraform |
| ✅ | Login con grupos de Cognito | Probado |
| ✅ | API: 401 sin token, 403 desde IP no permitida | Probado |
| ✅ | Subida a S3 con presigned URL | Probado |
| ✅ | OCR → chunking → embeddings → pgvector | Probado |
| 🔄 | Consulta RAG con filtrado RBAC | En progreso |
| 🔄 | Guardrails (regex + Bedrock) | En progreso |
| ⏳ | Migración masiva con DLQ | Pendiente |
| ⏳ | Monitoreo (CloudWatch) y CI/CD (GitHub Actions + OIDC) | Pendiente |
| ⏳ | Frontend React + Vite con Amplify Auth | Pendiente |

### Stack

Terraform · AWS · Python 3.13 · PostgreSQL/pgvector · GitHub Actions
