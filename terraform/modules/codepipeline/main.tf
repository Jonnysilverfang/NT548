# ==========================================
# 1. DEV CodePipeline
# ==========================================
resource "aws_codepipeline" "dev" {
  # checkov:skip=CKV_AWS_219: "The versioned private artifact bucket uses S3 managed encryption; a customer-managed KMS key is deferred for lab cost control"
  name     = "nt548-dev-pipeline"
  role_arn = var.dev_role_arn

  artifact_store {
    location = var.artifact_bucket_name
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

      configuration = {
        ConnectionArn    = var.github_connection_arn
        FullRepositoryId = var.github_repository
        BranchName       = "dev"
        DetectChanges    = "true"
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
        ProjectName = var.dev_build_project_name
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
        CustomData = "Automated Security Gate evaluated by Lambda from ECR image scan findings."
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
        ProjectName = var.dev_deploy_test_project_name
      }
    }
  }

  tags = {
    Name        = "nt548-dev-pipeline"
    Environment = "dev"
    Project     = "NT548"
  }
}

# ==========================================
# 2. PROD CodePipeline
# ==========================================
resource "aws_codepipeline" "prod" {
  # checkov:skip=CKV_AWS_219: "The versioned private artifact bucket uses S3 managed encryption; a customer-managed KMS key is deferred for lab cost control"
  name     = "nt548-prod-pipeline"
  role_arn = var.prod_role_arn

  artifact_store {
    location = var.artifact_bucket_name
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

      configuration = {
        ConnectionArn    = var.github_connection_arn
        FullRepositoryId = var.github_repository
        BranchName       = "main"
      }
    }
  }

  stage {
    name = "BuildAndScan"

    action {
      name             = "BuildAndPushProdECR"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact"]
      version          = "1"

      configuration = {
        ProjectName = var.prod_build_project_name
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
        NotificationArn = var.sns_topic_arn
        CustomData      = "Production Deployment Approval: Review commit, image tags, and scan status before deploying to 24/7 PROD fleet."
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "DeployToProdECS"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["BuildArtifact"]
      version         = "1"

      configuration = {
        ProjectName = var.prod_deploy_project_name
      }
    }
  }

  tags = {
    Name        = "nt548-prod-pipeline"
    Environment = "prod"
    Project     = "NT548"
  }
}
