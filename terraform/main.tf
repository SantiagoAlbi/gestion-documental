# Backend remoto — bucket creado por bootstrap/ (correr terraform apply ahí primero)
# Completar "bucket" con el output "state_bucket_name" del bootstrap.
terraform {
  backend "s3" {
    bucket       = "gestion-documental-terraform-state-d6ba25f3" # reemplazar con el output del bootstrap
    key          = "gestion-documental/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true # locking nativo S3, reemplaza dynamodb_table (requiere Terraform >= 1.10.0)
    encrypt      = true
  }
}

# ---------------------------------------------------------------------------
# Orden de dependencia (de menor a mayor):
#   network -> secrets -> data-dynamodb -> data-aurora -> storage -> queue
#   -> cognito -> compute -> api -> monitoring -> cicd
# ---------------------------------------------------------------------------

module "network" {
  source = "./modules/network"

  project_name = var.project_name
  environment  = var.environment
}

module "secrets" {
  source = "./modules/secrets"

  project_name = var.project_name
  environment  = var.environment
}

module "data_dynamodb" {
  source = "./modules/data-dynamodb"

  project_name = var.project_name
  environment  = var.environment
}

module "data_aurora" {
  source = "./modules/data-aurora"

  project_name             = var.project_name
  environment              = var.environment
  vpc_id                   = module.network.vpc_id
  private_subnet_ids       = module.network.private_subnet_ids
  lambda_security_group_id = module.network.lambda_security_group_id
}

module "storage" {
  source = "./modules/storage"

  project_name = var.project_name
  environment  = var.environment
}

module "queue" {
  source = "./modules/queue"

  project_name = var.project_name
  environment  = var.environment
  bucket_arn   = module.storage.bucket_arn
}

module "cognito" {
  source = "./modules/cognito"

  project_name = var.project_name
  environment  = var.environment
}
/*
module "compute" {
  source = "./modules/compute"

  project_name = var.project_name
  environment  = var.environment

  # network
  private_subnet_ids        = module.network.private_subnet_ids
  lambda_security_group_id  = module.network.lambda_security_group_id
  client_vpn_endpoint_id     = module.network.client_vpn_endpoint_id
  vpn_private_subnet_ids     = module.network.private_subnet_ids

  # storage
  documents_bucket_name = module.storage.bucket_id
  documents_bucket_arn  = module.storage.bucket_arn

  # data-dynamodb
  documents_metadata_table_name = module.data_dynamodb.documents_metadata_table_name
  documents_metadata_table_arn  = module.data_dynamodb.documents_metadata_table_arn
  audit_log_table_name          = module.data_dynamodb.audit_log_table_name
  audit_log_table_arn           = module.data_dynamodb.audit_log_table_arn
  rbac_permissions_table_name   = module.data_dynamodb.rbac_permissions_table_name
  rbac_permissions_table_arn    = module.data_dynamodb.rbac_permissions_table_arn

  # data-aurora
  aurora_cluster_endpoint       = module.data_aurora.cluster_endpoint
  aurora_database_name          = module.data_aurora.database_name
  aurora_master_user_secret_arn = module.data_aurora.master_user_secret_arn

  # queue
  migration_queue_arn = module.queue.queue_arn
}

module "api" {
  source = "./modules/api"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  cognito_user_pool_arn = module.cognito.user_pool_arn

  presigned_lambda_invoke_arn    = module.compute.presigned_lambda_invoke_arn
  presigned_lambda_function_name = module.compute.presigned_lambda_function_name
  query_lambda_invoke_arn        = module.compute.query_lambda_invoke_arn
  query_lambda_function_name     = module.compute.query_lambda_function_name

  execute_api_vpc_endpoint_id = module.network.execute_api_vpc_endpoint_id
  allowed_office_ips          = var.allowed_office_ips
}

module "monitoring" {
  source = "./modules/monitoring"

  project_name = var.project_name
  environment  = var.environment
  alert_email  = var.alert_email

  lambda_function_names = [
    module.compute.presigned_lambda_function_name,
    module.compute.query_lambda_function_name,
    module.compute.processing_lambda_function_name,
    module.compute.migration_consumer_function_name,
    module.compute.textract_callback_function_name,
    module.compute.lights_off_function_name,
  ]

  migration_dlq_name = module.queue.dlq_name
  api_gateway_name    = module.api.rest_api_name
  api_gateway_stage    = var.environment
  aurora_cluster_id    = module.data_aurora.cluster_id
}

module "cicd" {
  source = "./modules/cicd"

  project_name = var.project_name
  environment  = var.environment
  github_repo  = var.github_repo
}
*/
