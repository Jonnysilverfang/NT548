variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for public subnets"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "availability_zones" {
  type        = list(string)
  description = "Optional availability zones for subnets; null selects available zones in the provider region"
  default     = null
}

variable "project_name" {
  type        = string
  description = "Project name tag"
  default     = "NT548"
}
