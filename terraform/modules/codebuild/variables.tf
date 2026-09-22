variable "dev_role_arn" {
  type        = string
  description = "IAM Role ARN for DEV CodeBuild projects"
}

variable "prod_role_arn" {
  type        = string
  description = "IAM Role ARN for PROD CodeBuild projects"
}

variable "artifact_bucket" {
  type        = string
  description = "S3 bucket for build artifacts"
}
