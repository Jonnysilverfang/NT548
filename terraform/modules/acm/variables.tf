variable "domain_name" {
  type        = string
  description = "Domain name for the certificate"
  default     = "kiendev.site"
}

variable "route53_zone_id" {
  type        = string
  description = "Hosted zone ID in Route 53"
}
