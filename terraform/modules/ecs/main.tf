data "aws_region" "current" {}

resource "aws_ecs_cluster" "main" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name    = var.cluster_name
    Project = "NT548"
  }
}

# CloudWatch Log Groups for PROD
resource "aws_cloudwatch_log_group" "prod_logs" {
  # checkov:skip=CKV_AWS_158: "CloudWatch Log Group encryption using default AWS key is sufficient for project requirements"
  # checkov:skip=CKV_AWS_338: "Retention period set for lab lifecycle"
  for_each          = toset(["frontend", "user", "product", "order"])
  name              = "/nt548/prod/${each.key}"
  retention_in_days = 14
}

# CloudWatch Log Groups for DEV
resource "aws_cloudwatch_log_group" "dev_logs" {
  # checkov:skip=CKV_AWS_158: "CloudWatch Log Group encryption using default AWS key is sufficient for project requirements"
  # checkov:skip=CKV_AWS_338: "Retention period set for lab lifecycle"
  for_each          = toset(["frontend", "user", "product", "order"])
  name              = "/nt548/dev/${each.key}"
  retention_in_days = 7
}

# PROD Task Definitions
resource "aws_ecs_task_definition" "prod_frontend" {
  family                   = "nt548-prod-frontend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([{
    name      = "frontend"
    image     = var.image_urls.frontend
    essential = true
    portMappings = [{
      containerPort = 80
      protocol      = "tcp"
    }]
    environment = [
      { name = "ENVIRONMENT", value = "prod" },
      { name = "USER_SERVICE_HOST", value = var.frontend_api_host },
      { name = "USER_SERVICE_PORT", value = "80" },
      { name = "PRODUCT_SERVICE_HOST", value = var.frontend_api_host },
      { name = "PRODUCT_SERVICE_PORT", value = "80" },
      { name = "ORDER_SERVICE_HOST", value = var.frontend_api_host },
      { name = "ORDER_SERVICE_PORT", value = "80" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.prod_logs["frontend"].name
        awslogs-region        = data.aws_region.current.name
        awslogs-stream-prefix = "prod"
        mode                  = "blocking"
      }
    }
  }])
}

resource "aws_ecs_task_definition" "prod_user" {
  family                   = "nt548-prod-user"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([{
    name      = "user"
    image     = var.image_urls.user
    essential = true
    portMappings = [{
      containerPort = 5001
      protocol      = "tcp"
    }]
    environment = [
      { name = "ENVIRONMENT", value = "prod" },
      { name = "PORT", value = "5001" },
      { name = "NODE_ENV", value = "production" },
      { name = "ADMIN_EMAIL", value = "admin@nt548.local" }
    ]
    secrets = [
      { name = "JWT_SECRET", valueFrom = "${var.app_secret_arn}:JWT_SECRET::" },
      { name = "ADMIN_PASSWORD", valueFrom = "${var.app_secret_arn}:ADMIN_PASSWORD::" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.prod_logs["user"].name
        awslogs-region        = data.aws_region.current.name
        awslogs-stream-prefix = "prod"
        mode                  = "blocking"
      }
    }
  }])
}

resource "aws_ecs_task_definition" "prod_product" {
  family                   = "nt548-prod-product"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([{
    name      = "product"
    image     = var.image_urls.product
    essential = true
    portMappings = [{
      containerPort = 5002
      protocol      = "tcp"
    }]
    environment = [
      { name = "ENVIRONMENT", value = "prod" },
      { name = "PORT", value = "5002" }
    ]
    secrets = [
      { name = "JWT_SECRET", valueFrom = "${var.app_secret_arn}:JWT_SECRET::" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.prod_logs["product"].name
        awslogs-region        = data.aws_region.current.name
        awslogs-stream-prefix = "prod"
        mode                  = "blocking"
      }
    }
  }])
}

resource "aws_ecs_task_definition" "prod_order" {
  family                   = "nt548-prod-order"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([{
    name      = "order"
    image     = var.image_urls.order
    essential = true
    portMappings = [{
      containerPort = 5003
      protocol      = "tcp"
    }]
    environment = [
      { name = "ENVIRONMENT", value = "prod" },
      { name = "PORT", value = "5003" }
    ]
    secrets = [
      { name = "JWT_SECRET", valueFrom = "${var.app_secret_arn}:JWT_SECRET::" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.prod_logs["order"].name
        awslogs-region        = data.aws_region.current.name
        awslogs-stream-prefix = "prod"
        mode                  = "blocking"
      }
    }
  }])
}

# PROD ECS Services (Always running 24/7 with Rolling Deployment)
resource "aws_ecs_service" "prod_frontend" {
  # checkov:skip=CKV_AWS_333: "Public IP is required in public subnets because this lab intentionally avoids NAT Gateway cost"
  name                               = "nt548-prod-frontend"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.prod_frontend.arn
  desired_count                      = var.service_desired_count
  launch_type                        = "FARGATE"
  platform_version                   = "LATEST"
  health_check_grace_period_seconds  = 60
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.security_group_id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = var.prod_target_groups.frontend
    container_name   = "frontend"
    container_port   = 80
  }

  lifecycle {
    ignore_changes = [
      task_definition
    ]
  }

  tags = {
    Environment = "prod"
    Service     = "frontend"
  }
}

resource "aws_ecs_service" "prod_user" {
  # checkov:skip=CKV_AWS_333: "Public IP is required in public subnets because this lab intentionally avoids NAT Gateway cost"
  name                               = "nt548-prod-user"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.prod_user.arn
  desired_count                      = var.service_desired_count
  launch_type                        = "FARGATE"
  platform_version                   = "LATEST"
  health_check_grace_period_seconds  = 60
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.security_group_id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = var.prod_target_groups.user
    container_name   = "user"
    container_port   = 5001
  }

  lifecycle {
    ignore_changes = [
      task_definition
    ]
  }

  tags = {
    Environment = "prod"
    Service     = "user"
  }
}

resource "aws_ecs_service" "prod_product" {
  # checkov:skip=CKV_AWS_333: "Public IP is required in public subnets because this lab intentionally avoids NAT Gateway cost"
  name                               = "nt548-prod-product"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.prod_product.arn
  desired_count                      = var.service_desired_count
  launch_type                        = "FARGATE"
  platform_version                   = "LATEST"
  health_check_grace_period_seconds  = 60
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.security_group_id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = var.prod_target_groups.product
    container_name   = "product"
    container_port   = 5002
  }

  lifecycle {
    ignore_changes = [
      task_definition
    ]
  }

  tags = {
    Environment = "prod"
    Service     = "product"
  }
}

resource "aws_ecs_service" "prod_order" {
  # checkov:skip=CKV_AWS_333: "Public IP is required in public subnets because this lab intentionally avoids NAT Gateway cost"
  name                               = "nt548-prod-order"
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.prod_order.arn
  desired_count                      = var.service_desired_count
  launch_type                        = "FARGATE"
  platform_version                   = "LATEST"
  health_check_grace_period_seconds  = 60
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.security_group_id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = var.prod_target_groups.order
    container_name   = "order"
    container_port   = 5003
  }

  lifecycle {
    ignore_changes = [
      task_definition
    ]
  }

  tags = {
    Environment = "prod"
    Service     = "order"
  }
}
