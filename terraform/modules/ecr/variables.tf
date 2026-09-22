variable "dev_repository_names" {
  type        = list(string)
  description = "List of DEV repository names"
  default = [
    "nt548-dev-user",
    "nt548-dev-product",
    "nt548-dev-order",
    "nt548-dev-frontend"
  ]
}

variable "prod_repository_names" {
  type        = list(string)
  description = "List of PROD repository names"
  default = [
    "nt548-prod-user",
    "nt548-prod-product",
    "nt548-prod-order",
    "nt548-prod-frontend"
  ]
}

variable "image_tag_mutability" {
  type        = string
  description = "Tag mutability setting"
  default     = "IMMUTABLE"
}
