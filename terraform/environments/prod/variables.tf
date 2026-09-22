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
  default     = "arn:aws:codeconnections:ap-southeast-1:404063515739:connection/043741f8-f157-4ed4-8cb7-9006c8b02a4d"
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

variable "service_desired_count" {
  type        = number
  description = "Desired task count for each PROD service; set to 0 until initial PROD images exist"
  default     = 1

  validation {
    condition     = var.service_desired_count >= 0
    error_message = "service_desired_count must be zero or greater."
  }
}
