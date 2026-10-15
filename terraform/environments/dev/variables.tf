variable "aws_region" {
  type        = string
  description = "AWS deployment region"
  default     = "ap-southeast-1"
}

variable "github_connection_arn" {
  type        = string
  description = "CodeStar/CodeConnection ARN for GitHub"
  default     = "arn:aws:codeconnections:ap-southeast-1:620306387033:connection/13537aeb-3c13-4715-b94c-a7159ec35ebe"
}

variable "github_repository" {
  type        = string
  description = "GitHub repository (Owner/Repo)"
  default     = "Jonnysilverfang/NT548"
}
