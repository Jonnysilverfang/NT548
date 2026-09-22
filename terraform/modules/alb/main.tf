resource "aws_lb" "main" {
  # checkov:skip=CKV_AWS_91: "Access logging not enabled for lab demo ALB to optimize cost and resource usage"
  # checkov:skip=CKV_AWS_150: "Deletion protection disabled for automation and reproducibility"
  # checkov:skip=CKV2_AWS_28: "Ensure public facing ALB are protected by WAF"
  # checkov:skip=CKV2_AWS_20: "HTTP is intentionally retained until the user manually binds DNS and a validated ACM certificate"
  name                       = "nt548-shared-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [var.security_group_id]
  subnets                    = var.public_subnet_ids
  drop_invalid_header_fields = true

  enable_deletion_protection = false

  tags = {
    Name        = "nt548-shared-alb"
    Project     = var.project_name
    Environment = "shared"
  }
}

# PROD Target Groups
resource "aws_lb_target_group" "prod_fe" {
  # checkov:skip=CKV_AWS_378: "Target group communicates over HTTP internally within VPC"
  name                 = "nt548-prod-tg-fe"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "ip"
  deregistration_delay = 30

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = {
    Name        = "nt548-prod-tg-fe"
    Environment = "prod"
  }
}

resource "aws_lb_target_group" "prod_user" {
  # checkov:skip=CKV_AWS_378: "Target group communicates over HTTP internally within VPC"
  name                 = "nt548-prod-tg-user"
  port                 = 5001
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "ip"
  deregistration_delay = 30

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = {
    Name        = "nt548-prod-tg-user"
    Environment = "prod"
  }
}

resource "aws_lb_target_group" "prod_product" {
  # checkov:skip=CKV_AWS_378: "Target group communicates over HTTP internally within VPC"
  name                 = "nt548-prod-tg-product"
  port                 = 5002
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "ip"
  deregistration_delay = 30

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = {
    Name        = "nt548-prod-tg-product"
    Environment = "prod"
  }
}

resource "aws_lb_target_group" "prod_order" {
  # checkov:skip=CKV_AWS_378: "Target group communicates over HTTP internally within VPC"
  name                 = "nt548-prod-tg-order"
  port                 = 5003
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "ip"
  deregistration_delay = 30

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = {
    Name        = "nt548-prod-tg-order"
    Environment = "prod"
  }
}

# HTTP 80 Primary Listener (For direct ALB DNS verification and routing)
resource "aws_lb_listener" "http" {
  # checkov:skip=CKV_AWS_2: "HTTP listener port 80 is required for direct ALB DNS verification prior to custom domain binding"
  # checkov:skip=CKV_AWS_103: "HTTP listener is required for direct ALB DNS verification"
  # checkov:skip=CKV2_AWS_20: "Redirect to HTTPS postponed until custom domain TLS certificate is configured"
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prod_fe.arn
  }
}

# Optional HTTPS 443 Listener (Can be enabled when user attaches certificate later)
resource "aws_lb_listener" "https" {
  count             = var.certificate_arn != null && var.certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prod_fe.arn
  }
}

# PROD Path-Based Listener Rules attached to HTTP 80 Listener
resource "aws_lb_listener_rule" "prod_user" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prod_user.arn
  }

  condition {
    path_pattern {
      values = ["/api/users*"]
    }
  }
}

resource "aws_lb_listener_rule" "prod_product" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 101

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prod_product.arn
  }

  condition {
    path_pattern {
      values = ["/api/products*"]
    }
  }
}

resource "aws_lb_listener_rule" "prod_order" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 102

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prod_order.arn
  }

  condition {
    path_pattern {
      values = ["/api/orders*"]
    }
  }
}
