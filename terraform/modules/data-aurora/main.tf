terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-aurora-subnet-group-${var.environment}"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.project_name}-aurora-subnet-group-${var.environment}"
  }
}

resource "aws_security_group" "aurora" {
  name        = "${var.project_name}-aurora-sg-${var.environment}"
  description = "Security Group de Aurora — solo acepta 5432 desde las Lambdas"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Postgres desde las Lambdas"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.lambda_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-aurora-sg-${var.environment}"
  }
}

resource "aws_rds_cluster" "main" {
  cluster_identifier = "${var.project_name}-aurora-${var.environment}"
  engine             = "aurora-postgresql"
  engine_mode        = "provisioned" # requerido para Serverless v2
  engine_version     = var.engine_version
  database_name      = var.database_name
  master_username    = var.master_username

  # RDS genera, guarda y rota automáticamente el password en Secrets Manager.
  # No hay ningún secret hardcodeado ni gestionado a mano.
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.aurora.id]

  serverlessv2_scaling_configuration {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }

  storage_encrypted = true

  # Portfolio/dev: sin snapshot final ni deletion protection, para poder
  # destruir rápido entre sesiones. En producción real, ambos en true.
  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name = "${var.project_name}-aurora-${var.environment}"
  }
}

resource "aws_rds_cluster_instance" "main" {
  count = var.instance_count

  identifier         = "${var.project_name}-aurora-${count.index}-${var.environment}"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version

  tags = {
    Name = "${var.project_name}-aurora-instance-${count.index}-${var.environment}"
  }
}
