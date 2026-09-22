data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# 1. ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution" {
  name = "nt548-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_managed" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  name = "nt548-ecs-task-execution-secrets"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:nt548/app-secrets-*"
    }]
  })
}

# 2. ECS Task Role
resource "aws_iam_role" "ecs_task" {
  name = "nt548-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

# 3. CodeBuild DEV Role
resource "aws_iam_role" "codebuild_dev" {
  name = "nt548-codebuild-dev-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "codebuild.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "codebuild_dev_policy" {
  # checkov:skip=CKV_AWS_288: "CodeBuild requires multi-service access for building and deploying images"
  # checkov:skip=CKV_AWS_289: "CodeBuild requires ECS service and task execution permissions"
  # checkov:skip=CKV_AWS_290: "CodeBuild requires write access to ECR and CloudWatch logs"
  # checkov:skip=CKV_AWS_355: "Resource wildcards required for dynamic task definitions and log streams"
  name        = "nt548-codebuild-dev-policy"
  description = "Policy for DEV CodeBuild projects"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:DescribeImageScanFindings"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:RegisterTaskDefinition",
          "ecs:DeregisterTaskDefinition",
          "ecs:DescribeTaskDefinition",
          "ecs:CreateService",
          "ecs:UpdateService",
          "ecs:DeleteService",
          "ecs:DescribeServices",
          "ecs:ListTasks",
          "ecs:DescribeTasks"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:CreateRule",
          "elasticloadbalancing:ModifyRule",
          "elasticloadbalancing:DeleteRule",
          "elasticloadbalancing:CreateTargetGroup",
          "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetHealth"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_dev_attach" {
  role       = aws_iam_role.codebuild_dev.name
  policy_arn = aws_iam_policy.codebuild_dev_policy.arn
}

# 4. CodeBuild PROD Role
resource "aws_iam_role" "codebuild_prod" {
  name = "nt548-codebuild-prod-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "codebuild.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "codebuild_prod_policy" {
  # checkov:skip=CKV_AWS_287: "Terraform plan/apply must read managed IAM role policies; the role is dedicated to this repository's PROD pipeline"
  # checkov:skip=CKV_AWS_288: "CodeBuild requires multi-service access for building and deploying images"
  # checkov:skip=CKV_AWS_289: "CodeBuild requires ECS service and task execution permissions"
  # checkov:skip=CKV_AWS_290: "CodeBuild requires write access to ECR and CloudWatch logs"
  # checkov:skip=CKV_AWS_355: "Resource wildcards required for dynamic task definitions and log streams"
  name        = "nt548-codebuild-prod-policy"
  description = "Policy for PROD CodeBuild projects including Terraform and Docker builds"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:DescribeImages",
          "ecr:DescribeImageScanFindings",
          "ecr:ListImages"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:Describe*",
          "elasticloadbalancing:Get*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeRouteTables",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeAvailabilityZones"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:*",
          "codepipeline:*",
          "sns:*",
          "cloudwatch:*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:PassRole"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetResourcePolicy"
        ]
        Resource = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:nt548/app-secrets-*"
      },
      {
        Effect = "Allow"
        Action = [
          "codestar-connections:PassConnection"
        ]
        Resource = var.github_connection_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_prod_attach" {
  role       = aws_iam_role.codebuild_prod.name
  policy_arn = aws_iam_policy.codebuild_prod_policy.arn
}

# 5. CodePipeline DEV Role
resource "aws_iam_role" "codepipeline_dev" {
  name = "nt548-codepipeline-dev-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "codepipeline.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "codepipeline_dev_policy" {
  # checkov:skip=CKV_AWS_288: "CodePipeline requires S3 and CodeBuild execution permissions"
  # checkov:skip=CKV_AWS_289: "CodePipeline requires IAM pass role permissions for ECS and CodeBuild"
  # checkov:skip=CKV_AWS_290: "CodePipeline requires write access to pipeline artifacts"
  # checkov:skip=CKV_AWS_355: "Resource wildcards required for pipeline execution across tasks and builds"
  name = "nt548-codepipeline-dev-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:GetBucketVersioning"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "codestar-connections:UseConnection"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codepipeline_dev_attach" {
  role       = aws_iam_role.codepipeline_dev.name
  policy_arn = aws_iam_policy.codepipeline_dev_policy.arn
}

# 6. CodePipeline PROD Role
resource "aws_iam_role" "codepipeline_prod" {
  name = "nt548-codepipeline-prod-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "codepipeline.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "codepipeline_prod_policy" {
  # checkov:skip=CKV_AWS_288: "CodePipeline requires S3 and CodeBuild execution permissions"
  # checkov:skip=CKV_AWS_289: "CodePipeline requires IAM pass role permissions for ECS and CodeBuild"
  # checkov:skip=CKV_AWS_290: "CodePipeline requires write access to pipeline artifacts"
  # checkov:skip=CKV_AWS_355: "Resource wildcards required for pipeline execution across tasks and builds"
  name = "nt548-codepipeline-prod-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:GetBucketVersioning"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "codestar-connections:UseConnection"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codepipeline_prod_attach" {
  role       = aws_iam_role.codepipeline_prod.name
  policy_arn = aws_iam_policy.codepipeline_prod_policy.arn
}

# 7. Lambda DEV Security Gate Role
# Strict least-privilege: ONLY allowed PutApprovalResult on nt548-dev-pipeline!
resource "aws_iam_role" "lambda_security_gate" {
  name = "nt548-lambda-security-gate-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "lambda_security_gate_policy" {
  name        = "nt548-lambda-security-gate-policy"
  description = "Strict permissions for Lambda to only approve/reject DEV pipeline"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/nt548-dev-security-gate:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:DescribeImageScanFindings"
        ]
        Resource = "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/nt548-dev-*"
      },
      {
        Effect = "Allow"
        Action = [
          "codepipeline:GetPipelineState",
          "codepipeline:GetPipelineExecution",
          "codepipeline:PutApprovalResult"
        ]
        Resource = [
          "arn:aws:codepipeline:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${var.dev_pipeline_name}",
          "arn:aws:codepipeline:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${var.dev_pipeline_name}/*",
          "arn:aws:codepipeline:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${var.dev_pipeline_name}/*/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_security_gate_attach" {
  role       = aws_iam_role.lambda_security_gate.name
  policy_arn = aws_iam_policy.lambda_security_gate_policy.arn
}
