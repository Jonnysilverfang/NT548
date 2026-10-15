// Keep the existing production MySQL resources under their original Terraform
// addresses. Renaming them to postgresql would make Terraform destroy MySQL.
resource "aws_db_subnet_group" "mysql" {
  name       = "${lower(var.project_name)}-rds-subnet-group"
  subnet_ids = var.existing_mysql_subnet_ids

  tags = {
    Name    = "${var.project_name}-rds-subnet-group"
    Project = var.project_name
  }
}

resource "aws_security_group" "mysql" {
  # checkov:skip=CKV2_AWS_5: Security group is attached to the existing MySQL instance below.
  name        = "${var.project_name}-rds-mysql-sg"
  description = "MySQL access from NT548 ECS tasks only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from ECS tasks"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.ecs_tasks_security_group_id]
  }

  egress {
    description = "Allow database response traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-rds-mysql-sg"
    Project = var.project_name
  }
}

resource "aws_db_instance" "mysql" {
  identifier                  = "${lower(var.project_name)}-mysql"
  engine                      = "mysql"
  engine_version              = "8.4.11"
  instance_class              = "db.t4g.micro"
  db_name                     = "nt548"
  username                    = "nt548_admin"
  manage_master_user_password = true

  allocated_storage     = 20
  max_allocated_storage = 50
  storage_type          = "gp3"
  iops                  = 3000
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.mysql.name
  vpc_security_group_ids = [aws_security_group.mysql.id]
  publicly_accessible    = false
  multi_az               = false

  backup_retention_period    = 1
  apply_immediately          = true
  deletion_protection        = false
  skip_final_snapshot        = true
  auto_minor_version_upgrade = true

  tags = {
    Name    = "${var.project_name}-mysql"
    Project = var.project_name
  }
}

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
