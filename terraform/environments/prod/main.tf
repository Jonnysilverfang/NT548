data "aws_caller_identity" "current" {}

data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket       = "nt548-terraform-state-${data.aws_caller_identity.current.account_id}"
    key          = "shared/terraform.tfstate"
    region       = var.aws_region
    use_lockfile = true
  }
}

# Application credentials are managed outside Terraform so their values never
# enter plans, state files, build logs, or task-definition environment blocks.
data "aws_secretsmanager_secret" "app" {
  name = "nt548/app-secrets"
}

# 1. SNS Topics for Manual Approvals
module "sns_infra" {
  source         = "../../modules/sns"
  approval_email = var.approval_email
  topic_name     = "nt548-prod-infra-approval"
}

module "sns_app" {
  source         = "../../modules/sns"
  approval_email = var.approval_email
  topic_name     = "nt548-prod-deployment-approval"
}

# 2. ECS Cluster & PROD Services (24/7 Fleet with Rolling Deployment)
module "ecs" {
  source             = "../../modules/ecs"
  cluster_name       = "nt548-cluster"
  vpc_id             = data.terraform_remote_state.shared.outputs.vpc_id
  subnet_ids         = data.terraform_remote_state.shared.outputs.public_subnet_ids
  security_group_id  = data.terraform_remote_state.shared.outputs.ecs_tasks_security_group_id
  execution_role_arn = data.terraform_remote_state.shared.outputs.ecs_task_execution_role_arn
  task_role_arn      = data.terraform_remote_state.shared.outputs.ecs_task_role_arn
  prod_target_groups = data.terraform_remote_state.shared.outputs.prod_target_groups
  frontend_api_host  = data.terraform_remote_state.shared.outputs.alb_dns_name
  app_secret_arn     = data.aws_secretsmanager_secret.app.arn

  image_urls = {
    frontend = "${data.terraform_remote_state.shared.outputs.prod_repository_urls["nt548-prod-frontend"]}:${var.app_image_tag}"
    user     = "${data.terraform_remote_state.shared.outputs.prod_repository_urls["nt548-prod-user"]}:${var.app_image_tag}"
    product  = "${data.terraform_remote_state.shared.outputs.prod_repository_urls["nt548-prod-product"]}:${var.app_image_tag}"
    order    = "${data.terraform_remote_state.shared.outputs.prod_repository_urls["nt548-prod-order"]}:${var.app_image_tag}"
  }
}

# 3. PROD CodeBuild Projects
resource "aws_codebuild_project" "infra_plan" {
  # checkov:skip=CKV_AWS_147: "AWS-managed encryption is accepted for this cost-constrained lab; plan artifacts are held in the encrypted private artifact bucket"
  name          = "nt548-prod-terraform-plan"
  description   = "Performs terraform fmt, checkov security scan, validate, and plan for PROD infrastructure"
  service_role  = data.terraform_remote_state.shared.outputs.codebuild_prod_role_arn
  build_timeout = 30

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
      value = var.aws_region
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec/prod-infra-plan.yml"
  }

  logs_config {
    cloudwatch_logs {
      status = "ENABLED"
    }
  }

  tags = {
    Name        = "nt548-prod-terraform-plan"
    Environment = "prod"
    Project     = "NT548"
  }
}

resource "aws_codebuild_project" "infra_apply" {
  # checkov:skip=CKV_AWS_147: "AWS-managed encryption is accepted for this cost-constrained lab; plan artifacts are held in the encrypted private artifact bucket"
  name          = "nt548-prod-terraform-apply"
  description   = "Applies pre-approved tfplan to PROD infrastructure"
  service_role  = data.terraform_remote_state.shared.outputs.codebuild_prod_role_arn
  build_timeout = 30

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
      value = var.aws_region
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec/prod-infra-apply.yml"
  }

  logs_config {
    cloudwatch_logs {
      status = "ENABLED"
    }
  }

  tags = {
    Name        = "nt548-prod-terraform-apply"
    Environment = "prod"
    Project     = "NT548"
  }
}

resource "aws_codebuild_project" "app_build" {
  # checkov:skip=CKV_AWS_147: "AWS-managed encryption is accepted for this cost-constrained lab; source and artifacts contain no secret values"
  # checkov:skip=CKV_AWS_316: "Privileged mode is required only in this project to build Docker images"
  name          = "nt548-prod-app-build"
  description   = "Runs unit tests, builds and scans Docker images, pushes to PROD ECR"
  service_role  = data.terraform_remote_state.shared.outputs.codebuild_prod_role_arn
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
      value = var.aws_region
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec/prod-app-build.yml"
  }

  logs_config {
    cloudwatch_logs {
      status = "ENABLED"
    }
  }

  tags = {
    Name        = "nt548-prod-app-build"
    Environment = "prod"
    Project     = "NT548"
  }
}

# 4. PROD CodePipeline (7 Sequential Stages: Source -> InfraPlan -> InfraApproval -> InfraApply -> AppBuild -> ProductionApproval -> AppDeploy)
resource "aws_codepipeline" "prod" {
  # checkov:skip=CKV_AWS_219: "The versioned private artifact bucket uses S3 managed encryption; a customer-managed KMS key is deferred for lab cost control"
  name           = "nt548-prod-pipeline"
  role_arn       = data.terraform_remote_state.shared.outputs.codepipeline_prod_role_arn
  pipeline_type  = "V2"
  execution_mode = "QUEUED"

  artifact_store {
    location = data.terraform_remote_state.shared.outputs.artifact_bucket_name
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "GitHubMainSource"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["SourceArtifact"]
      namespace        = "SourceVariables"

      configuration = {
        ConnectionArn    = var.github_connection_arn
        FullRepositoryId = var.github_repository
        BranchName       = "main"
        DetectChanges    = "true"
      }
    }
  }

  stage {
    name = "InfraPlan"

    action {
      name             = "TerraformPlanAndCheckov"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["InfraPlanArtifact"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.infra_plan.name
      }
    }
  }

  stage {
    name = "InfraApproval"

    action {
      name     = "ApproveTerraformPlan"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"

      configuration = {
        NotificationArn = module.sns_infra.topic_arn
        CustomData      = "Infrastructure approval for commit #{SourceVariables.CommitId} in ap-southeast-1. Terraform fmt/validate and Checkov passed; review tfplan.txt in InfraPlanArtifact before approving the exact saved tfplan."
      }
    }
  }

  stage {
    name = "InfraApply"

    action {
      name            = "TerraformApply"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["InfraPlanArtifact"]
      version         = "1"

      configuration = {
        ProjectName = aws_codebuild_project.infra_apply.name
      }
    }
  }

  stage {
    name = "AppBuild"

    action {
      name             = "BuildAndPushProdECR"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["AppBuildArtifact"]
      version          = "1"
      namespace        = "AppBuildVariables"

      configuration = {
        ProjectName = aws_codebuild_project.app_build.name
      }
    }
  }

  stage {
    name = "ProductionApproval"

    action {
      name     = "ApproveProductionDeployment"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"

      configuration = {
        NotificationArn = module.sns_app.topic_arn
        CustomData      = "Application approval for commit #{SourceVariables.CommitId}, image tag #{AppBuildVariables.IMAGE_TAG}. Scan evidence: #{AppBuildVariables.SCAN_SUMMARY}. Pipeline execution and approval links are included by CodePipeline. Approve ECS rolling deployment."
      }
    }
  }

  stage {
    name = "AppDeploy"

    action {
      name            = "DeployFrontend"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["AppBuildArtifact"]
      version         = "1"
      run_order       = 1

      configuration = {
        ClusterName = module.ecs.cluster_name
        ServiceName = module.ecs.frontend_service_name
        FileName    = "imagedefinitions-frontend.json"
      }
    }

    action {
      name            = "DeployUser"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["AppBuildArtifact"]
      version         = "1"
      run_order       = 1

      configuration = {
        ClusterName = module.ecs.cluster_name
        ServiceName = module.ecs.user_service_name
        FileName    = "imagedefinitions-user.json"
      }
    }

    action {
      name            = "DeployProduct"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["AppBuildArtifact"]
      version         = "1"
      run_order       = 1

      configuration = {
        ClusterName = module.ecs.cluster_name
        ServiceName = module.ecs.product_service_name
        FileName    = "imagedefinitions-product.json"
      }
    }

    action {
      name            = "DeployOrder"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["AppBuildArtifact"]
      version         = "1"
      run_order       = 1

      configuration = {
        ClusterName = module.ecs.cluster_name
        ServiceName = module.ecs.order_service_name
        FileName    = "imagedefinitions-order.json"
      }
    }
  }

  tags = {
    Name        = "nt548-prod-pipeline"
    Environment = "prod"
    Project     = "NT548"
  }
}
