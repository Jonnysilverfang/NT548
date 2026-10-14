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

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for private database subnets"
  default     = ["10.0.101.0/24", "10.0.102.0/24"]

  validation {
    condition     = length(var.private_subnet_cidrs) >= 2
    error_message = "At least two private subnet CIDRs are required for RDS."
  }
}

variable "availability_zones" {
  type        = list(string)
  description = "Pinned availability zones for deterministic subnet placement"

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "availability_zones must contain at least two zones."
  }
}

variable "project_name" {
  type        = string
  description = "Project name tag"
  default     = "NT548"
}
