resource "aws_db_subnet_group" "postgresql" {
  name       = "${lower(var.project_name)}-postgresql-subnets"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name    = "${var.project_name}-postgresql-subnets"
    Project = var.project_name
  }
}

resource "aws_security_group" "postgresql" {
  # checkov:skip=CKV2_AWS_5: Security group is attached to the RDS instance below.
  name        = "${lower(var.project_name)}-postgresql-sg"
  description = "Allow PostgreSQL only from NT548 ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from ECS tasks"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.ecs_tasks_security_group_id]
  }

  tags = {
    Name    = "${var.project_name}-postgresql-sg"
    Project = var.project_name
  }
}

resource "aws_db_instance" "postgresql" {
  identifier = var.identifier

  engine         = "postgres"
  engine_version = "16"
  instance_class = var.instance_class

  db_name  = var.database_name
  username = var.master_username

  manage_master_user_password = true

  allocated_storage     = var.allocated_storage
  max_allocated_storage = 50
  storage_type          = "gp3"
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.postgresql.name
  vpc_security_group_ids = [aws_security_group.postgresql.id]
  publicly_accessible    = false
  multi_az               = false

  backup_retention_period         = 7
  copy_tags_to_snapshot           = true
  deletion_protection             = var.deletion_protection
  skip_final_snapshot             = false
  final_snapshot_identifier       = "${var.identifier}-final"
  auto_minor_version_upgrade      = true
  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = {
    Name        = var.identifier
    Environment = "shared"
    Project     = var.project_name
  }
}
