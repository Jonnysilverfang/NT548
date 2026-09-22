data "aws_caller_identity" "current" {}

data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket = "nt548-terraform-state-${data.aws_caller_identity.current.account_id}"
    key    = "shared/terraform.tfstate"
    region = var.aws_region
  }
}

# 1. Lambda Security Gate
module "lambda_security_gate" {
  source            = "../../modules/lambda-security-gate"
  role_arn          = data.terraform_remote_state.shared.outputs.lambda_security_gate_role_arn
  dev_pipeline_name = "nt548-dev-pipeline"
  max_critical      = 0
  max_high          = 0
}

# 2. EventBridge Rule (ECR Scan -> Trigger Lambda)
module "eventbridge" {
  source               = "../../modules/eventbridge"
  lambda_function_arn  = module.lambda_security_gate.lambda_function_arn
  lambda_function_name = module.lambda_security_gate.lambda_function_name
}

# 3. DEV CodeBuild Projects
resource "aws_codebuild_project" "dev_build" {
  name          = "nt548-dev-build"
  description   = "Builds, tests, and pushes Docker images to ECR DEV"
  service_role  = data.terraform_remote_state.shared.outputs.codebuild_dev_role_arn
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
    buildspec = "buildspec/dev-build.yml"
  }

  tags = {
    Name        = "nt548-dev-build"
    Environment = "dev"
    Project     = "NT548"
  }
}

resource "aws_codebuild_project" "dev_deploy_test" {
  name          = "nt548-dev-deploy-test"
  description   = "Deploys ephemeral DEV ECS, executes cookie smoke test, then runs cleanup"
  service_role  = data.terraform_remote_state.shared.outputs.codebuild_dev_role_arn
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
      value = var.aws_region
    }
    environment_variable {
      name  = "BASE_URL"
      value = "http://${data.terraform_remote_state.shared.outputs.alb_dns_name}"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec/dev-deploy-test.yml"
  }

  tags = {
    Name        = "nt548-dev-deploy-test"
    Environment = "dev"
    Project     = "NT548"
  }
}

# 4. DEV CodePipeline
resource "aws_codepipeline" "dev" {
  name           = "nt548-dev-pipeline"
  role_arn       = data.terraform_remote_state.shared.outputs.codepipeline_dev_role_arn
  pipeline_type  = "V2"
  execution_mode = "QUEUED"

  trigger {
    provider_type = "CodeStarSourceConnection"

    git_configuration {
      source_action_name = "GitHubDevSource"

      push {
        branches {
          includes = ["dev"]
        }
      }
    }
  }

  artifact_store {
    location = data.terraform_remote_state.shared.outputs.artifact_bucket_name
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "GitHubDevSource"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["SourceArtifact"]
      namespace        = "SourceVariables"

      configuration = {
        ConnectionArn    = var.github_connection_arn
        FullRepositoryId = var.github_repository
        BranchName       = "dev"
        DetectChanges    = "false"
      }
    }
  }

  stage {
    name = "BuildAndScan"

    action {
      name             = "BuildAndPushDevECR"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.dev_build.name
      }
    }
  }

  stage {
    name = "SecurityGate"

    action {
      name     = "SecurityGateApproval"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"

      configuration = {
        CustomData = "Automated DEV gate for commit #{SourceVariables.CommitId}. Lambda approves only after all four images with the same immutable tag complete scanning with CRITICAL=0 and HIGH=0."
      }
    }
  }

  stage {
    name = "DeployAndTest"

    action {
      name            = "EphemeralDeployAndSmokeTest"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["BuildArtifact"]
      version         = "1"

      configuration = {
        ProjectName = aws_codebuild_project.dev_deploy_test.name
      }
    }
  }

  tags = {
    Name        = "nt548-dev-pipeline"
    Environment = "dev"
    Project     = "NT548"
  }
}
