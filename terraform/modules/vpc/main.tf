data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  selected_availability_zones = var.availability_zones != null ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, length(var.public_subnet_cidrs))
}

check "availability_zone_count" {
  assert {
    condition     = length(local.selected_availability_zones) >= length(var.public_subnet_cidrs)
    error_message = "availability_zones must contain at least one entry per public subnet CIDR."
  }
}

resource "aws_vpc" "main" {
  # checkov:skip=CKV2_AWS_11: "VPC flow logging disabled to optimize demo lab costs"
  # checkov:skip=CKV2_AWS_12: "Default security group restrictions managed at account level"
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name    = "${var.project_name}-vpc"
    Project = var.project_name
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}

resource "aws_subnet" "public" {
  # checkov:skip=CKV_AWS_130: "Public subnets map public IP for internet-facing tasks and ALB"
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = local.selected_availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project_name}-public-subnet-${count.index + 1}"
    Type    = "Public"
    Project = var.project_name
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name    = "${var.project_name}-public-rt"
    Project = var.project_name
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "alb" {
  # checkov:skip=CKV_AWS_260: "Public internet-facing ALB requires ingress on port 80"
  # checkov:skip=CKV_AWS_382: "Egress allowed for routing to ECS tasks"
  # checkov:skip=CKV2_AWS_5: "Security group attached to ALB"
  name        = "nt548-alb-sg"
  description = "Security group for Shared Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-alb-sg"
    Project = var.project_name
  }
}

resource "aws_security_group" "ecs_tasks" {
  # checkov:skip=CKV_AWS_382: "Egress allowed to fetch ECR images and CloudWatch"
  # checkov:skip=CKV2_AWS_5: "Security group attached to ECS services"
  name        = "nt548-ecs-tasks-sg"
  description = "Security group for ECS Tasks (ingress strictly from ALB)"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow Frontend from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "Allow User Service from ALB"
    from_port       = 5001
    to_port         = 5001
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "Allow Product Service from ALB"
    from_port       = 5002
    to_port         = 5002
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "Allow Order Service from ALB"
    from_port       = 5003
    to_port         = 5003
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow outbound to internet for ECR and CloudWatch"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-ecs-tasks-sg"
    Project = var.project_name
  }
}
