variable "approval_email" {
  type        = string
  description = "Email to receive PROD deployment manual approval notifications"
  default     = "admin@kiendev.site"
}

variable "topic_name" {
  type        = string
  description = "SNS Topic Name"
  default     = "nt548-prod-deployment-approval"
}
