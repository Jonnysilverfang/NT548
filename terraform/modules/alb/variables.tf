variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "List of public subnet IDs"
}

variable "security_group_id" {
  type        = string
  description = "Security Group ID for ALB"
}

variable "certificate_arn" {
  type        = string
  description = "ARN of the ACM certificate"
  default     = null
}

variable "project_name" {
  type        = string
  description = "Project name"
  default     = "NT548"
}
