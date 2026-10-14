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
  description = "GitHub Infrastructure repository (Owner/Repo)"
  default     = "Jonnysilverfang/NT548"
}

variable "github_app_repository" {
  type        = string
  description = "GitHub Application repository (Owner/Repo)"
  default     = "Kien-devops/NT548-APP"
}

variable "app_image_tag" {
  type        = string
  description = "Baseline Docker image tag for initial ECS tasks"
  default     = "e15bfa1"
}

variable "product_image_tag" {
  type        = string
  description = "Optional product image tag used for the observability PoC"
  default     = "arch-202610142350"
}

variable "frontend_image_tag" {
  type        = string
  description = "Optional frontend image tag"
  default     = null
}

variable "user_image_tag" {
  type        = string
  description = "Optional user image tag used for observability rollout"
  default     = "arch-202610142350"
}

variable "order_image_tag" {
  type        = string
  description = "Optional order image tag used for observability rollout"
  default     = "arch-202610142350"
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

variable "observability_image" {
  type        = string
  description = "ADOT collector image used by backend sidecars"
  default     = "620306387033.dkr.ecr.ap-southeast-1.amazonaws.com/nt548-prod-observability:metrics-202610141700"
}
