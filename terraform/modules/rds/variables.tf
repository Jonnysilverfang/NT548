variable "project_name" {
  type        = string
  description = "Project name used in resource names and tags"
}

variable "vpc_id" {
  type        = string
  description = "VPC hosting the database"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets used by the RDS subnet group"
}

variable "ecs_security_group_id" {
  type        = string
  description = "ECS security group allowed to connect to MySQL"
}

variable "db_name" {
  type        = string
  description = "Initial database name"
  default     = "nt548"
}

variable "db_username" {
  type        = string
  description = "RDS master username"
  default     = "nt548_admin"
}
