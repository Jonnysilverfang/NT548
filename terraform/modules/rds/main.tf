resource "aws_security_group" "mysql" {
  name        = "${var.project_name}-rds-mysql-sg"
  description = "MySQL access from NT548 ECS tasks only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from ECS tasks"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.ecs_security_group_id]
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

resource "aws_db_subnet_group" "mysql" {
  name       = lower("${var.project_name}-rds-subnet-group")
  subnet_ids = var.subnet_ids

  tags = {
    Name    = "${var.project_name}-rds-subnet-group"
    Project = var.project_name
  }
}

resource "aws_db_instance" "mysql" {
  identifier                  = lower("${var.project_name}-mysql")
  engine                      = "mysql"
  instance_class              = "db.t4g.micro"
  allocated_storage           = 20
  max_allocated_storage       = 50
  storage_type                = "gp3"
  storage_encrypted           = true
  db_name                     = var.db_name
  username                    = var.db_username
  manage_master_user_password = true
  port                        = 3306
  publicly_accessible         = false
  multi_az                    = false
  backup_retention_period     = 1
  skip_final_snapshot         = true
  apply_immediately           = true
  deletion_protection         = false

  db_subnet_group_name   = aws_db_subnet_group.mysql.name
  vpc_security_group_ids = [aws_security_group.mysql.id]

  tags = {
    Name    = "${var.project_name}-mysql"
    Project = var.project_name
  }
}
