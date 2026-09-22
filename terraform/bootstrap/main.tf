terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "terraform_state" {
  # checkov:skip=CKV_AWS_18: "Access logging not required for state bucket"
  # checkov:skip=CKV_AWS_144: "Cross-region replication not required for state bucket"
  # checkov:skip=CKV_AWS_145: "AES256 standard encryption used"
  # checkov:skip=CKV2_AWS_61: "Lifecycle configuration not required for state bucket"
  # checkov:skip=CKV2_AWS_62: "Event notifications not required for state bucket"
  bucket        = "nt548-terraform-state-${data.aws_caller_identity.current.account_id}"
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Project     = "NT548"
    ManagedBy   = "Terraform"
    Environment = "Bootstrap"
  }
}

resource "aws_s3_bucket_versioning" "state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state_encryption" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state_pab" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
