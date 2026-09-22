variable "aws_region" {
  type        = string
  description = "AWS deployment region"
  default     = "ap-southeast-1"
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
