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

variable "aws_region" {
  type        = string
  description = "AWS Region used by CodeBuild commands"
  default     = "ap-southeast-1"
}

variable "dev_base_url" {
  type        = string
  description = "Optional DEV smoke-test base URL; empty lets the script discover the shared ALB"
  default     = ""
}
