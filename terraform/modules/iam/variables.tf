variable "project_name" {
  type        = string
  description = "Project name"
  default     = "nt548"
}

variable "dev_pipeline_name" {
  type        = string
  description = "DEV pipeline name"
  default     = "nt548-dev-pipeline"
}

variable "prod_pipeline_name" {
  type        = string
  description = "PROD pipeline name"
  default     = "nt548-prod-pipeline"
}

variable "github_connection_arn" {
  type        = string
  description = "CodeConnections ARN used by the production source action"
}
