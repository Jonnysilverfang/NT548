variable "project_name" {
  type        = string
  description = "Project name used in resource names and tags"
  default     = "NT548"
}

variable "vpc_id" {
  type        = string
  description = "VPC where PostgreSQL is deployed"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs in at least two availability zones"

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "RDS requires at least two private subnets."
  }
}

variable "ecs_tasks_security_group_id" {
  type        = string
  description = "Security group used by ECS tasks that connect to PostgreSQL"
}

variable "identifier" {
  type        = string
  description = "RDS instance identifier"
  default     = "nt548-postgresql"
}

variable "database_name" {
  type        = string
  description = "Initial PostgreSQL database name"
  default     = "nt548"
}

variable "master_username" {
  type        = string
  description = "PostgreSQL master username; password is managed by RDS"
  default     = "nt548_admin"
}

variable "instance_class" {
  type        = string
  description = "RDS instance class"
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  type        = number
  description = "Initial gp3 storage size in GiB"
  default     = 20
}

variable "deletion_protection" {
  type        = bool
  description = "Protect the shared database from accidental deletion"
  default     = true
}
