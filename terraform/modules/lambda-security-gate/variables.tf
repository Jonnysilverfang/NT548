variable "role_arn" {
  type        = string
  description = "IAM Role ARN for Lambda Security Gate"
}

variable "dev_pipeline_name" {
  type        = string
  description = "DEV CodePipeline Name"
  default     = "nt548-dev-pipeline"
}

variable "max_critical" {
  type        = number
  description = "Max allowed critical vulnerabilities before rejection"
  default     = 0
}

variable "max_high" {
  type        = number
  description = "Max allowed high vulnerabilities before rejection"
  default     = 0
}
