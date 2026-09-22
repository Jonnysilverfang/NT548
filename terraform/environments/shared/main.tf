data "aws_caller_identity" "current" {}

# S3 Bucket for CodePipeline Artifacts
resource "aws_s3_bucket" "artifacts" {
  # checkov:skip=CKV_AWS_18: "Access logging not required for CI/CD artifacts bucket"
  # checkov:skip=CKV_AWS_144: "Cross-region replication not required for CI/CD artifacts bucket"
  # checkov:skip=CKV_AWS_145: "AES256 encryption is sufficient for CI/CD artifacts bucket"
  # checkov:skip=CKV2_AWS_62: "S3 event notifications not required for artifacts bucket"
  # checkov:skip=CKV2_AWS_61: "Lifecycle configuration not required for ephemeral artifact bucket"
  bucket        = "nt548-artifacts-${data.aws_caller_identity.current.account_id}"
  force_destroy = false

  tags = {
    Name        = "nt548-pipeline-artifacts"
    Environment = "shared"
    Project     = var.project_name
  }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 1. VPC Module
module "vpc" {
  source       = "../../modules/vpc"
  project_name = var.project_name
}

# 2. ALB Module (Shared ALB, HTTP:80 Listener, PROD Target Groups)
module "alb" {
  source            = "../../modules/alb"
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  security_group_id = module.vpc.alb_security_group_id
  project_name      = var.project_name
}

# 3. ECR Module (4 DEV + 4 PROD ECR Repositories)
module "ecr" {
  source = "../../modules/ecr"
}

# 4. IAM Module (Least-privilege roles)
module "iam" {
  source                = "../../modules/iam"
  project_name          = var.project_name
  github_connection_arn = var.github_connection_arn
}
