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
  default     = "arn:aws:codestar-connections:ap-southeast-1:404063515739:connection/6d611890-6a82-43be-9ccf-8f83f7664e6e"
}
