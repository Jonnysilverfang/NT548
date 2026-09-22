variable "dev_role_arn" {
  type        = string
  description = "IAM Role ARN for DEV CodePipeline"
}

variable "prod_role_arn" {
  type        = string
  description = "IAM Role ARN for PROD CodePipeline"
}

variable "artifact_bucket_name" {
  type        = string
  description = "S3 bucket for CodePipeline artifacts"
}

variable "github_connection_arn" {
  type        = string
  description = "CodeStar/CodeConnection ARN for GitHub"
}

variable "github_repository" {
  type        = string
  description = "Full GitHub repository name (Owner/Repo)"
  default     = "Jonnysilverfang/NT548"
}

variable "dev_build_project_name" {
  type        = string
  description = "DEV build project name"
}

variable "dev_deploy_test_project_name" {
  type        = string
  description = "DEV deploy and test project name"
}

variable "prod_build_project_name" {
  type        = string
  description = "PROD build project name"
}

variable "prod_deploy_project_name" {
  type        = string
  description = "PROD deploy project name"
}

variable "sns_topic_arn" {
  type        = string
  description = "SNS Topic ARN for PROD approval notifications"
}
