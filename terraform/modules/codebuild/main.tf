# 1. DEV Build Project
resource "aws_codebuild_project" "dev_build" {
  # checkov:skip=CKV_AWS_147: "AWS-managed encryption is accepted for this cost-constrained lab; source and artifacts contain no secrets"
  # checkov:skip=CKV_AWS_316: "Privileged mode is required only in this project to build Docker images"
  name          = "nt548-dev-build"
  description   = "Builds, tests, and pushes Docker images to ECR DEV"
  service_role  = var.dev_role_arn
  build_timeout = 30

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "AWS_REGION"
      value = "ap-southeast-1"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec/dev-build.yml"
  }

  logs_config {
    cloudwatch_logs {
      status = "ENABLED"
    }
  }

  tags = {
    Name        = "nt548-dev-build"
    Environment = "dev"
    Project     = "NT548"
  }
}

# 2. DEV Ephemeral Deploy & Smoke Test Project
resource "aws_codebuild_project" "dev_deploy_test" {
  # checkov:skip=CKV_AWS_147: "AWS-managed encryption is accepted for this cost-constrained lab; source and artifacts contain no secrets"
  name          = "nt548-dev-deploy-test"
  description   = "Deploys ephemeral DEV ECS, executes cookie smoke test, then runs cleanup"
  service_role  = var.dev_role_arn
  build_timeout = 20

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = false
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "AWS_REGION"
      value = "ap-southeast-1"
    }
    environment_variable {
      name  = "BASE_URL"
      value = "https://kiendev.site"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec/dev-deploy-test.yml"
  }

  logs_config {
    cloudwatch_logs {
      status = "ENABLED"
    }
  }

  tags = {
    Name        = "nt548-dev-deploy-test"
    Environment = "dev"
    Project     = "NT548"
  }
}

# 3. PROD Build Project
resource "aws_codebuild_project" "prod_build" {
  # checkov:skip=CKV_AWS_147: "AWS-managed encryption is accepted for this cost-constrained lab; source and artifacts contain no secrets"
  # checkov:skip=CKV_AWS_316: "Privileged mode is required only in this project to build Docker images"
  name          = "nt548-prod-build"
  description   = "Builds, tests, and pushes Docker images to ECR PROD"
  service_role  = var.prod_role_arn
  build_timeout = 30

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "AWS_REGION"
      value = "ap-southeast-1"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec/prod-build.yml"
  }

  logs_config {
    cloudwatch_logs {
      status = "ENABLED"
    }
  }

  tags = {
    Name        = "nt548-prod-build"
    Environment = "prod"
    Project     = "NT548"
  }
}

# 4. PROD Deploy Project
resource "aws_codebuild_project" "prod_deploy" {
  # checkov:skip=CKV_AWS_147: "AWS-managed encryption is accepted for this cost-constrained lab; source and artifacts contain no secrets"
  name          = "nt548-prod-deploy"
  description   = "Updates PROD ECS tasks with newly approved images"
  service_role  = var.prod_role_arn
  build_timeout = 15

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = false
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "AWS_REGION"
      value = "ap-southeast-1"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec/prod-deploy.yml"
  }

  logs_config {
    cloudwatch_logs {
      status = "ENABLED"
    }
  }

  tags = {
    Name        = "nt548-prod-deploy"
    Environment = "prod"
    Project     = "NT548"
  }
}
