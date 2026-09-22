variable "aws_region" {
  type        = string
  description = "AWS deployment region"
  default     = "ap-southeast-1"
}

variable "github_connection_arn" {
  type        = string
  description = "CodeStar/CodeConnection ARN for GitHub"
  default     = "arn:aws:codestar-connections:ap-southeast-1:404063515739:connection/6d611890-6a82-43be-9ccf-8f83f7664e6e"
}

variable "github_repository" {
  type        = string
  description = "GitHub repository (Owner/Repo)"
  default     = "Jonnysilverfang/NT548"
}
