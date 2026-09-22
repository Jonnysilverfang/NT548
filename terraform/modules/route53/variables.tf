variable "route53_zone_id" {
  type        = string
  description = "Zone ID of the Route 53 hosted zone"
}

variable "domain_name" {
  type        = string
  description = "Domain name for the record"
  default     = "kiendev.site"
}

variable "alb_dns_name" {
  type        = string
  description = "DNS name of the ALB"
}

variable "alb_zone_id" {
  type        = string
  description = "Zone ID of the ALB"
}
