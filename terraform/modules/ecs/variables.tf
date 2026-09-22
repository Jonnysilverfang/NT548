variable "cluster_name" {
  type        = string
  description = "ECS cluster name"
  default     = "nt548-cluster"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for ECS tasks"
}

variable "security_group_id" {
  type        = string
  description = "Security group ID for ECS tasks"
}

variable "execution_role_arn" {
  type        = string
  description = "Execution role ARN for ECS tasks"
}

variable "task_role_arn" {
  type        = string
  description = "Task role ARN for ECS tasks"
}

variable "frontend_api_host" {
  type        = string
  description = "Shared ALB DNS name used by the frontend fallback reverse proxy in ECS"
}

variable "app_secret_arn" {
  type        = string
  description = "Secrets Manager ARN containing JWT_SECRET and ADMIN_PASSWORD JSON keys"
}

variable "service_desired_count" {
  type        = number
  description = "Desired task count for each PROD ECS service; use 0 during first-account image bootstrap"
  default     = 1

  validation {
    condition     = var.service_desired_count >= 0
    error_message = "service_desired_count must be zero or greater."
  }
}

variable "prod_target_groups" {
  type = object({
    frontend = string
    user     = string
    product  = string
    order    = string
  })
  description = "Map of PROD Target Group ARNs"
}

variable "image_urls" {
  type = object({
    frontend = string
    user     = string
    product  = string
    order    = string
  })
  description = "Container image URLs for the 4 services"
  default = {
    frontend = "public.ecr.aws/docker/library/nginx:alpine"
    user     = "public.ecr.aws/docker/library/node:20-alpine"
    product  = "public.ecr.aws/docker/library/python:3.12-alpine"
    order    = "public.ecr.aws/docker/library/node:20-alpine"
  }
}
