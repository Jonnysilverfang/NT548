variable "aws_region" {
  type        = string
  description = "AWS deployment region"
  default     = "ap-southeast-1"
}

variable "approval_email" {
  type        = string
  description = "Email to receive PROD deployment manual approval notifications"
  default     = "admin@kiendev.site"
}

variable "github_connection_arn" {
  type        = string
  description = "CodeStar/CodeConnection ARN for GitHub"
  default     = "arn:aws:codeconnections:ap-southeast-1:404063515739:connection/cf889280-4f49-4954-9757-5d45f05b3ccc"
}

variable "github_repository" {
  type        = string
  description = "GitHub repository (Owner/Repo)"
  default     = "Jonnysilverfang/NT548"
}

variable "app_image_tag" {
  type        = string
  description = "Baseline Docker image tag for initial ECS tasks"
  default     = "e15bfa1"
}
