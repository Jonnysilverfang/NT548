variable "aws_region" {
  type        = string
  description = "AWS deployment region"
  default     = "ap-southeast-1"
}

variable "domain_name" {
  type        = string
  description = "Apex domain name in Route 53"
  default     = "kiendev.site"
}

variable "project_name" {
  type        = string
  description = "Project name"
  default     = "NT548"
}

variable "github_connection_arn" {
  type        = string
  description = "CodeConnections ARN used by the CI/CD pipelines"
  default     = "arn:aws:codeconnections:ap-southeast-1:404063515739:connection/043741f8-f157-4ed4-8cb7-9006c8b02a4d"
}

variable "availability_zones" {
  type        = list(string)
  description = "Two or more availability zones pinned during account bootstrap"

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "availability_zones must contain at least two zones."
  }
}

variable "github_repository" {
  type        = string
  description = "GitHub repository (Owner/Repo)"
  default     = "Jonnysilverfang/NT548"
}
