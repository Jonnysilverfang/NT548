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

resource "aws_cloudwatch_log_group" "prod_otel_collector" {
  # Collector diagnostics are separate from application logs for faster triage.
  # checkov:skip=CKV_AWS_158: "CloudWatch Log Group encryption using default AWS key is sufficient for project requirements"
  # checkov:skip=CKV_AWS_338: "Retention period set for lab lifecycle"
  name              = "/nt548/prod/otel-collector"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "prod_app_metrics" {
  # EMF exporter writes application metrics through CloudWatch Logs.
  # checkov:skip=CKV_AWS_158: "CloudWatch Log Group encryption using default AWS key is sufficient for project requirements"
  # checkov:skip=CKV_AWS_338: "Retention period set for lab lifecycle"
  name              = "/metrics/NT548/Application"
  retention_in_days = 14
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
  cpu                      = "512"
  memory                   = "1024"
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
      { name = "ADMIN_EMAIL", value = "admin@nt548.local" },
      { name = "OTEL_SERVICE_NAME", value = "nt548-prod-user-service" },
      { name = "OTEL_EXPORTER_OTLP_ENDPOINT", value = "http://127.0.0.1:4317" },
      { name = "OTEL_EXPORTER_OTLP_PROTOCOL", value = "grpc" },
      { name = "OTEL_RESOURCE_ATTRIBUTES", value = "deployment.environment=prod,service.namespace=nt548" },
      { name = "OTEL_TRACES_SAMPLER", value = "parentbased_traceidratio" },
      { name = "OTEL_TRACES_SAMPLER_ARG", value = "1.0" },
      { name = "OTEL_METRICS_EXPORTER", value = "otlp" },
      { name = "OTEL_LOGS_EXPORTER", value = "none" },
      { name = "DB_HOST", value = var.db_host },
      { name = "DB_PORT", value = "3306" },
      { name = "DB_NAME", value = var.db_name }
    ]
    secrets = [
      { name = "JWT_SECRET", valueFrom = "${var.app_secret_arn}:JWT_SECRET::" },
      { name = "ADMIN_PASSWORD", valueFrom = "${var.app_secret_arn}:ADMIN_PASSWORD::" },
      { name = "DB_USER", valueFrom = "${var.db_credentials_secret_arn}:username::" },
      { name = "DB_PASSWORD", valueFrom = "${var.db_credentials_secret_arn}:password::" }
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
    }, {
    name        = "adot-collector"
    image       = var.observability_image
    essential   = false
    command     = ["--config=/etc/ecs/nt548-adot.yaml"]
    environment = [{ name = "AWS_REGION", value = data.aws_region.current.name }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.prod_otel_collector.name
        awslogs-region        = data.aws_region.current.name
        awslogs-stream-prefix = "user"
        mode                  = "blocking"
      }
    }
  }])
}

resource "aws_ecs_task_definition" "prod_product" {
  family                   = "nt548-prod-product"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
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
      { name = "PORT", value = "5002" },
      { name = "OTEL_SERVICE_NAME", value = "nt548-prod-product-service" },
      { name = "OTEL_EXPORTER_OTLP_ENDPOINT", value = "http://127.0.0.1:4317" },
      { name = "OTEL_EXPORTER_OTLP_PROTOCOL", value = "grpc" },
      { name = "OTEL_RESOURCE_ATTRIBUTES", value = "deployment.environment=prod,service.namespace=nt548" },
      { name = "OTEL_TRACES_SAMPLER", value = "parentbased_traceidratio" },
      { name = "OTEL_TRACES_SAMPLER_ARG", value = "1.0" },
      { name = "OTEL_METRICS_EXPORTER", value = "otlp" },
      { name = "OTEL_LOGS_EXPORTER", value = "none" },
      { name = "OTEL_PYTHON_EXCLUDED_URLS", value = "health" },
      { name = "OTEL_PYTHON_LOG_CORRELATION", value = "true" },
      { name = "DB_HOST", value = var.db_host },
      { name = "DB_PORT", value = "3306" },
      { name = "DB_NAME", value = var.db_name }
    ]
    secrets = [
      { name = "JWT_SECRET", valueFrom = "${var.app_secret_arn}:JWT_SECRET::" },
      { name = "DB_USER", valueFrom = "${var.db_credentials_secret_arn}:username::" },
      { name = "DB_PASSWORD", valueFrom = "${var.db_credentials_secret_arn}:password::" }
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
    }, {
    name      = "adot-collector"
    image     = var.observability_image
    essential = false
    command   = ["--config=/etc/ecs/nt548-adot.yaml"]
    environment = [
      { name = "AWS_REGION", value = data.aws_region.current.name }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.prod_otel_collector.name
        awslogs-region        = data.aws_region.current.name
        awslogs-stream-prefix = "product"
        mode                  = "blocking"
      }
    }
  }])
}

resource "aws_ecs_task_definition" "prod_order" {
  family                   = "nt548-prod-order"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
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
      { name = "PORT", value = "5003" },
      { name = "OTEL_SERVICE_NAME", value = "nt548-prod-order-service" },
      { name = "OTEL_EXPORTER_OTLP_ENDPOINT", value = "http://127.0.0.1:4317" },
      { name = "OTEL_EXPORTER_OTLP_PROTOCOL", value = "grpc" },
      { name = "OTEL_RESOURCE_ATTRIBUTES", value = "deployment.environment=prod,service.namespace=nt548" },
      { name = "OTEL_TRACES_SAMPLER", value = "parentbased_traceidratio" },
      { name = "OTEL_TRACES_SAMPLER_ARG", value = "1.0" },
      { name = "OTEL_METRICS_EXPORTER", value = "otlp" },
      { name = "OTEL_LOGS_EXPORTER", value = "none" },
      { name = "DB_HOST", value = var.db_host },
      { name = "DB_PORT", value = "3306" },
      { name = "DB_NAME", value = var.db_name },
      { name = "USER_SERVICE_URL", value = "http://${var.frontend_api_host}/api/users" },
      { name = "PRODUCT_SERVICE_URL", value = "http://${var.frontend_api_host}/api/products" }
    ]
    secrets = [
      { name = "JWT_SECRET", valueFrom = "${var.app_secret_arn}:JWT_SECRET::" },
      { name = "DB_USER", valueFrom = "${var.db_credentials_secret_arn}:username::" },
      { name = "DB_PASSWORD", valueFrom = "${var.db_credentials_secret_arn}:password::" }
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
    }, {
    name        = "adot-collector"
    image       = var.observability_image
    essential   = false
    command     = ["--config=/etc/ecs/nt548-adot.yaml"]
    environment = [{ name = "AWS_REGION", value = data.aws_region.current.name }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.prod_otel_collector.name
        awslogs-region        = data.aws_region.current.name
        awslogs-stream-prefix = "order"
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
