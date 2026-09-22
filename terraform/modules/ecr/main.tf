resource "aws_ecr_repository" "dev" {
  # checkov:skip=CKV_AWS_136: "ECR default AES-256 encryption is used; a customer-managed KMS key is deferred for lab cost control"
  for_each             = toset(var.dev_repository_names)
  name                 = each.key
  image_tag_mutability = var.image_tag_mutability
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = "dev"
    Project     = "NT548"
    ManagedBy   = "Terraform"
  }
}

resource "aws_ecr_repository" "prod" {
  # checkov:skip=CKV_AWS_136: "ECR default AES-256 encryption is used; a customer-managed KMS key is deferred for lab cost control"
  for_each             = toset(var.prod_repository_names)
  name                 = each.key
  image_tag_mutability = var.image_tag_mutability
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = "prod"
    Project     = "NT548"
    ManagedBy   = "Terraform"
  }
}
